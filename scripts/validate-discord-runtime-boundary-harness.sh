#!/usr/bin/env bash
set -euo pipefail

HARNESS_PATH="docker/openclaw/discord-runtime-boundary-harness.sh"
GUARD_PATH="docker/openclaw/discord-approval-guard.sh"
NOOP_PATH="docker/openclaw/discord-noop-observation.sh"
DOCKERFILE_PATH="docker/openclaw/Dockerfile"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
RUNTIME_DOC_PATH="docs/operations/docker-runtime.md"
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

for path in "$HARNESS_PATH" "$GUARD_PATH" "$NOOP_PATH" "$DOCKERFILE_PATH" "$GUIDE_PATH" "$RUNTIME_DOC_PATH"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

bash -n "$HARNESS_PATH" || fail "runtime boundary harness has invalid shell syntax"

grep -F "discord-project-manager-runtime-boundary-harness" "$DOCKERFILE_PATH" >/dev/null || fail "Dockerfile does not install runtime boundary harness"
grep -F "discord-project-manager-approval-guard" "$HARNESS_PATH" >/dev/null || fail "harness must resolve approval guard helper"
grep -F "discord-project-manager-noop-observation" "$HARNESS_PATH" >/dev/null || fail "harness must resolve no-op observation helper"
grep -F "synthetic-container-boundary-only" "$HARNESS_PATH" >/dev/null || fail "harness must report synthetic container boundary evidence mode"
grep -F "readiness_available_and_proven: false" "$HARNESS_PATH" >/dev/null || fail "harness must keep readiness blocked"

grep -F "discord-project-manager-runtime-boundary-harness" "$GUIDE_PATH" >/dev/null || fail "manual guide missing runtime boundary harness command"
grep -F "container boundary evidence only" "$GUIDE_PATH" >/dev/null || fail "manual guide must describe container boundary-only evidence"
grep -F "does not prove live Discord gateway delivery" "$GUIDE_PATH" >/dev/null || fail "manual guide must keep live Discord proof blocked"
grep -F "discord-project-manager-runtime-boundary-harness" "$RUNTIME_DOC_PATH" >/dev/null || fail "docker runtime guide missing harness command"

grep -F "issue_211_status: blocked" "$HARNESS_PATH" >/dev/null || fail "harness must report issue 211 blocked"

run_harness() {
  sh "$HARNESS_PATH" "$@"
}

assert_contains() {
  local output="$1"
  local expected="$2"
  grep -F "$expected" <<<"$output" >/dev/null || {
    printf '%s\n' "$output" >&2
    fail "missing expected output: $expected"
  }
}

normal_output="$(run_harness)"
assert_contains "$normal_output" "evidence_mode: synthetic-container-boundary-only"
assert_contains "$normal_output" "live_discord_delivery_proven: false"
assert_contains "$normal_output" "private_redacted_event_ingestion_proven: false"
assert_contains "$normal_output" "readiness_available_and_proven: false"
assert_contains "$normal_output" "matched_no_approval_state: approval-requested"
assert_contains "$normal_output" "matched_exact_approval_state: approval-verification-required"
assert_contains "$normal_output" "matched_exact_approval_persistent_writes_allowed: false"
assert_contains "$normal_output" "unmapped_state: needs-route"
assert_contains "$normal_output" "unmapped_durable_reads_allowed: false"
assert_contains "$normal_output" "noop_network_calls_attempted: false"
assert_contains "$normal_output" "noop_filesystem_writes_attempted: false"
assert_contains "$normal_output" "noop_workspace_file_writes_allowed: false"
assert_contains "$normal_output" "noop_engram_writes_allowed: false"
assert_contains "$normal_output" "noop_publishing_attempted: false"
assert_contains "$normal_output" "noop_scheduling_attempted: false"
assert_contains "$normal_output" "noop_github_mutations_attempted: false"
assert_contains "$normal_output" "approval_memory_writes_allowed: false"
assert_contains "$normal_output" "approval_publishing_allowed: false"
assert_contains "$normal_output" "approval_scheduling_allowed: false"
assert_contains "$normal_output" "issue_211_status: blocked"

cat >"$TMPDIR_CREATED/discord-project-manager-noop-observation" <<'NOOP_MALFORMED'
#!/usr/bin/env sh
printf '%s\n' 'noop_observation_result:' '  route_status: matched-route'
NOOP_MALFORMED
cat >"$TMPDIR_CREATED/discord-project-manager-approval-guard" <<'GUARD_PLACEHOLDER'
#!/usr/bin/env sh
printf '%s\n' 'approval_guard_result:' '  response_state: approval-verification-required'
GUARD_PLACEHOLDER
cp "$HARNESS_PATH" "$TMPDIR_CREATED/discord-runtime-boundary-harness.sh"
chmod +x "$TMPDIR_CREATED/discord-project-manager-noop-observation" "$TMPDIR_CREATED/discord-project-manager-approval-guard" "$TMPDIR_CREATED/discord-runtime-boundary-harness.sh"
if sh "$TMPDIR_CREATED/discord-runtime-boundary-harness.sh" >"$TMPDIR_CREATED/malformed-noop.out" 2>"$TMPDIR_CREATED/malformed-noop.err"; then
  fail "harness must fail closed when no-op helper output is malformed"
fi
grep -F "helper output missing required field" "$TMPDIR_CREATED/malformed-noop.err" >/dev/null || fail "malformed no-op failure must explain missing field"

cat >"$TMPDIR_CREATED/discord-project-manager-noop-observation" <<'NOOP_UNEXPECTED'
#!/usr/bin/env sh
route_status='matched-route'
while [ "$#" -gt 0 ]; do
  case "$1" in
    --route-status)
      shift
      route_status="${1:-}"
      ;;
  esac
  shift || true
done
if [ "$route_status" = 'unmapped-channel' ]; then
  state='needs-route'
  durable_reads='false'
else
  state='approved-for-write'
  durable_reads='true'
fi
cat <<EOF
noop_observation_result:
  route_status: $route_status
  write_like: true
  response_state: $state
  persistent_writes_allowed: false
  workspace_file_writes_allowed: false
  engram_writes_allowed: false
  durable_reads_allowed: $durable_reads
  writes_attempted: false
  prompt_execution: none
  guard_event_type: guard-denial
  network_calls_attempted: false
  filesystem_writes_attempted: false
  publishing_attempted: false
  scheduling_attempted: false
  github_mutations_attempted: false
EOF
NOOP_UNEXPECTED
cat >"$TMPDIR_CREATED/discord-project-manager-approval-guard" <<'GUARD_VALID'
#!/usr/bin/env sh
cat <<EOF
approval_guard_result:
  route_status: matched-route
  write_like: true
  response_state: approval-verification-required
  runtime_namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
  target_namespace: discord-project-manager/project/demo-project/private-context
  prior_proposal_ref: proposal-demo
  exact_approval_received: true
  persistent_writes_allowed: false
  workspace_file_writes_allowed: false
  memory_writes_allowed: false
  engram_writes_allowed: false
  publishing_allowed: false
  scheduling_allowed: false
  durable_reads_allowed: true
  writes_attempted: false
  prompt_execution: none
  allowed_write_scope: none
  audit_required: true
  guard_event_type: guard-approval-verification-required
  operator_signal_required: true
  reason: exact approval phrase received; server-side proposal binding verification required before writes
EOF
GUARD_VALID
chmod +x "$TMPDIR_CREATED/discord-project-manager-noop-observation" "$TMPDIR_CREATED/discord-project-manager-approval-guard"
if sh "$TMPDIR_CREATED/discord-runtime-boundary-harness.sh" >"$TMPDIR_CREATED/unexpected-noop.out" 2>"$TMPDIR_CREATED/unexpected-noop.err"; then
  fail "harness must fail closed when helper output contains unexpected scenario values"
fi
grep -F "matched no approval scenario expected response_state=approval-requested but got approved-for-write" "$TMPDIR_CREATED/unexpected-noop.err" >/dev/null || fail "unexpected no-op value failure must explain scenario mismatch"

cat >"$TMPDIR_CREATED/discord-project-manager-noop-observation" <<'NOOP_VALID'
#!/usr/bin/env sh
route_status='matched-route'
while [ "$#" -gt 0 ]; do
  case "$1" in
    --route-status)
      shift
      route_status="${1:-}"
      ;;
  esac
  shift || true
done
if [ "$route_status" = 'unmapped-channel' ]; then
  state='needs-route'
  durable_reads='false'
else
  state='approval-requested'
  durable_reads='true'
fi
cat <<EOF
noop_observation_result:
  route_status: $route_status
  write_like: true
  response_state: $state
  persistent_writes_allowed: false
  workspace_file_writes_allowed: false
  engram_writes_allowed: false
  durable_reads_allowed: $durable_reads
  writes_attempted: false
  prompt_execution: none
  guard_event_type: guard-denial
  network_calls_attempted: false
  filesystem_writes_attempted: false
  publishing_attempted: false
  scheduling_attempted: false
  github_mutations_attempted: false
EOF
NOOP_VALID
cat >"$TMPDIR_CREATED/discord-project-manager-approval-guard" <<'GUARD_MALFORMED'
#!/usr/bin/env sh
cat <<EOF
approval_guard_result:
  route_status: matched-route
  write_like: true
  response_state: approval-verification-required
  runtime_namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
  target_namespace: discord-project-manager/project/demo-project/private-context
  prior_proposal_ref: proposal-demo
  exact_approval_received: true
  persistent_writes_allowed: false
  workspace_file_writes_allowed: false
  memory_writes_allowed: false
  engram_writes_allowed: false
  publishing_allowed: false
  scheduling_allowed: false
  durable_reads_allowed: true
  writes_attempted: false
  allowed_write_scope: none
  audit_required: true
  guard_event_type: guard-approval-verification-required
  operator_signal_required: true
  reason: malformed helper missing prompt execution
EOF
GUARD_MALFORMED
chmod +x "$TMPDIR_CREATED/discord-project-manager-noop-observation" "$TMPDIR_CREATED/discord-project-manager-approval-guard"
if sh "$TMPDIR_CREATED/discord-runtime-boundary-harness.sh" >"$TMPDIR_CREATED/malformed-guard.out" 2>"$TMPDIR_CREATED/malformed-guard.err"; then
  fail "harness must fail closed when approval guard output is malformed"
fi
grep -F "helper output missing required field: prompt_execution" "$TMPDIR_CREATED/malformed-guard.err" >/dev/null || fail "malformed guard failure must explain missing field"

if grep -E '\b[0-9]{17,20}\b' "$HARNESS_PATH" "$GUIDE_PATH" "$RUNTIME_DOC_PATH" >/dev/null; then
  fail "runtime boundary harness artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_delivery_proven: true|private_redacted_event_ingestion_proven: true|readiness_available_and_proven: true|production-ready|live Discord passed' "$HARNESS_PATH" "$GUIDE_PATH" "$RUNTIME_DOC_PATH" >/dev/null; then
  fail "runtime boundary harness artifacts must not claim live delivery, private ingestion proof, readiness, or production behavior"
fi

echo "Validated deterministic Discord runtime boundary harness."
echo "Harness: $HARNESS_PATH"
echo "Guide: $GUIDE_PATH"
