#!/usr/bin/env sh
set -eu

RUNTIME_NAMESPACE="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
TARGET_NAMESPACE="discord-project-manager/project/demo-project/private-context"
MATCHED_WRITE_REQUEST="save a fake demo writing profile preference"
UNMAPPED_WRITE_REQUEST="remember this fake planning note"
APPROVAL_PHRASE="approve write"
PROPOSAL_REF="proposal-demo"

usage() {
  cat <<'USAGE'
Usage: discord-project-manager-runtime-boundary-harness

Repo-safe synthetic container-side runtime boundary harness.
It composes the approval guard and no-op observation helpers without claiming
live Discord gateway delivery, private event ingestion, or available-and-proven readiness.
USAGE
}

find_helper() {
  installed_name="$1"
  repo_local_path="$2"
  script_dir=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)

  if [ -x "$script_dir/$installed_name" ]; then
    printf '%s\n' "$script_dir/$installed_name"
    return 0
  fi

  if [ -f "$repo_local_path" ]; then
    printf '%s\n' "$repo_local_path"
    return 0
  fi

  echo "required helper not found: $installed_name" >&2
  exit 2
}

require_field() {
  output="$1"
  field="$2"
  value=$(printf '%s\n' "$output" | awk -F': ' -v key="  $field" '$1 == key { print $2; exit }')
  if [ -z "$value" ]; then
    echo "helper output missing required field: $field" >&2
    exit 2
  fi
  printf '%s\n' "$value"
}

assert_field_equals() {
  output="$1"
  field="$2"
  expected="$3"
  context="$4"
  actual=$(require_field "$output" "$field")
  if [ "$actual" != "$expected" ]; then
    echo "$context expected $field=$expected but got $actual" >&2
    exit 2
  fi
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

approval_guard_path=$(find_helper "discord-project-manager-approval-guard" "docker/openclaw/discord-approval-guard.sh")
noop_observation_path=$(find_helper "discord-project-manager-noop-observation" "docker/openclaw/discord-noop-observation.sh")

matched_no_approval_output=$(sh "$noop_observation_path" \
  --route-status matched-route \
  --content-summary "$MATCHED_WRITE_REQUEST" \
  --runtime-namespace "$RUNTIME_NAMESPACE" \
  --target-namespace "$TARGET_NAMESPACE")
assert_field_equals "$matched_no_approval_output" "route_status" "matched-route" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "write_like" "true" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "response_state" "approval-requested" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "persistent_writes_allowed" "false" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "workspace_file_writes_allowed" "false" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "engram_writes_allowed" "false" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "writes_attempted" "false" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "prompt_execution" "none" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "network_calls_attempted" "false" "matched no approval scenario"
assert_field_equals "$matched_no_approval_output" "filesystem_writes_attempted" "false" "matched no approval scenario"

matched_exact_approval_output=$(sh "$approval_guard_path" \
  --route-status matched-route \
  --request "$MATCHED_WRITE_REQUEST" \
  --approval "$APPROVAL_PHRASE" \
  --prior-proposal "$PROPOSAL_REF" \
  --runtime-namespace "$RUNTIME_NAMESPACE" \
  --target-namespace "$TARGET_NAMESPACE")
assert_field_equals "$matched_exact_approval_output" "route_status" "matched-route" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "write_like" "true" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "response_state" "approval-verification-required" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "persistent_writes_allowed" "false" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "workspace_file_writes_allowed" "false" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "engram_writes_allowed" "false" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "writes_attempted" "false" "matched exact approval scenario"
assert_field_equals "$matched_exact_approval_output" "prompt_execution" "none" "matched exact approval scenario"

unmapped_output=$(sh "$noop_observation_path" \
  --route-status unmapped-channel \
  --content-summary "$UNMAPPED_WRITE_REQUEST" \
  --runtime-namespace "$RUNTIME_NAMESPACE" \
  --target-namespace "$TARGET_NAMESPACE")
assert_field_equals "$unmapped_output" "route_status" "unmapped-channel" "unmapped scenario"
assert_field_equals "$unmapped_output" "response_state" "needs-route" "unmapped scenario"
assert_field_equals "$unmapped_output" "durable_reads_allowed" "false" "unmapped scenario"
assert_field_equals "$unmapped_output" "persistent_writes_allowed" "false" "unmapped scenario"
assert_field_equals "$unmapped_output" "workspace_file_writes_allowed" "false" "unmapped scenario"
assert_field_equals "$unmapped_output" "engram_writes_allowed" "false" "unmapped scenario"
assert_field_equals "$unmapped_output" "writes_attempted" "false" "unmapped scenario"
assert_field_equals "$unmapped_output" "prompt_execution" "none" "unmapped scenario"
assert_field_equals "$unmapped_output" "network_calls_attempted" "false" "unmapped scenario"
assert_field_equals "$unmapped_output" "filesystem_writes_attempted" "false" "unmapped scenario"

cat <<EOF
runtime_boundary_harness_result:
  evidence_mode: synthetic-container-boundary-only
  live_discord_delivery_proven: false
  private_redacted_event_ingestion_proven: false
  readiness_available_and_proven: false
  runtime_namespace: $RUNTIME_NAMESPACE
  target_namespace: $TARGET_NAMESPACE
  approval_guard_helper: $approval_guard_path
  noop_observation_helper: $noop_observation_path
  matched_no_approval_state: approval-requested
  matched_exact_approval_state: approval-verification-required
  matched_exact_approval_persistent_writes_allowed: false
  unmapped_state: needs-route
  unmapped_durable_reads_allowed: false
  noop_network_calls_attempted: false
  noop_filesystem_writes_attempted: false
  noop_workspace_file_writes_allowed: false
  noop_engram_writes_allowed: false
  issue_211_status: blocked
EOF
