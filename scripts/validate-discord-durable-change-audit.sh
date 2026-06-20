#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_DURABLE_CHANGE_AUDIT_FIXTURE:-examples/discord-durable-change-audit.fake.yaml}"
DOC_PATH="docs/architecture/discord-durable-change-audit.md"
MEMORY_GATEWAY_DOC="docs/architecture/discord-memory-gateway.md"
DATA_HANDLING_DOC="docs/security/data-handling.md"
APPROVAL_SKILL="skills/discord-approval-gate/SKILL.md"
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

[[ -f "$FIXTURE_PATH" ]] || fail "fixture not found: $FIXTURE_PATH"
[[ -f "$DOC_PATH" ]] || fail "doc not found: $DOC_PATH"
[[ -f "$MEMORY_GATEWAY_DOC" ]] || fail "memory gateway doc not found: $MEMORY_GATEWAY_DOC"
[[ -f "$DATA_HANDLING_DOC" ]] || fail "data handling doc not found: $DATA_HANDLING_DOC"
[[ -f "$APPROVAL_SKILL" ]] || fail "approval skill not found: $APPROVAL_SKILL"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-durable-change-audit" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "live_github_mutations: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "raw_discord_chat_logs_included: false" \
  "private_payload_included: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "durable_memory_writes_allowed: false" \
  "workspace_file_writes_allowed: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "decision_state: proposed" \
  "decision_state: approved" \
  "decision_state: revised" \
  "decision_state: rejected" \
  "decision_state: failed-validation" \
  "artifact_type: private_context" \
  "artifact_type: workflow_skill" \
  "artifact_type: runtime_capability" \
  "persistence_target: private-runtime" \
  "persistence_target: repo" \
  "gate: discord-approval-gate" \
  "accepted_phrase: approve write" \
  "raw_transcript_stored: false" \
  "raw_discord_ids_stored: false" \
  "private_payload_stored: false"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing audit marker: $required"
done

for required in \
  "Discord durable change audit" \
  "Audit record schema" \
  "Decision states" \
  "approved" \
  "revised" \
  "rejected" \
  "discord-approval-gate" \
  "raw Discord transcripts" \
  "private runtime backup/export"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing audit marker: $required"
done

for required in \
  "discord/audit/approval-decision" \
  "audit/provenance" \
  "docs/architecture/discord-durable-change-audit.md"; do
  grep -F "$required" "$MEMORY_GATEWAY_DOC" >/dev/null || fail "memory gateway doc missing audit marker: $required"
done

for required in \
  "Current recovery path" \
  "psql" \
  "tar xzf" \
  "sanitized readback check"; do
  grep -F "$required" "$DATA_HANDLING_DOC" >/dev/null || fail "data handling doc missing recovery marker: $required"
done

for required in \
  "record the final sanitized audit trail" \
  "audit_record" \
  "raw private transcripts"; do
  grep -F "$required" "$APPROVAL_SKILL" >/dev/null || fail "approval skill missing audit marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()
runtime = sys.argv[2]
records = []
current = None
for raw in lines:
    if raw.startswith("  - audit_id:"):
        if current:
            records.append(current)
        current = {"audit_id": raw.split(":", 1)[1].strip(), "pairs": []}
        continue
    if current and raw.startswith("    ") and ":" in raw:
        key, value = raw.strip().split(":", 1)
        current["pairs"].append((key, value.strip()))
if current:
    records.append(current)

if len(records) < 5:
    raise SystemExit("expected at least five audit records covering proposed, approved, revised, rejected, and failed-validation")

states = set()
for rec in records:
    pairs = rec["pairs"]
    d = {}
    for k, v in pairs:
        d.setdefault(k, []).append(v)
    for required in ["decision_state", "actor_ref", "actor_role", "runtime_namespace", "artifact_type", "operation", "persistence_target", "target_ref", "target_namespace", "required", "gate", "decision", "source", "sanitized_input_summary", "restore_hint", "rollback_scope", "backup_ref", "pre_change_snapshot_ref", "restore_command_ref", "verification_step", "owner_ref", "raw_transcript_stored", "raw_discord_ids_stored", "private_payload_stored", "safe_for_repo"]:
        if required not in d:
            raise SystemExit(f"audit record {rec['audit_id']} missing {required}")
    if runtime not in d.get("runtime_namespace", []):
        raise SystemExit(f"audit record {rec['audit_id']} has wrong runtime namespace")
    if d["raw_transcript_stored"][-1] != "false" or d["raw_discord_ids_stored"][-1] != "false" or d["private_payload_stored"][-1] != "false":
        raise SystemExit(f"audit record {rec['audit_id']} stores raw/private material")
    states.add(d["decision_state"][-1])
    if d["decision_state"][-1] == "approved" and d.get("accepted_phrase", [""])[-1] != "approve write":
        raise SystemExit(f"approved audit record {rec['audit_id']} must include accepted approve write phrase")
    if d["decision_state"][-1] == "failed-validation":
        if d.get("result", [""])[-1] != "failed-demo":
            raise SystemExit(f"failed-validation audit record {rec['audit_id']} must carry failed validation result")
        for required_recovery in ["backup_ref", "pre_change_snapshot_ref", "restore_command_ref", "verification_step", "owner_ref"]:
            if d.get(required_recovery, ["none"])[-1] == "none":
                raise SystemExit(f"failed-validation audit record {rec['audit_id']} missing concrete {required_recovery}")
    if d["persistence_target"][-1] == "private-runtime" and "include_in_private_export" not in d:
        raise SystemExit(f"private runtime audit record {rec['audit_id']} missing private export flag")

for required_state in ["proposed", "approved", "revised", "rejected", "failed-validation"]:
    if required_state not in states:
        raise SystemExit(f"missing audit decision state {required_state}")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$MEMORY_GATEWAY_DOC" "$DATA_HANDLING_DOC" "$APPROVAL_SKILL")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "audit artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "$FIXTURE_PATH" "$DOC_PATH" "$MEMORY_GATEWAY_DOC" "$APPROVAL_SKILL" >/dev/null; then
  fail "audit contract artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_prompt_execution: true|live_github_mutations: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|raw_discord_chat_logs_included: true|private_payload_included: true|screenshots_included: true|secrets_included: true|durable_memory_writes_allowed: true|workspace_file_writes_allowed: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|public Discord validation passed|live Discord validation passed|uses production credentials|production credentials enabled' "${review_paths[@]}" >/dev/null; then
  fail "audit artifacts must not claim live, production, private content, persistence, publishing, scheduling, or public Discord behavior"
fi

echo "Validated fake Discord durable change audit contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Memory gateway doc: $MEMORY_GATEWAY_DOC"
echo "Data handling doc: $DATA_HANDLING_DOC"
echo "Approval skill: $APPROVAL_SKILL"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
