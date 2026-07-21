#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_EXECUTION_APPROVAL_PACKET_FIXTURE:-examples/private-execution-approval-packet.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
PROPOSAL_BINDING_FIXTURE="examples/proposal-binding-boundary.fake.yaml"
TOPOLOGY_FIXTURE="examples/private-topology-readiness-packet.fake.yaml"
INGESTION_FIXTURE="examples/private-redacted-noop-ingestion-packet.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$PROPOSAL_BINDING_FIXTURE" "$TOPOLOGY_FIXTURE" "$INGESTION_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-execution-approval-packet" \
  "issue: 266" \
  "parent_issue: 211" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "live_discord_message_sent: false" \
  "live_engram_write_attempted: false" \
  "live_readback_attempted: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "execution_approval_proof_level: repo-safe-decision-packet" \
  "private_execution_approval_granted: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "approval_state: not-granted" \
  "allowed_now: false" \
  "readiness_result: blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "approval packet fixture missing marker: $required"
done

for required in \
  "Private execution approval packet" \
  "examples/private-execution-approval-packet.fake.yaml" \
  "scripts/validate-private-execution-approval-packet.sh" \
  "repo-safe decision packet" \
  "does not grant private execution approval" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing approval packet marker: $required"
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
    "contract": "private-execution-approval-packet",
    "issue": 266,
    "parent_issue": 211,
}
for key, expected in expected_top_level.items():
    if data.get(key) != expected:
        raise SystemExit(f"approval packet top-level field mismatch for {key}: expected {expected!r}, got {data.get(key)!r}")

false_flags = [
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution",
    "live_discord_message_sent", "live_engram_write_attempted", "live_readback_attempted",
    "uses_real_discord_ids", "raw_discord_chat_logs_included", "raw_private_payload_included",
    "screenshots_included", "secrets_included", "private_execution_approval_granted",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"approval packet must keep {key}: false")
if data.get("execution_approval_proof_level") != "repo-safe-decision-packet":
    raise SystemExit("approval proof level mismatch")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

expected_sources = {
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/proposal-binding-boundary.fake.yaml",
    "examples/private-topology-readiness-packet.fake.yaml",
    "examples/private-redacted-noop-ingestion-packet.fake.yaml",
    "docs/operations/private-discord-manual-verification-guide.md",
}
if set(data.get("source_contracts", [])) != expected_sources:
    raise SystemExit("source contracts drifted")

expected_packet = {
    "approval_state": "not-granted",
    "exact_approval_phrase": "approve write",
    "approval_scope": "single-displayed-proposal-only",
    "proposal_ref": "proposal/<proposal-id>",
    "route_ref": "route/<project-key>/private-context",
    "actor_ref": "<operator-ref>",
    "runtime_namespace": runtime,
    "target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "operation_fingerprint": "fingerprint/<operation-fingerprint>",
    "evidence_schema_ref": "private-redacted-noop-ingestion-packet",
    "approval_record_committed": False,
    "broad_approval_allowed": False,
    "stale_approval_allowed": False,
    "cross_target_approval_allowed": False,
    "approval_replay_allowed": False,
    "raw_private_values_printed": False,
}
if data.get("approval_packet", {}) != expected_packet:
    raise SystemExit("approval packet body drifted")

expected_matrix = {
    "no-approval": ("none", "blocked", False, "explicit approval is not granted"),
    "exact-phrase-unbound": ("approve write", "blocked", False, "approval is not bound to proposal route actor target and fingerprint"),
    "broad-approval": ("approve all writes", "blocked", False, "broad approval is not allowed"),
    "stale-approval": ("approve write", "blocked", False, "stale approval is not allowed"),
    "cross-target-approval": ("approve write", "blocked", False, "cross-target approval is not allowed"),
    "repo-artifact-approval": ("approve write", "blocked", False, "repo artifacts cannot grant private execution approval"),
}
items = data.get("approval_matrix", [])
ids = [item.get("id") for item in items]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate approval matrix ids rejected: {duplicates}")
scenarios = {item.get("id"): item for item in items}
if set(scenarios) != set(expected_matrix):
    raise SystemExit("approval matrix coverage drifted")
for scenario_id, (decision, state, allowed, reason) in expected_matrix.items():
    expected = {
        "id": scenario_id,
        "input_decision": decision,
        "expected_state": state,
        "expected_execution_allowed": allowed,
        "reason": reason,
    }
    if scenarios[scenario_id] != expected:
        raise SystemExit(f"approval matrix scenario drifted for {scenario_id}")

expected_execution = {
    "allowed_now": False,
    "readiness_result": "blocked",
    "stop_reasons": [
        "private execution approval is not granted",
        "repo artifacts cannot grant private execution approval",
        "approval must be granted outside repo for one displayed proposal only",
        "private redacted no-op ingestion summary must be reviewed before write/readback",
        "no private write/readback was executed by this issue",
    ],
    "next_safe_actions": [
        "request explicit private execution approval outside repo after reviewing sanitized packets",
        "bind approval to one proposal route actor target namespace and operation fingerprint",
        "keep #211 open until actual private execution and readback are separately approved executed and reviewed",
    ],
}
if data.get("execution_gate", {}) != expected_execution:
    raise SystemExit("approval packet execution gate drifted")

expected_policy = {
    "allowed": [
        "approval state summary",
        "placeholder namespace refs",
        "blocked status summaries",
        "validator command names and pass/fail summaries",
        "operator decision summary without identifiers",
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
    "granting private execution approval",
    "executing live Discord messages",
    "executing an Engram write",
    "executing a live readback from Engram",
    "updating readiness to available-and-proven",
    "closing issue 211",
]
if data.get("non_goals", []) != expected_non_goals:
    raise SystemExit("non-goals drifted")
PY

if [[ "${PRIVATE_READINESS_CROSSCHECK_SKIP:-0}" != "1" ]]; then
  bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
fi
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-proposal-binding-boundary.sh >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-topology-readiness-packet.sh >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-redacted-noop-ingestion-packet.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "approval packet artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|private_execution_approval_granted: true|readiness_gate_updated: true|allowed_now: true|readiness_result: ready|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "approval packet artifacts must not claim approval, live execution, readiness update, closure, or production behavior"
fi

echo "Validated fake private execution approval packet."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
