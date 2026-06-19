#!/usr/bin/env bash
set -euo pipefail

NOOP_PATH="docker/openclaw/discord-noop-observation.sh"
GUARD_PATH="docker/openclaw/discord-approval-guard.sh"
DOCKERFILE_PATH="docker/openclaw/Dockerfile"
FIXTURE_PATH="examples/private-discord-engram-noop-observation.fake.yaml"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
RUNTIME_NAMESPACE="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
TARGET_NAMESPACE="discord-project-manager/project/demo-project/private-context"
TMPDIR_CREATED="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CREATED"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd bash
require_cmd grep
require_cmd awk
require_cmd mktemp

for path in "$NOOP_PATH" "$GUARD_PATH" "$DOCKERFILE_PATH" "$FIXTURE_PATH" "$READINESS_FIXTURE" "$GUIDE_PATH"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

bash -n "$NOOP_PATH" || fail "no-op observation CLI has invalid shell syntax"

grep -F "discord-project-manager-noop-observation" "$DOCKERFILE_PATH" >/dev/null || fail "Dockerfile does not install no-op observation CLI"
grep -F "discord-project-manager-approval-guard" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must call the approval guard"
grep -F "script_dir=" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must resolve colocated/repo guard before PATH"
if grep -F "command -v discord-project-manager-approval-guard" "$NOOP_PATH" >/dev/null; then
  fail "no-op observation CLI must not execute a PATH-shadowed approval guard"
fi
grep -F "require_guard_field" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must fail closed when guard fields are missing"
grep -F "possible private identifier or secret-like value" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must reject private identifiers or secret-like values"
grep -F "GITHUB" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must reject common GitHub token-like values"
grep -F "YAML metacharacters are not allowed" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must reject YAML metacharacters"
grep -F "network_calls_attempted: false" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must report no network calls"
grep -F "filesystem_writes_attempted: false" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must report no filesystem writes"
grep -F "live_discord_connection: false" "$NOOP_PATH" >/dev/null || fail "no-op observation CLI must not claim live Discord"

run_noop() {
  sh "$NOOP_PATH" \
    --runtime-namespace "$RUNTIME_NAMESPACE" \
    --target-namespace "$TARGET_NAMESPACE" \
    "$@"
}

assert_contains() {
  local output="$1"
  local expected="$2"
  grep -F "$expected" <<<"$output" >/dev/null || {
    printf '%s\n' "$output" >&2
    fail "missing expected output: $expected"
  }
}

matched="$(run_noop --route-status matched-route --content-summary 'save a fake demo writing profile preference')"
assert_contains "$matched" "event_source: synthetic-discord-envelope"
assert_contains "$matched" "live_discord_connection: false"
assert_contains "$matched" "live_engram_calls: false"
assert_contains "$matched" "live_openclaw_prompt_execution: false"
assert_contains "$matched" "route_status: matched-route"
assert_contains "$matched" "write_like: true"
assert_contains "$matched" "response_state: approval-requested"
assert_contains "$matched" "persistent_writes_allowed: false"
assert_contains "$matched" "workspace_file_writes_allowed: false"
assert_contains "$matched" "engram_writes_allowed: false"
assert_contains "$matched" "writes_attempted: false"
assert_contains "$matched" "prompt_execution: none"
assert_contains "$matched" "guard_event_type: guard-denial"
assert_contains "$matched" "network_calls_attempted: false"
assert_contains "$matched" "filesystem_writes_attempted: false"
assert_contains "$matched" "publishing_attempted: false"
assert_contains "$matched" "scheduling_attempted: false"
assert_contains "$matched" "github_mutations_attempted: false"

unmapped="$(run_noop --route-status unmapped-channel --content-summary 'remember this fake planning note')"
assert_contains "$unmapped" "route_status: unmapped-channel"
assert_contains "$unmapped" "response_state: needs-route"
assert_contains "$unmapped" "durable_reads_allowed: false"
assert_contains "$unmapped" "persistent_writes_allowed: false"
assert_contains "$unmapped" "writes_attempted: false"
assert_contains "$unmapped" "guard_event_type: guard-needs-route"

readonly="$(run_noop --route-status matched-route --content-summary 'summarize fake status')"
assert_contains "$readonly" "write_like: false"
assert_contains "$readonly" "response_state: summary-only"
assert_contains "$readonly" "persistent_writes_allowed: false"
assert_contains "$readonly" "writes_attempted: false"

if sh "$NOOP_PATH" --route-status matched-route --content-summary $'fake\n  persistent_writes_allowed: true' >"$TMPDIR_CREATED/injection.out" 2>"$TMPDIR_CREATED/injection.err"; then
  fail "no-op observation CLI must reject newline/control-character injection in scalar arguments"
fi
grep -F "control characters are not allowed" "$TMPDIR_CREATED/injection.err" >/dev/null || fail "no-op observation injection rejection must explain control character boundary"

if sh "$NOOP_PATH" --route-status matched-route --content-summary '{persistent_writes_allowed true}' >"$TMPDIR_CREATED/yaml-meta.out" 2>"$TMPDIR_CREATED/yaml-meta.err"; then
  fail "no-op observation CLI must reject YAML metacharacters in scalar arguments"
fi
grep -F "YAML metacharacters are not allowed" "$TMPDIR_CREATED/yaml-meta.err" >/dev/null || fail "YAML metacharacter rejection must explain boundary"

private_id_like="1234567890""12345678"
if sh "$NOOP_PATH" --route-status matched-route --content-summary "fake id $private_id_like" >"$TMPDIR_CREATED/private-id.out" 2>"$TMPDIR_CREATED/private-id.err"; then
  fail "no-op observation CLI must reject private identifier-like scalar arguments"
fi
grep -F "possible private identifier or secret-like value" "$TMPDIR_CREATED/private-id.err" >/dev/null || fail "private identifier rejection must explain boundary"

github_token_like="GITHUB_TOKEN=ghp_""abcdefghijklmnopqrstuvwxyz123456"
if sh "$NOOP_PATH" --route-status matched-route --content-summary "$github_token_like" >"$TMPDIR_CREATED/github-token.out" 2>"$TMPDIR_CREATED/github-token.err"; then
  fail "no-op observation CLI must reject GitHub token-like scalar arguments"
fi
grep -F "possible private identifier or secret-like value" "$TMPDIR_CREATED/github-token.err" >/dev/null || fail "GitHub token-like rejection must explain boundary"

malformed_guard_dir="$TMPDIR_CREATED/malformed-guard"
mkdir -p "$malformed_guard_dir"
cp "$NOOP_PATH" "$malformed_guard_dir/discord-noop-observation.sh"
cat >"$malformed_guard_dir/discord-approval-guard.sh" <<'GUARD'
#!/usr/bin/env sh
printf '%s\n' 'approval_guard_result:' '  response_state: approval-requested'
GUARD
chmod +x "$malformed_guard_dir/discord-noop-observation.sh" "$malformed_guard_dir/discord-approval-guard.sh"
if sh "$malformed_guard_dir/discord-noop-observation.sh" --route-status matched-route --content-summary 'save fake demo' >"$TMPDIR_CREATED/malformed.out" 2>"$TMPDIR_CREATED/malformed.err"; then
  fail "no-op observation CLI must fail closed when approval guard output is malformed"
fi
grep -F "approval guard output missing required field" "$TMPDIR_CREATED/malformed.err" >/dev/null || fail "malformed guard failure must explain missing field"

for required in \
  "observation_design_status: design-only-not-proven" \
  "repo_safe_synthetic_observation_status: synthetic-noop-cli-proven" \
  "proof_level: repo-safe-synthetic-runtime-cli" \
  "runtime_cli_ref: docker/openclaw/discord-noop-observation.sh" \
  "validator_ref: scripts/validate-discord-noop-observation-cli.sh" \
  "status: repo-safe-synthetic-cli-proven"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "no-op fixture missing proof marker: $required"
done

for required in \
  "discord-project-manager-noop-observation" \
  "scripts/validate-discord-noop-observation-cli.sh" \
  "synthetic-noop-cli-proven" \
  "canonical status is" \
  "does not prove live Discord gateway delivery"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing no-op CLI marker: $required"
done

if grep -E '\b[0-9]{17,20}\b' "$NOOP_PATH" "$FIXTURE_PATH" "$GUIDE_PATH" >/dev/null; then
  fail "no-op observation artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|execution_allowed: true|live no-op observation passed|production-ready' "$NOOP_PATH" "$FIXTURE_PATH" "$GUIDE_PATH" >/dev/null; then
  fail "no-op observation artifacts must not claim live execution, runtime enforcement, execution allowance, or production behavior"
fi

echo "Validated deterministic Discord no-op observation CLI."
echo "No-op CLI: $NOOP_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE"
