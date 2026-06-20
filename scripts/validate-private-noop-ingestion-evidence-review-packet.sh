#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_NOOP_INGESTION_EVIDENCE_REVIEW_PACKET_FIXTURE:-examples/private-noop-ingestion-evidence-review-packet.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
INGESTION_FIXTURE="examples/private-redacted-noop-ingestion-packet.fake.yaml"
APPROVAL_FIXTURE="examples/private-execution-approval-packet.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$INGESTION_FIXTURE" "$APPROVAL_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-noop-ingestion-evidence-review-packet" \
  "issue: 268" \
  "parent_issue: 211" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "live_discord_message_received: false" \
  "live_discord_message_sent: false" \
  "live_engram_write_attempted: false" \
  "live_readback_attempted: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "evidence_review_proof_level: repo-safe-review-packet" \
  "private_noop_ingestion_reviewed: false" \
  "private_execution_approval_granted: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "review_state: not-run" \
  "accepted_now: false" \
  "readiness_result: blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "evidence review packet fixture missing marker: $required"
done

for required in \
  "Private no-op ingestion evidence review packet" \
  "examples/private-noop-ingestion-evidence-review-packet.fake.yaml" \
  "scripts/validate-private-noop-ingestion-evidence-review-packet.sh" \
  "repo-safe review packet" \
  "does not prove private no-op ingestion occurred" \
  "does not execute Engram write/readback" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing evidence review packet marker: $required"
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
    "contract": "private-noop-ingestion-evidence-review-packet",
    "issue": 268,
    "parent_issue": 211,
}
for key, expected in expected_top_level.items():
    if data.get(key) != expected:
        raise SystemExit(f"evidence review packet top-level field mismatch for {key}: expected {expected!r}, got {data.get(key)!r}")

false_flags = [
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution",
    "live_discord_message_received", "live_discord_message_sent", "live_engram_write_attempted",
    "live_readback_attempted", "uses_real_discord_ids", "raw_discord_chat_logs_included",
    "raw_private_payload_included", "screenshots_included", "secrets_included",
    "private_noop_ingestion_reviewed", "private_execution_approval_granted", "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"evidence review packet must keep {key}: false")
if data.get("evidence_review_proof_level") != "repo-safe-review-packet":
    raise SystemExit("evidence review proof level mismatch")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

expected_sources = {
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-redacted-noop-ingestion-packet.fake.yaml",
    "examples/private-execution-approval-packet.fake.yaml",
    "docs/operations/private-discord-manual-verification-guide.md",
}
if set(data.get("source_contracts", [])) != expected_sources:
    raise SystemExit("source contracts drifted")

expected_packet = {
    "review_state": "not-run",
    "expected_event_kind": "private-redacted-discord-noop",
    "approval_binding_ref": "approval/<approval-record-id>",
    "proposal_ref": "proposal/<proposal-id>",
    "route_ref": "route/<project-key>/private-context",
    "actor_ref": "<operator-ref>",
    "runtime_namespace": runtime,
    "target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "operation_fingerprint": "fingerprint/<operation-fingerprint>",
    "evidence_schema_ref": "private-redacted-noop-ingestion-packet",
    "operator_attestation_required": True,
    "sanitized_summary_required": True,
    "raw_private_values_allowed": False,
    "write_readback_allowed": False,
    "approval_reuse_allowed": False,
}
if data.get("sanitized_review_packet", {}) != expected_packet:
    raise SystemExit("sanitized review packet body drifted")

expected_matrix = {
    "not-run": ("none", "blocked", False, "private no-op ingestion has not been run or reviewed"),
    "missing-approval-binding": ("sanitized no-op summary present", "blocked", False, "approval binding reference is missing"),
    "missing-operator-attestation": ("sanitized no-op summary present", "blocked", False, "operator attestation is missing"),
    "raw-private-evidence": ("raw private payload included", "blocked", False, "raw private evidence is forbidden"),
    "unsupported-success-claim": ("available-and-proven claimed", "blocked", False, "no-op ingestion review cannot claim write/readback readiness"),
    "write-readback-attempt": ("Engram write or readback attempted", "blocked", False, "write/readback attempts are outside this packet"),
}
items = data.get("review_matrix", [])
ids = [item.get("id") for item in items]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate review matrix ids rejected: {duplicates}")
scenarios = {item.get("id"): item for item in items}
if set(scenarios) != set(expected_matrix):
    raise SystemExit("review matrix coverage drifted")
for scenario_id, (summary, state, allowed, reason) in expected_matrix.items():
    expected = {
        "id": scenario_id,
        "input_summary": summary,
        "expected_state": state,
        "expected_acceptance_allowed": allowed,
        "reason": reason,
    }
    if scenarios[scenario_id] != expected:
        raise SystemExit(f"review matrix scenario drifted for {scenario_id}")

expected_gate = {
    "accepted_now": False,
    "readiness_result": "blocked",
    "stop_reasons": [
        "private no-op ingestion has not been executed in this repo-safe packet",
        "operator attestation is not present in repo artifacts",
        "repo artifacts cannot contain raw private evidence",
        "no private write/readback was executed by this issue",
        "sanitized evidence review cannot close issue 211",
    ],
    "next_safe_actions": [
        "run private redacted no-op ingestion only after explicit approval outside repo",
        "review only sanitized summary fields against the approved evidence schema",
        "keep #211 open until actual private execution and readback are separately approved executed and reviewed",
    ],
}
if data.get("review_gate", {}) != expected_gate:
    raise SystemExit("review gate drifted")

expected_policy = {
    "allowed": [
        "sanitized no-op outcome summary",
        "approval binding summary without identifiers",
        "placeholder namespace refs",
        "blocked or pass-summary status summaries",
        "validator command names and pass/fail summaries",
        "operator attestation summary without identifiers",
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
    "proving private no-op ingestion occurred",
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

bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
bash scripts/validate-private-redacted-noop-ingestion-packet.sh >/dev/null
bash scripts/validate-private-execution-approval-packet.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "evidence review packet artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_received: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|private_noop_ingestion_reviewed: true|private_execution_approval_granted: true|readiness_gate_updated: true|accepted_now: true|readiness_result: ready|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "evidence review packet artifacts must not claim private execution, acceptance, readiness update, closure, or production behavior"
fi

echo "Validated fake private no-op ingestion evidence review packet."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
