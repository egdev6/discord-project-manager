#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd bash
require_cmd git
require_cmd grep
require_cmd mktemp
require_cmd python3

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

REPO_DIR="$TMPDIR/repo"
OUTPUT_PATH="$TMPDIR/vtest.md"
RAW_LOG_PATH="$TMPDIR/git-log.out"

git init -q "$REPO_DIR"
git -C "$REPO_DIR" config user.name "Release Validator"
git -C "$REPO_DIR" config user.email "release-validator@example.invalid"
git -C "$REPO_DIR" config commit.gpgsign false

printf 'base\n' >"$REPO_DIR/fixture.txt"
git -C "$REPO_DIR" add fixture.txt
git -C "$REPO_DIR" commit -q -m "chore: base"
BASE_REF="$(git -C "$REPO_DIR" rev-parse HEAD)"

printf 'middle\n' >>"$REPO_DIR/fixture.txt"
git -C "$REPO_DIR" add fixture.txt
git -C "$REPO_DIR" commit -q -m "feat: included middle row (#209)"

printf 'token\n' >>"$REPO_DIR/fixture.txt"
git -C "$REPO_DIR" add fixture.txt
git -C "$REPO_DIR" commit -q -m "fix: redact pasted token ghp_fake (#211)"

printf 'secret\n' >>"$REPO_DIR/fixture.txt"
git -C "$REPO_DIR" add fixture.txt
git -C "$REPO_DIR" commit -q -m "fix: redact secret DISCORD_BOT_TOKEN=<fake-discord-token-value> (#212)"

printf 'spaced-secret\n' >>"$REPO_DIR/fixture.txt"
git -C "$REPO_DIR" add fixture.txt
git -C "$REPO_DIR" commit -q -m "fix: redact spaced secret DISCORD_BOT_TOKEN = <fake-spaced-token-value> (#213)"

printf 'final\n' >>"$REPO_DIR/fixture.txt"
git -C "$REPO_DIR" add fixture.txt
git -C "$REPO_DIR" commit -q -m "fix: final row survives unterminated git log (#210)"
HEAD_REF="$(git -C "$REPO_DIR" rev-parse HEAD)"

git -C "$REPO_DIR" log --reverse --pretty=format:'%h%x09%s' "${BASE_REF}..${HEAD_REF}" >"$RAW_LOG_PATH"
python3 - "$RAW_LOG_PATH" <<'PY'
from pathlib import Path
import sys

raw = Path(sys.argv[1]).read_bytes()
if not raw:
    raise SystemExit("git log fixture unexpectedly empty")
if raw.endswith(b"\n"):
    raise SystemExit("git log fixture unexpectedly ended with a trailing newline")
if raw.count(b"\n") != 4:
    raise SystemExit("git log fixture should contain exactly five rows")
PY

(
  cd "$REPO_DIR"
  bash "$ROOT_DIR/scripts/generate-release-changeset.sh" v9.9.9 --base "$BASE_REF" --head "$HEAD_REF" --output "$OUTPUT_PATH" >/dev/null
)

grep -F "| #209 | feat: included middle row (#209) |" "$OUTPUT_PATH" >/dev/null || fail "generated changeset missing middle row"
grep -F "| #210 | fix: final row survives unterminated git log (#210) |" "$OUTPUT_PATH" >/dev/null || fail "generated changeset missing final unterminated git-log row"
grep -F "| #211 | fix: redact pasted token <redacted-token> (#211) |" "$OUTPUT_PATH" >/dev/null || fail "generated changeset did not redact pasted token"
grep -F "| #212 | fix: redact secret <redacted-secret> (#212) |" "$OUTPUT_PATH" >/dev/null || fail "generated changeset did not redact secret assignment"
grep -F "| #213 | fix: redact spaced secret <redacted-secret> (#213) |" "$OUTPUT_PATH" >/dev/null || fail "generated changeset did not redact spaced secret assignment"
! grep -F "ghp_fake" "$OUTPUT_PATH" >/dev/null || fail "generated changeset leaked fake token fixture"
! grep -F "DISCORD_BOT_TOKEN=<fake-discord-token-value>" "$OUTPUT_PATH" >/dev/null || fail "generated changeset leaked fake secret fixture"
! grep -F "DISCORD_BOT_TOKEN = <fake-spaced-token-value>" "$OUTPUT_PATH" >/dev/null || fail "generated changeset leaked fake spaced-secret fixture"
grep -F "Develop commits in range: 5" "$OUTPUT_PATH" >/dev/null || fail "generated changeset has unexpected commit count"

printf 'Validated release changeset final-row handling with unterminated git log output.\n'
printf 'Validated release changeset token and secret redaction.\n'
printf 'Fixture commits in range: 5\n'
