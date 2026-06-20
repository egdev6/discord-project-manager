#!/usr/bin/env bash
set -euo pipefail

HARNESS_PATH="docker/openclaw/private-noop-ingestion-review-harness.sh"
DOCKERFILE_PATH="docker/openclaw/Dockerfile"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
REVIEW_PACKET_VALIDATOR="scripts/validate-private-noop-ingestion-evidence-review-packet.sh"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
TARGET_NAMESPACE_CONTRACT="discord-project-manager/project/<project-key>/private-context"
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

for path in "$HARNESS_PATH" "$DOCKERFILE_PATH" "$GUIDE_PATH" "$REVIEW_PACKET_VALIDATOR"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

bash -n "$HARNESS_PATH" || fail "private no-op ingestion review harness has invalid shell syntax"

grep -F "discord-project-manager-private-noop-ingestion-review-harness" "$DOCKERFILE_PATH" >/dev/null || fail "Dockerfile does not install private no-op ingestion review harness"
grep -F "repo-safe-sanitized-review-harness" "$HARNESS_PATH" >/dev/null || fail "harness must report repo-safe sanitized review mode"
grep -F "readiness_available_and_proven: false" "$HARNESS_PATH" >/dev/null || fail "harness must keep readiness blocked"
grep -F "issue_211_status: blocked" "$HARNESS_PATH" >/dev/null || fail "harness must report issue 211 blocked"
grep -F "live_discord_connection: false" "$HARNESS_PATH" >/dev/null || fail "harness must not claim live Discord connection"
grep -F "live_engram_calls: false" "$HARNESS_PATH" >/dev/null || fail "harness must not claim live Engram calls"
grep -F "live_engram_write_attempted: false" "$HARNESS_PATH" >/dev/null || fail "harness must not claim Engram writes"
grep -F "live_readback_attempted: false" "$HARNESS_PATH" >/dev/null || fail "harness must not claim readback"

grep -F "Private no-op ingestion review harness" "$GUIDE_PATH" >/dev/null || fail "manual guide missing review harness section"
grep -F "discord-project-manager-private-noop-ingestion-review-harness" "$GUIDE_PATH" >/dev/null || fail "manual guide missing installed harness command"
grep -F "repo-safe sanitized review harness" "$GUIDE_PATH" >/dev/null || fail "manual guide must describe repo-safe harness mode"
grep -F "does not prove private no-op ingestion occurred" "$GUIDE_PATH" >/dev/null || fail "manual guide must keep private ingestion proof blocked"

field_value() {
  local output="$1"
  local field="$2"
  awk -F': ' -v key="  $field" '$1 == key { print $2; exit }' <<<"$output"
}

assert_field_equals() {
  local output="$1"
  local field="$2"
  local expected="$3"
  local context="$4"
  local actual
  actual="$(field_value "$output" "$field")"
  [[ -n "$actual" ]] || fail "$context missing field: $field"
  [[ "$actual" == "$expected" ]] || {
    printf '%s\n' "$output" >&2
    fail "$context expected $field=$expected but got $actual"
  }
}

assert_common_safe_fields() {
  local output="$1"
  local context="$2"
  assert_field_equals "$output" "evidence_mode" "repo-safe-sanitized-review-harness" "$context"
  assert_field_equals "$output" "runtime_namespace" "$RUNTIME_NAMESPACE_CONTRACT" "$context"
  assert_field_equals "$output" "target_namespace" "$TARGET_NAMESPACE_CONTRACT" "$context"
  assert_field_equals "$output" "live_discord_connection" "false" "$context"
  assert_field_equals "$output" "live_engram_calls" "false" "$context"
  assert_field_equals "$output" "live_openclaw_prompt_execution" "false" "$context"
  assert_field_equals "$output" "live_discord_message_received" "false" "$context"
  assert_field_equals "$output" "live_discord_message_sent" "false" "$context"
  assert_field_equals "$output" "live_engram_write_attempted" "false" "$context"
  assert_field_equals "$output" "live_readback_attempted" "false" "$context"
  assert_field_equals "$output" "uses_real_discord_ids" "false" "$context"
  assert_field_equals "$output" "readiness_available_and_proven" "false" "$context"
  assert_field_equals "$output" "issue_211_status" "blocked" "$context"
}

run_harness() {
  sh "$HARNESS_PATH" "$@"
}

check_scenario() {
  local scenario="$1"
  local review_state="$2"
  local acceptance_allowed="$3"
  local operator_attestation="$4"
  local approval_binding="$5"
  local sanitized_summary="$6"
  local raw_private="$7"
  local unsupported_claim="$8"
  local write_readback="$9"
  local reason="${10}"
  local output
  output="$(run_harness --scenario "$scenario")"
  assert_common_safe_fields "$output" "$scenario"
  assert_field_equals "$output" "scenario" "$scenario" "$scenario"
  assert_field_equals "$output" "review_state" "$review_state" "$scenario"
  assert_field_equals "$output" "acceptance_allowed" "$acceptance_allowed" "$scenario"
  assert_field_equals "$output" "operator_attestation_present" "$operator_attestation" "$scenario"
  assert_field_equals "$output" "approval_binding_present" "$approval_binding" "$scenario"
  assert_field_equals "$output" "sanitized_summary_present" "$sanitized_summary" "$scenario"
  assert_field_equals "$output" "raw_private_evidence_present" "$raw_private" "$scenario"
  assert_field_equals "$output" "unsupported_success_claim" "$unsupported_claim" "$scenario"
  assert_field_equals "$output" "write_or_readback_attempted" "$write_readback" "$scenario"
  assert_field_equals "$output" "reason" "$reason" "$scenario"
}

check_scenario "not-run" "blocked" "false" "false" "false" "false" "false" "false" "false" "private no-op ingestion has not been run or reviewed"
check_scenario "pass-summary" "pass-summary" "false" "true" "true" "true" "false" "false" "false" "sanitized no-op ingestion summary is reviewable but cannot be accepted as write/readback readiness proof"
check_scenario "missing-approval-binding" "blocked" "false" "true" "false" "true" "false" "false" "false" "approval binding reference is missing"
check_scenario "missing-operator-attestation" "blocked" "false" "false" "true" "true" "false" "false" "false" "operator attestation is missing"
check_scenario "raw-private-evidence" "blocked" "false" "true" "true" "true" "true" "false" "false" "raw private evidence is forbidden"
check_scenario "unsupported-success-claim" "blocked" "false" "true" "true" "true" "false" "true" "false" "no-op ingestion review cannot claim write/readback readiness"
check_scenario "write-readback-attempt" "blocked" "false" "true" "true" "true" "false" "false" "true" "write/readback attempts are outside this harness"

if sh "$HARNESS_PATH" --scenario unknown >"$TMPDIR_CREATED/unknown.out" 2>"$TMPDIR_CREATED/unknown.err"; then
  fail "harness must fail closed for unknown scenarios"
fi
grep -F "unknown scenario: unknown" "$TMPDIR_CREATED/unknown.err" >/dev/null || fail "unknown scenario failure must explain scenario"

if grep -E '\b[0-9]{17,20}\b' "$HARNESS_PATH" "$GUIDE_PATH" >/dev/null; then
  fail "review harness artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'acceptance_allowed: true|live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_received: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|readiness_available_and_proven: true|issue 211 closed|production-ready' "$HARNESS_PATH" "$GUIDE_PATH" >/dev/null; then
  fail "review harness artifacts must not claim private execution, readiness, closure, or production behavior"
fi

PRIVATE_NOOP_EVIDENCE_SKIP_READINESS_CROSSCHECK=1 bash "$REVIEW_PACKET_VALIDATOR" >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

echo "Validated private no-op ingestion review harness."
echo "Harness: $HARNESS_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
