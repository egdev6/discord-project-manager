#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_REDACTED_NOOP_INGESTION_PACKET_FIXTURE:-examples/private-redacted-noop-ingestion-packet.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
TOPOLOGY_FIXTURE="examples/private-topology-readiness-packet.fake.yaml"
NOOP_PROOF_FIXTURE="examples/private-discord-engram-noop-observation-proof.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$TOPOLOGY_FIXTURE" "$NOOP_PROOF_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-redacted-noop-ingestion-packet" \
  "issue: 264" \
  "parent_issue: 211" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "live_discord_message_sent: false" \
  "live_engram_write_attempted: false" \
  "live_readback_attempted: false" \
  "uses_real_discord_ids: false" \
  "raw_discord_chat_logs_included: false" \
  "raw_private_payload_included: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "private_redacted_event_ingestion_proof_level: repo-safe-schema-packet" \
  "private_redacted_event_ingestion_proven: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "raw_event_payload_committed: false" \
  "expected_status: pending-private-run" \
  "allowed_now: false" \
  "readiness_result: blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "ingestion packet fixture missing marker: $required"
done

for required in \
  "Private redacted no-op ingestion packet" \
  "examples/private-redacted-noop-ingestion-packet.fake.yaml" \
  "scripts/validate-private-redacted-noop-ingestion-packet.sh" \
  "repo-safe schema packet" \
  "does not prove private redacted event ingestion" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing ingestion packet marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

class UniqueKeyLoader(yaml.SafeLoader):
    pass

def construct_mapping(loader, node, deep=False):
    mapping = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in mapping:
            raise SystemExit(f"duplicate YAML key rejected: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping

UniqueKeyLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping)

data = yaml.load(Path(sys.argv[1]).read_text(), Loader=UniqueKeyLoader)
runtime = sys.argv[2]

expected_top_level = {
    "schema_version": 1,
    "fixture_type": "fake-demo",
    "safe_for_repo": True,
    "privacy_reviewed": True,
    "contract": "private-redacted-noop-ingestion-packet",
    "issue": 264,
    "parent_issue": 211,
}
for key, expected in expected_top_level.items():
    if data.get(key) != expected:
        raise SystemExit(f"ingestion packet top-level field mismatch for {key}: expected {expected!r}, got {data.get(key)!r}")

false_flags = [
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution",
    "live_discord_message_sent", "live_engram_write_attempted", "live_readback_attempted",
    "uses_real_discord_ids", "raw_discord_chat_logs_included", "raw_private_payload_included",
    "screenshots_included", "secrets_included", "private_redacted_event_ingestion_proven",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"ingestion packet must keep {key}: false")
if data.get("private_redacted_event_ingestion_proof_level") != "repo-safe-schema-packet":
    raise SystemExit("ingestion proof level mismatch")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-topology-readiness-packet.fake.yaml",
    "examples/private-discord-engram-noop-observation-proof.fake.yaml",
    "docs/operations/private-discord-manual-verification-guide.md",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

envelope = data.get("redacted_event_envelope", {})
expected_envelope = {
    "event_source": "private-discord-redacted-envelope",
    "guild_ref": "<guild-id>",
    "channel_ref": "<channel-id>",
    "message_ref": "<message-id>",
    "actor_ref": "<operator-ref>",
    "route_ref": "route/<project-key>/private-context",
    "runtime_namespace": runtime,
    "target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "content_summary": "redacted write-like no-op observation request",
    "raw_content_committed": False,
    "raw_event_payload_committed": False,
    "placeholders_only": True,
}
if envelope != expected_envelope:
    raise SystemExit("redacted event envelope drifted")

expectations = data.get("no_op_ingestion_expectations", {})
expected_expectations = {
    "expected_status": "pending-private-run",
    "expected_response_state": "approval-requested",
    "expected_guard_event_type": "guard-denial",
    "prompt_execution": "none",
    "persistent_writes_allowed": False,
    "workspace_file_writes_allowed": False,
    "filesystem_writes_allowed": False,
    "memory_writes_allowed": False,
    "engram_writes_allowed": False,
    "network_calls_attempted": False,
    "publishing_attempted": False,
    "scheduling_attempted": False,
    "github_mutations_attempted": False,
    "writes_attempted": False,
    "evidence_policy": "sanitized-summary-only",
}
if expectations != expected_expectations:
    raise SystemExit("no-op ingestion expectations drifted")

expected_schema = {
    "required_sections": [
        "topology_summary", "redacted_event_summary", "route_result", "approval_state",
        "no_op_boundaries", "blocked_reason", "operator_decision",
    ],
    "allowed_result_values": ["not-run", "pending-private-run", "blocked", "pass-summary"],
    "forbidden_result_values": ["live-write-passed", "live-readback-passed", "production-ready"],
}
if data.get("private_run_evidence_schema", {}) != expected_schema:
    raise SystemExit("private run evidence schema drifted")

expected_checks = {
    "private-topology-prepared": ("pending-private-run", "placeholder-summary-only"),
    "redacted-event-captured": ("pending-private-run", "sanitized-summary-only"),
    "no-op-ingestion-executed": ("not-run", "sanitized-summary-only"),
    "prompt-and-write-surfaces-blocked": ("not-run", "sanitized-summary-only"),
    "sanitized-evidence-reviewed": ("not-reviewed", "review-summary-only"),
}
items = data.get("private_checklist", [])
ids = [item.get("id") for item in items]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate private checklist ids rejected: {duplicates}")
checks = {item.get("id"): item for item in items}
if set(checks) != set(expected_checks):
    raise SystemExit("private checklist coverage drifted")
for check_id, (expected_status, expected_evidence) in expected_checks.items():
    check = checks[check_id]
    expected_check = {
        "id": check_id,
        "status": expected_status,
        "evidence_allowed_in_repo": expected_evidence,
        "fail_closed_if_missing": True,
    }
    if check != expected_check:
        raise SystemExit(f"private checklist entry drifted for {check_id}")

expected_execution = {
    "allowed_now": False,
    "readiness_result": "blocked",
    "stop_reasons": [
        "private redacted no-op ingestion is not run in repo",
        "raw event payloads are forbidden in repo",
        "prompt execution and write surfaces must remain blocked",
        "explicit write/readback execution approval is not granted",
        "no private write/readback was executed by this issue",
    ],
    "next_safe_actions": [
        "run private redacted no-op ingestion outside repo with summary-only evidence",
        "review sanitized no-op ingestion summary before any write-like traffic",
        "keep #211 open until actual private execution and readback are separately approved executed and reviewed",
    ],
}
if data.get("execution_gate", {}) != expected_execution:
    raise SystemExit("ingestion packet execution gate drifted")

expected_policy = {
    "allowed": [
        "redacted event summary",
        "placeholder namespace refs",
        "blocked status summaries",
        "pending-private-run summaries",
        "validator command names and pass/fail summaries",
    ],
    "forbidden": [
        "real Discord guild/channel/user/message IDs",
        "credentials or .env values",
        "screenshots",
        "raw logs",
        "transcripts",
        "private payloads",
        "raw event payloads",
        "raw Engram exports",
        "SQL dumps",
    ],
}
if data.get("sanitized_evidence_policy", {}) != expected_policy:
    raise SystemExit("sanitized evidence policy drifted")

expected_non_goals = [
    "executing live Discord messages",
    "executing an Engram write",
    "executing a live readback from Engram",
    "proving private redacted event ingestion",
    "updating readiness to available-and-proven",
    "closing issue 211",
]
if data.get("non_goals", []) != expected_non_goals:
    raise SystemExit("non-goals drifted")
PY

if [[ "${PRIVATE_READINESS_CROSSCHECK_SKIP:-0}" != "1" ]]; then
  bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
fi
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-topology-readiness-packet.sh >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-discord-engram-noop-observation-proof.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "ingestion packet artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|raw_event_payload_committed: true|screenshots_included: true|secrets_included: true|private_redacted_event_ingestion_proven: true|readiness_gate_updated: true|allowed_now: true|readiness_result: ready|available-and-proven-now|issue 211 closed' "${review_paths[@]}" >/dev/null; then
  fail "ingestion packet artifacts must not claim live execution, readiness update, closure, or production behavior"
fi

echo "Validated fake private redacted no-op ingestion packet."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
