#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${RUNTIME_APPROVAL_ENFORCEMENT_REPAIR_FIXTURE:-examples/runtime-approval-enforcement-repair.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
SKILL_PATH="skills/discord-approval-gate/SKILL.md"
APPROVAL_DOC="docs/operations/discord-approval-responses.md"
APPROVAL_FIXTURE="examples/discord-approval-gate.fake.yaml"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
NOOP_FIXTURE="examples/private-discord-engram-noop-observation.fake.yaml"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd grep
require_cmd python3

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$SKILL_PATH" "$APPROVAL_DOC" "$APPROVAL_FIXTURE" "$READINESS_FIXTURE" "$NOOP_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: runtime-approval-enforcement-repair" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "repair_design_status: design-only-not-implemented" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "known_failure: write-like private Discord pilot created runtime workspace files before explicit approve write" \
  "required_repair: runtime must enforce approval before any prompt execution or persistence tool call for write-like Discord-originated requests" \
  "invalid_inputs_write_allowed: false" \
  "recovery_required: true" \
  "incident_state: unauthorized-workspace-artifact-created" \
  "guard_denial_event_required: true" \
  "invalid_approval_attempt_event_required: true" \
  "guard_failure_event_required: true" \
  "alert_condition: guard failure or any attempted write before approval" \
  "guard_location: openclaw-discord-entrypoint-before-runner" \
  "fixture_only_evidence_satisfies_runtime_proof: false" \
  "synthetic_fixture_only_satisfies_runtime_proof: false" \
  "updates_readiness_fixture_now: false"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "repair fixture missing marker: $required"
done

for required in \
  "Runtime approval enforcement repair contract" \
  "examples/runtime-approval-enforcement-repair.fake.yaml" \
  "scripts/validate-runtime-approval-enforcement-repair.sh" \
  "design-only-not-implemented" \
  "does not update the readiness gate"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing repair marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

fixture = Path(sys.argv[1])
runtime = sys.argv[2]
data = yaml.safe_load(fixture.read_text())

false_flags = [
    "live_discord_connection",
    "live_engram_calls",
    "live_openclaw_prompt_execution",
    "runtime_enforcement_proven",
    "uses_real_discord_ids",
    "raw_discord_chat_logs_included",
    "raw_private_payload_included",
    "screenshots_included",
    "secrets_included",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"repair fixture must keep {key}: false")
if data.get("repair_design_status") != "design-only-not-implemented":
    raise SystemExit("repair fixture must remain design-only-not-implemented")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "skills/discord-approval-gate/SKILL.md",
    "docs/operations/discord-approval-responses.md",
    "examples/discord-approval-gate.fake.yaml",
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-discord-engram-noop-observation.fake.yaml",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

pre = data.get("pre_approval_enforcement", {})
if pre.get("write_like_detection_required") is not True:
    raise SystemExit("write-like detection must be required")
required_triggers = {"save", "write", "update", "remember", "store", "queue", "ledger", "publish", "schedule"}
if set(pre.get("triggers", [])) != required_triggers:
    raise SystemExit("write-like trigger coverage drifted")
for forbidden in ["prompt execution", "workspace file writes", "filesystem writes", "Engram writes", "durable memory writes", "ledger writes", "queue writes", "publishing", "scheduling", "GitHub mutations"]:
    if forbidden not in pre.get("forbidden_before_approval", []):
        raise SystemExit(f"missing pre-approval forbidden action: {forbidden}")
for allowed in ["classify request", "resolve route metadata", "render response-only approval prompt", "keep response-local audit summary"]:
    if allowed not in pre.get("allowed_before_approval", []):
        raise SystemExit(f"missing safe pre-approval allowed action: {allowed}")

state = data.get("approval_state_machine", {})
if state.get("initial_write_like_state") != "approval-requested":
    raise SystemExit("write-like initial state must be approval-requested")
if state.get("exact_approval_phrase") != "approve write":
    raise SystemExit("approval phrase must be exact")
for invalid in ["approve", "Approve write", "approve write please", "emoji-reaction", "no-reply"]:
    if invalid not in state.get("invalid_approval_inputs", []):
        raise SystemExit(f"missing invalid approval input: {invalid}")
if state.get("invalid_inputs_write_allowed") is not False:
    raise SystemExit("invalid approval inputs must not write")
if state.get("revise_state") != "approval-requested" or state.get("reject_state") != "rejected" or state.get("unmapped_route_state") != "needs-route":
    raise SystemExit("approval state machine drifted")

post = data.get("post_approval_enforcement", {})
if post.get("approved_write_allowed") is not True:
    raise SystemExit("post approval should allow approved write")
for key in ["requires_prior_proposal_ref", "requires_sanitized_audit_record", "requires_rollback_restore_hint", "requires_unauthorized_artifact_cleanup"]:
    if post.get(key) is not True:
        raise SystemExit(f"post approval missing requirement: {key}")
if post.get("allowed_scope") != "displayed-target-only":
    raise SystemExit("post approval write scope must be displayed-target-only")
for key in ["publishing_allowed", "scheduling_allowed", "unrelated_memory_writes_allowed"]:
    if post.get(key) is not False:
        raise SystemExit(f"post approval must keep {key}: false")

recovery = data.get("unauthorized_write_recovery", {})
if recovery.get("recovery_required") is not True:
    raise SystemExit("unauthorized write recovery must be required")
if recovery.get("incident_state") != "unauthorized-workspace-artifact-created":
    raise SystemExit("unauthorized write incident state drifted")
for key in ["immediate_action", "cleanup_scope", "cleanup_requires_operator_review", "restore_hint", "backup_ref", "pre_change_snapshot_ref", "restore_command_ref", "verification_step", "owner_ref", "fix_forward_path"]:
    if key not in recovery:
        raise SystemExit(f"unauthorized write recovery missing {key}")
for required in ["unauthorized workspace files", "partial runtime audit records", "partial durable memory writes if any"]:
    if required not in recovery.get("cleanup_scope", []):
        raise SystemExit(f"recovery cleanup scope missing {required}")
if recovery.get("cleanup_requires_operator_review") is not True:
    raise SystemExit("recovery cleanup must require operator review")
if not str(recovery.get("backup_ref", "")).startswith("private-backup://demo/"):
    raise SystemExit("recovery must include private backup ref")
if not str(recovery.get("pre_change_snapshot_ref", "")).startswith("snapshot:"):
    raise SystemExit("recovery must include snapshot ref")
if recovery.get("restore_command_ref") != "docs/security/data-handling.md#current-recovery-path":
    raise SystemExit("recovery must reference recovery path")
if "no-op observation" not in str(recovery.get("verification_step", "")):
    raise SystemExit("recovery verification must include no-op observation")
if not str(recovery.get("owner_ref", "")).startswith("operator-"):
    raise SystemExit("recovery must include sanitized operator owner")
if "approval lifecycle validator" not in str(recovery.get("fix_forward_path", "")):
    raise SystemExit("recovery fix-forward must rerun approval lifecycle validator")

observability = data.get("observability_contract", {})
for key in ["guard_denial_event_required", "invalid_approval_attempt_event_required", "guard_failure_event_required", "operator_signal_required"]:
    if observability.get(key) is not True:
        raise SystemExit(f"observability missing required flag: {key}")
if observability.get("event_privacy") != "sanitized-metadata-only":
    raise SystemExit("observability events must be sanitized metadata only")
for forbidden in ["raw Discord IDs", "raw transcripts", "private payloads", "credentials"]:
    if forbidden not in observability.get("forbidden_event_content", []):
        raise SystemExit(f"observability missing forbidden content: {forbidden}")
for required in ["event_type", "route_status", "response_state", "approval_status", "writes_attempted", "runtime_namespace_placeholder", "target_namespace_ref"]:
    if required not in observability.get("required_event_fields", []):
        raise SystemExit(f"observability missing event field: {required}")
if observability.get("alert_condition") != "guard failure or any attempted write before approval":
    raise SystemExit("observability alert condition drifted")

guard = data.get("runtime_guard_contract", {})
if guard.get("guard_location") != "openclaw-discord-entrypoint-before-runner":
    raise SystemExit("guard location drifted")
for required in ["workflow skill execution", "model prompt execution", "file tools", "memory tools", "workspace persistence"]:
    if required not in guard.get("must_run_before", []):
        raise SystemExit(f"guard must run before {required}")
if guard.get("denial_response_state") != "approval-requested" or guard.get("denial_is_successful_preview") is not True or guard.get("denial_must_not_throw_unhandled_error") is not True:
    raise SystemExit("guard denial behavior drifted")

plan = data.get("repair_validation_plan", {})
if plan.get("static_contract_validator") != "scripts/validate-runtime-approval-enforcement-repair.sh":
    raise SystemExit("repair validator ref mismatch")
if plan.get("fixture_only_evidence_satisfies_runtime_proof") is not False or plan.get("synthetic_fixture_only_satisfies_runtime_proof") is not False:
    raise SystemExit("fixture-only evidence must not satisfy runtime proof")
for required in ["write-like request returns approval-requested", "invalid approval inputs do not write", "no prompt execution occurs before approval", "no workspace file writes occur before approval", "no Engram/durable memory writes occur before approval", "approved write is limited to displayed target only", "unauthorized workspace artifacts have cleanup and restore path", "guard denial and guard failure events emit sanitized metadata"]:
    if required not in plan.get("required_probe_observations", []):
        raise SystemExit(f"missing future probe observation: {required}")

effect = data.get("readiness_gate_effect", {})
if effect.get("readiness_check_id") != "runtime-approval-enforcement":
    raise SystemExit("repair must map to runtime-approval-enforcement readiness check")
if effect.get("current_status") != "design-only-not-implemented" or effect.get("required_future_status") != "available-and-proven":
    raise SystemExit("repair readiness status drifted")
if effect.get("updates_readiness_fixture_now") is not False:
    raise SystemExit("repair design must not update readiness fixture now")
if effect.get("readiness_fixture_ref") != "examples/private-discord-engram-rehearsal-readiness.fake.yaml":
    raise SystemExit("repair must reference readiness fixture")
PY

bash scripts/validate-discord-approval-gate.sh >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-discord-engram-noop-observation.sh >/dev/null
if [[ "${PRIVATE_READINESS_CROSSCHECK_SKIP:-0}" != "1" ]]; then
  bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
fi

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH" "$SKILL_PATH" "$APPROVAL_DOC" "$APPROVAL_FIXTURE" "$READINESS_FIXTURE" "$NOOP_FIXTURE")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "runtime approval enforcement repair artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|readiness_gate_updated: true|repair_design_status: implemented|fixture_only_evidence_satisfies_runtime_proof: true|synthetic_fixture_only_satisfies_runtime_proof: true|runtime approval enforcement passed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "repair artifacts must not claim live execution, runtime proof, readiness update, or production behavior"
fi

echo "Validated fake runtime approval enforcement repair contract."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
