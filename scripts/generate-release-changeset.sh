#!/usr/bin/env bash
set -euo pipefail

VERSION=""
BASE_REF="${RELEASE_CHANGESET_BASE:-origin/main}"
HEAD_REF="${RELEASE_CHANGESET_HEAD:-origin/develop}"
OUTPUT_PATH=""

usage() {
  cat <<'USAGE'
Usage: scripts/generate-release-changeset.sh vX.Y.Z [--base <ref>] [--head <ref>] [--output <path>]

Generates a sanitized release changeset at docs/releases/vX.Y.Z.md from a git range.
Defaults: --base origin/main --head origin/develop.
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
    --output)
      [[ $# -ge 2 ]] || fail "--output requires a path"
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    v[0-9]*.[0-9]*.[0-9]*)
      [[ -z "$VERSION" ]] || fail "version was provided more than once"
      VERSION="$1"
      shift
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "$VERSION" ]] || fail "missing version, expected vX.Y.Z"
[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-.][A-Za-z0-9._-]+)?$ ]] || fail "invalid version: $VERSION"

OUTPUT_PATH="${OUTPUT_PATH:-docs/releases/${VERSION}.md}"
mkdir -p "$(dirname "$OUTPUT_PATH")"

git rev-parse --verify "$BASE_REF^{commit}" >/dev/null || fail "base ref not found: $BASE_REF"
git rev-parse --verify "$HEAD_REF^{commit}" >/dev/null || fail "head ref not found: $HEAD_REF"

range="${BASE_REF}..${HEAD_REF}"
commit_count="$(git rev-list --count "$range")"

sanitize_summary() {
  local value="$1"
  value="${value//|/\\|}"
  value="$(printf '%s' "$value" | sed -E \
    -e 's/[0-9]{17,20}/<redacted-id>/g' \
    -e 's/(ghp_|gho_|github_pat_)[A-Za-z0-9_]+/<redacted-token>/g' \
    -e 's/(DISCORD_BOT_TOKEN|OPENAI_API_KEY|ANTHROPIC_API_KEY)=[^[:space:]]+/<redacted-secret>/g' \
    -e 's/production-ready/[release-claim-redacted]/Ig' \
    -e 's/public Discord validation passed/[release-claim-redacted]/Ig' \
    -e 's/live Discord validation passed/[release-claim-redacted]/Ig' \
    -e 's/live social validation passed/[release-claim-redacted]/Ig' \
    -e 's/live analytics validation passed/[release-claim-redacted]/Ig' \
    -e 's/publishing enabled/[release-claim-redacted]/Ig' \
    -e 's/scheduling enabled/[release-claim-redacted]/Ig' \
    -e 's/Buffer activity enabled/[release-claim-redacted]/Ig' \
    -e 's/production credentials enabled/[release-claim-redacted]/Ig' \
    -e 's/durable production writes enabled/[release-claim-redacted]/Ig')"
  printf '%s' "$value"
}

changes_table=""
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  sha="${line%%$'\t'*}"
  subject="${line#*$'\t'}"
  subject="$(sanitize_summary "$subject")"
  pr_ref="commit ${sha}"
  if [[ "$subject" =~ \(\#([0-9]+)\)$ ]]; then
    pr_ref="#${BASH_REMATCH[1]}"
  fi
  changes_table+="| ${pr_ref} | ${subject} |"$'\n'
done < <(git log --reverse --pretty=format:'%h%x09%s' "$range")

if [[ -z "$changes_table" ]]; then
  changes_table="| none | No commits found in ${BASE_REF}..${HEAD_REF}. |"$'\n'
fi

cat >"$OUTPUT_PATH" <<EOF
# ${VERSION} internal fake-first/local baseline

This release promotes the current release branch to main as an internal fake-first/local baseline.

It is intended for repository review, local Docker/runtime rehearsal, contract validation, and follow-up release hardening. It does **not** claim production readiness, public Discord readiness, live Discord execution, live social publishing/scheduling, live analytics ingestion, or durable production writes.

## Release scope

Status statement preserved for this baseline:

> Internal fake-first/local baseline complete. Private Docker and local disposable validations passed. QA-07 private Discord routing execution remains gated and was not executed. Production readiness is not claimed.

The release owner explicitly defers private Discord execution for this tag unless a separate approved issue completes it first. QA-07/private Discord execution remains gated until a separate approved issue executes and reviews docs/operations/private-discord-manual-verification-guide.md with sanitized evidence.

## Changeset

Generated from ${BASE_REF}..${HEAD_REF}.

Commits in range: ${commit_count}

| Ref | Summary |
| --- | --- |
${changes_table}
## Validation evidence

Run before opening or merging the release-promotion PR:

~~~bash
git diff --check
bash scripts/validate-release-promotion.sh --base origin/main --head HEAD
bash scripts/validate-repo-safe-evidence.sh
bash scripts/validate-openclaw-gentle-ai-runtime.sh
bash scripts/validate-openclaw-skill-inventory.sh
SAFE_VALIDATION_SKIP_STAGE0=1 bash scripts/run-safe-validation-suite.sh
~~~

PR checks on the release-promotion PR must also pass before merge to main.

## Known limitations

- QA-07/private Discord execution is gated unless a separate approved issue completes it first.
- No public Discord behavior is claimed.
- No production hosting, high availability, backup/restore, or operational SLO is claimed.
- No live social publishing, scheduling, Buffer activity, or live analytics ingestion is claimed.
- Local/no-op orchestration evidence must not be restated as deterministic production enforcement.
- Gentle SDD assets are packaged as OpenClaw workspace protocol/backend assets, not Pi subagents running inside OpenClaw.

## Rollback notes

This promotion is repository-only. If a release problem is found after merge, open a hotfix issue/PR against main, then back-merge or cherry-pick the fix into develop.

## Post-merge actions

After the release-promotion PR merges, the Release tag and notes workflow should create the matching ${VERSION} tag and GitHub Release from this file if they do not already exist.
EOF

printf 'Generated release changeset: %s\n' "$OUTPUT_PATH"
printf 'Range: %s..%s (%s commits)\n' "$BASE_REF" "$HEAD_REF" "$commit_count"
