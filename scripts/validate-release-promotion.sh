#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${RELEASE_PROMOTION_BASE:-origin/main}"
HEAD_REF="${RELEASE_PROMOTION_HEAD:-HEAD}"
FORCE="${RELEASE_PROMOTION_FORCE:-0}"

usage() {
  cat <<'USAGE'
Usage: scripts/validate-release-promotion.sh [--base <ref>] [--head <ref>] [--force]

Validates release-promotion PR requirements:
- PRs to main must include docs/releases/vX.Y.Z.md.
- Release notes must keep internal fake-first/local limitation language.
- Release notes must not claim production/public Discord/live social/live analytics readiness.
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || fail "--base requires a ref"
      BASE_REF="$2"
      shift 2
      ;;
    --head)
      [[ $# -ge 2 ]] || fail "--head requires a ref"
      HEAD_REF="$2"
      shift 2
      ;;
    --force)
      FORCE="1"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" && "${GITHUB_BASE_REF:-}" != "main" && "$FORCE" != "1" ]]; then
  echo "Skipping release-promotion validation: PR target is ${GITHUB_BASE_REF:-unknown}, not main."
  exit 0
fi

if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" && "$FORCE" != "1" ]]; then
  echo "Skipping release-promotion validation outside pull_request. Use --force for local checks."
  exit 0
fi

if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
  if [[ -f .git/shallow ]]; then
    git fetch --no-tags --unshallow origin "${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >/dev/null 2>&1 ||
      git fetch --no-tags --deepen=200 origin "${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >/dev/null 2>&1 || true
  else
    git fetch --no-tags origin "${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >/dev/null 2>&1 || true
  fi
fi

if ! git rev-parse --verify "$BASE_REF^{commit}" >/dev/null 2>&1; then
  if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
    git fetch --no-tags --depth=1 origin "${GITHUB_BASE_REF}:refs/remotes/origin/${GITHUB_BASE_REF}" >/dev/null 2>&1 || true
  fi
fi

git rev-parse --verify "$BASE_REF^{commit}" >/dev/null || fail "base ref not found: $BASE_REF"
git rev-parse --verify "$HEAD_REF^{commit}" >/dev/null || fail "head ref not found: $HEAD_REF"

if git merge-base "$BASE_REF" "$HEAD_REF" >/dev/null 2>&1; then
  diff_range="${BASE_REF}...${HEAD_REF}"
else
  diff_range="${BASE_REF}..${HEAD_REF}"
fi

mapfile -t release_files < <(git diff --name-only "$diff_range" | grep -E '^docs/releases/v[0-9]+\.[0-9]+\.[0-9]+([-.][A-Za-z0-9._-]+)?\.md$' | LC_ALL=C sort || true)

if [[ ${#release_files[@]} -eq 0 ]]; then
  fail "release promotion to main must include docs/releases/vX.Y.Z.md"
fi

for file in "${release_files[@]}"; do
  [[ -f "$file" ]] || fail "release file listed by diff is missing from working tree: $file"
  version="$(basename "$file" .md)"

  grep -F "# ${version}" "$file" >/dev/null || fail "$file missing matching version heading"
  grep -Fi "internal fake-first/local baseline" "$file" >/dev/null || fail "$file must state internal fake-first/local baseline"
  grep -F "Production readiness is not claimed" "$file" >/dev/null || fail "$file must preserve production-readiness disclaimer"
  grep -F "QA-07" "$file" >/dev/null || fail "$file must mention QA-07/private Discord gate"
  grep -Fi "private Discord" "$file" >/dev/null || fail "$file must mention private Discord gate"
  grep -F "bash scripts/validate-repo-safe-evidence.sh" "$file" >/dev/null || fail "$file must record repo-safe evidence validation"

  if grep -E 'production-ready|public Discord validation passed|live Discord validation passed|live social validation passed|live analytics validation passed|publishing enabled|scheduling enabled|Buffer activity enabled|production credentials enabled|durable production writes enabled' "$file" >/dev/null; then
    fail "$file contains forbidden release readiness claim"
  fi

  if grep -E '\b[0-9]{17,20}\b|ghp_|gho_|github_pat_|DISCORD_BOT_TOKEN=|OPENAI_API_KEY=|ANTHROPIC_API_KEY=' "$file" >/dev/null; then
    fail "$file contains private-looking IDs or secrets"
  fi

done

printf 'Validated release-promotion notes:\n'
printf ' - %s\n' "${release_files[@]}"
