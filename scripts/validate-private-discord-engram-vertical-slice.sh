#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_DISCORD_ENGRAM_SLICE_FIXTURE:-examples/private-discord-engram-vertical-slice.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
APPROVAL_DOC="docs/operations/discord-approval-responses.md"
ORCHESTRATOR_DOC="docs/architecture/discord-runtime-orchestrator.md"
RESOLVER_DOC="docs/architecture/discord-effective-runtime-resolver.md"
AUDIT_DOC="docs/architecture/discord-durable-change-audit.md"
BACKUP_DOC="docs/operations/private-runtime-backup-restore.md"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$APPROVAL_DOC" "$ORCHESTRATOR_DOC" "$RESOLVER_DOC" "$AUDIT_DOC" "$BACKUP_DOC"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-discord-engram-vertical-slice" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "raw_discord_chat_logs_included: false" \
  "raw_private_payload_included: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "workspace_file_writes_allowed: false" \
  "writes_attempted: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "exact_approval_phrase_required: approve write" \
  "durable_writes_before_approval: false" \
  "workspace_writes_before_approval: false" \
  "approval_enforcement_runtime_proven: false" \
  "repo_evidence_status: template-only"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing marker: $required"
done

for required in \
  "Private Discord-to-Engram vertical slice evidence pack" \
  "examples/private-discord-engram-vertical-slice.fake.yaml" \
  "scripts/validate-private-discord-engram-vertical-slice.sh" \
  "template/validator only" \
  "does not close #211"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual verification guide missing marker: $required"
done

for required in \
  "approval boundary is not yet enforced" \
  "approve write" \
  "approval-requested"; do
  grep -F "$required" "$APPROVAL_DOC" >/dev/null || fail "approval doc missing marker: $required"
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
    "workspace_file_writes_allowed",
    "writes_attempted",
    "publishing_enabled",
    "scheduling_enabled",
    "buffer_activity_enabled",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"fixture must keep {key}: false")

if data.get("safe_for_repo") is not True or data.get("fixture_type") != "fake-demo":
    raise SystemExit("fixture must be fake-demo and safe_for_repo")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("fixture runtime namespace contract mismatch")

required_contracts = {
    "docs/operations/private-discord-manual-verification-guide.md",
    "docs/operations/discord-approval-responses.md",
    "docs/architecture/discord-runtime-orchestrator.md",
    "docs/architecture/openclaw-artifact-classification.md",
    "docs/architecture/discord-effective-runtime-resolver.md",
    "docs/architecture/discord-durable-change-audit.md",
    "docs/operations/private-runtime-backup-restore.md",
    "docs/security/data-handling.md",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("fixture source contracts drifted")

boundary = data.get("operator_boundary", {})
for key in ["real_identifiers_committed", "private_credentials_committed", "raw_runtime_exports_committed"]:
    if boundary.get(key) is not False:
        raise SystemExit(f"operator boundary must keep {key}: false")
if boundary.get("rehearsal_result_claim") != "not-run":
    raise SystemExit("fixture must not claim rehearsal execution")

scenario = data.get("scenario", {})
classification = scenario.get("artifact_classification", {})
expected_classification = {
    "artifact_type": "private_context",
    "persistence_target": "private-runtime",
    "approval_required": True,
    "backup_required": True,
    "deployment_required": False,
    "writeback_policy": "confirmation-required",
}
for key, expected in expected_classification.items():
    if classification.get(key) != expected:
        raise SystemExit(f"classification mismatch for {key}")

routing = scenario.get("routing", {})
if routing.get("runtime_namespace") != runtime:
    raise SystemExit("routing runtime namespace mismatch")
if not str(routing.get("durable_target_namespace", "")).startswith("discord-project-manager/project/"):
    raise SystemExit("durable target namespace must be project-scoped")

resolution = scenario.get("effective_resolution", {})
skills = {item.get("ref"): item for item in resolution.get("skill_refs", [])}
for required in ["skill:openclaw-runtime-orchestrator", "skill:scoped-skill-resolver", "skill:discord-approval-gate"]:
    if skills.get(required, {}).get("required") is not True:
        raise SystemExit(f"missing required skill ref: {required}")
capabilities = {item.get("capability"): item for item in resolution.get("capability_permissions", [])}
if capabilities.get("engram", {}).get("permitted") is not True:
    raise SystemExit("Engram capability must be permitted only after approval")
if capabilities.get("filesystem", {}).get("permitted") is not False:
    raise SystemExit("filesystem capability must stay blocked")

approval = data.get("approval_gate", {})
if approval.get("response_state_before_operator_decision") != "approval-requested":
    raise SystemExit("approval state must be approval-requested before decision")
if approval.get("exact_approval_phrase_required") != "approve write":
    raise SystemExit("approval phrase must be exact")
if approval.get("durable_writes_before_approval") is not False or approval.get("workspace_writes_before_approval") is not False:
    raise SystemExit("writes before approval must be forbidden")
if approval.get("approval_enforcement_runtime_proven") is not False:
    raise SystemExit("fixture must not claim runtime approval enforcement")

audit = data.get("expected_audit_record_shape", {})
if audit.get("schema_version") != 1:
    raise SystemExit("expected audit record must declare schema_version: 1")
for key in ["audit_id", "decision_state", "actor_ref", "actor_role", "runtime_namespace", "route", "target", "approval", "provenance", "validation", "rollback", "privacy"]:
    if key not in audit:
        raise SystemExit(f"expected audit record missing {key}")
if audit.get("decision_state") != "approved":
    raise SystemExit("expected audit record must model approved decision state")
if audit.get("runtime_namespace") != runtime:
    raise SystemExit("expected audit runtime namespace mismatch")
if audit.get("actor_ref") == "" or audit.get("actor_role") == "":
    raise SystemExit("expected audit actor fields must be sanitized refs")

target = audit.get("target", {})
for key, expected in {
    "artifact_type": "private_context",
    "subtype": "profile",
    "operation": "update",
    "persistence_target": "private-runtime",
}.items():
    if target.get(key) != expected:
        raise SystemExit(f"expected audit target mismatch for {key}")
if not str(target.get("target_namespace", "")).startswith("discord-project-manager/project/"):
    raise SystemExit("expected audit target namespace must be project-scoped")

approval_record = audit.get("approval", {})
if approval_record.get("required") is not True or approval_record.get("gate") != "discord-approval-gate" or approval_record.get("accepted_phrase") != "approve write" or approval_record.get("decision") != "approve write":
    raise SystemExit("expected audit approval record must require discord-approval-gate and exact approve write")

provenance = audit.get("provenance", {})
for key in ["source", "classification_ref", "resolver_ref", "sanitized_input_summary"]:
    if key not in provenance:
        raise SystemExit(f"expected audit provenance missing {key}")
if provenance.get("source") != "discord-runtime-orchestrator":
    raise SystemExit("expected audit provenance source mismatch")

validation = audit.get("validation", {})
if validation.get("command_ref") != "scripts/validate-private-discord-engram-vertical-slice.sh" or validation.get("result") != "template-only-not-run":
    raise SystemExit("expected audit validation must remain template-only")

rollback = audit.get("rollback", {})
for key in ["restore_hint", "rollback_scope", "backup_ref", "pre_change_snapshot_ref", "restore_command_ref", "verification_step", "owner_ref"]:
    if key not in rollback:
        raise SystemExit(f"expected audit rollback missing {key}")
if rollback.get("restore_command_ref") != "docs/security/data-handling.md#current-recovery-path":
    raise SystemExit("expected audit rollback must reference recovery path")
if not str(rollback.get("backup_ref", "")).startswith("private-backup://demo/"):
    raise SystemExit("expected audit rollback must use private backup demo ref")

privacy = audit.get("privacy", {})
for key in ["raw_transcript_stored", "raw_discord_ids_stored", "screenshots_stored", "private_payload_stored"]:
    if privacy.get(key) is not False:
        raise SystemExit(f"expected audit privacy must keep {key}: false")
if privacy.get("safe_for_repo") is not True:
    raise SystemExit("expected audit privacy must mark safe_for_repo true")

write_plan = data.get("write_plan_after_approval", {})
if write_plan.get("runtime_audit_namespace") != runtime:
    raise SystemExit("write plan audit namespace mismatch")
if write_plan.get("raw_profile_text_committed") is not False:
    raise SystemExit("write plan must forbid raw profile text in repo")

readback = data.get("readback_plan", {})
if readback.get("expected_response_boundary") != "summary-only":
    raise SystemExit("readback response must be summary-only")
if readback.get("raw_private_payload_returned_to_repo") is not False:
    raise SystemExit("readback must not return raw private payload to repo")

notes = data.get("validation_notes", {})
for key in ["docker_health_checked", "discord_message_sent", "approval_preview_observed", "durable_write_observed", "readback_observed"]:
    if notes.get(key) != "not-run":
        raise SystemExit(f"validation note must remain not-run: {key}")
if notes.get("repo_evidence_status") != "template-only":
    raise SystemExit("repo evidence must remain template-only")
PY

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH" "$APPROVAL_DOC" "$ORCHESTRATOR_DOC" "$RESOLVER_DOC" "$AUDIT_DOC" "$BACKUP_DOC")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "private Discord evidence artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|raw_discord_chat_logs_included: true|raw_private_payload_included: true|screenshots_included: true|secrets_included: true|workspace_file_writes_allowed: true|writes_attempted: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|live Discord-to-Engram validation passed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "private Discord evidence artifacts must not claim live, production, persistence, publishing, scheduling, or private-data behavior"
fi

echo "Validated fake private Discord-to-Engram vertical slice evidence contract."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
