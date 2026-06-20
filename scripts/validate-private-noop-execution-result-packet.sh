#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_NOOP_EXECUTION_RESULT_PACKET_FIXTURE:-examples/private-noop-execution-result-packet.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_VALIDATOR="scripts/validate-private-discord-engram-rehearsal-readiness.sh"
RUNBOOK_VALIDATOR="scripts/validate-private-noop-execution-runbook-gate.sh"
HARNESS_VALIDATOR="scripts/validate-private-noop-ingestion-review-harness.sh"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_VALIDATOR" "$RUNBOOK_VALIDATOR" "$HARNESS_VALIDATOR"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "contract: private-noop-execution-result-packet" \
  "issue: 278" \
  "parent_issue: 211" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "live_engram_write_attempted: false" \
  "live_readback_attempted: false" \
  "result_packet_proof_level: repo-safe-result-schema-only" \
  "private_noop_execution_result_recorded: false" \
  "private_noop_execution_passed: false" \
  "private_noop_evidence_reviewed: false" \
  "readiness_gate_updated: false" \
  "accepted_now: false" \
  "readiness_result: blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "result packet fixture missing marker: $required"
done

for required in \
  "Private no-op execution result packet" \
  "examples/private-noop-execution-result-packet.fake.yaml" \
  "scripts/validate-private-noop-execution-result-packet.sh" \
  "repo-safe result schema only" \
  "does not prove private no-op execution occurred" \
  "does not execute Engram write/readback" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing result packet marker: $required"
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
allowed_top = {
    "schema_version", "fixture_type", "safe_for_repo", "privacy_reviewed", "contract", "issue", "parent_issue",
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution", "live_discord_message_received",
    "live_discord_message_sent", "live_engram_write_attempted", "live_readback_attempted", "uses_real_discord_ids",
    "raw_discord_chat_logs_included", "raw_private_payload_included", "screenshots_included", "secrets_included",
    "result_packet_proof_level", "private_noop_execution_result_recorded", "private_noop_execution_passed",
    "private_noop_execution_failed", "private_noop_evidence_reviewed", "readiness_gate_updated", "runtime_namespace_contract",
    "source_contracts", "result_packet", "fail_closed_matrix", "execution_gate", "sanitized_evidence_policy", "non_goals",
}
extra = sorted(set(data) - allowed_top)
if extra:
    raise SystemExit(f"unsupported top-level keys rejected: {extra}")
expected_top = {"schema_version": 1, "fixture_type": "fake-demo", "safe_for_repo": True, "privacy_reviewed": True, "contract": "private-noop-execution-result-packet", "issue": 278, "parent_issue": 211}
for key, expected in expected_top.items():
    if data.get(key) != expected:
        raise SystemExit(f"top-level field mismatch for {key}")
for key in [
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution", "live_discord_message_received",
    "live_discord_message_sent", "live_engram_write_attempted", "live_readback_attempted", "uses_real_discord_ids",
    "raw_discord_chat_logs_included", "raw_private_payload_included", "screenshots_included", "secrets_included",
    "private_noop_execution_result_recorded", "private_noop_execution_passed", "private_noop_execution_failed",
    "private_noop_evidence_reviewed", "readiness_gate_updated",
]:
    if data.get(key) is not False:
        raise SystemExit(f"result packet must keep {key}: false")
if data.get("result_packet_proof_level") != "repo-safe-result-schema-only":
    raise SystemExit("proof level drifted")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")
expected_sources = {
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-noop-execution-runbook-gate.fake.yaml",
    "examples/private-noop-ingestion-evidence-review-packet.fake.yaml",
    "docker/openclaw/private-noop-ingestion-review-harness.sh",
    "docs/operations/private-discord-manual-verification-guide.md",
}
if set(data.get("source_contracts", [])) != expected_sources:
    raise SystemExit("source contracts drifted")
expected_packet = {
    "result_state": "not-run",
    "approval_binding_ref": "approval/<approval-record-id>",
    "runbook_gate_ref": "private-noop-execution-runbook-gate",
    "route_ref": "route/<project-key>/private-context",
    "runtime_namespace": runtime,
    "target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "operation_fingerprint": "fingerprint/<operation-fingerprint>",
    "sanitized_noop_summary_present": False,
    "operator_attestation_present": False,
    "harness_review_state": "not-run",
    "raw_private_values_present": False,
    "write_readback_attempted": False,
    "readiness_claimed": False,
}
if data.get("result_packet") != expected_packet:
    raise SystemExit("result packet body drifted")
expected_matrix = {
    "not-run": "private no-op execution result has not been recorded",
    "missing-approval-binding": "approval binding is missing",
    "missing-runbook-gate": "runbook gate reference is missing",
    "raw-private-evidence": "raw private evidence is forbidden",
    "write-readback-attempt": "write/readback attempts are outside no-op result packet",
    "readiness-overclaim": "no-op result packet cannot claim available-and-proven readiness",
}
matrix = data.get("fail_closed_matrix", [])
ids = [item.get("id") for item in matrix]
if len(ids) != len(set(ids)):
    raise SystemExit("duplicate fail-closed matrix ids rejected")
if set(ids) != set(expected_matrix):
    raise SystemExit("fail-closed matrix coverage drifted")
allowed_matrix = {"id", "expected_state", "expected_acceptance_allowed", "reason"}
for item in matrix:
    extra = sorted(set(item) - allowed_matrix)
    if extra:
        raise SystemExit(f"unsupported fail-closed matrix keys rejected for {item.get('id')}: {extra}")
    if item.get("expected_state") != "blocked" or item.get("expected_acceptance_allowed") is not False:
        raise SystemExit(f"matrix item must stay blocked: {item.get('id')}")
    if item.get("reason") != expected_matrix[item["id"]]:
        raise SystemExit(f"matrix reason drifted: {item['id']}")
expected_gate = {
    "accepted_now": False,
    "readiness_result": "blocked",
    "stop_reasons": [
        "private no-op execution result has not been recorded",
        "private no-op evidence has not been reviewed",
        "write/readback remains blocked",
        "readiness remains blocked",
        "issue 211 must remain open",
    ],
    "next_safe_actions": [
        "record only sanitized no-op result after separately approved private run",
        "review result with the repo-safe harness contract",
        "keep #211 open until write/readback is separately approved executed and reviewed",
    ],
}
if data.get("execution_gate") != expected_gate:
    raise SystemExit("execution gate drifted")
expected_policy = {
    "allowed": ["sanitized no-op outcome summary", "approval binding summary without identifiers", "runbook gate summary", "harness review status", "blocked write/readback status"],
    "forbidden": ["real Discord guild/channel/user/message IDs", "credentials or .env values", "screenshots", "raw logs", "transcripts", "private payloads", "raw event payloads", "raw Engram exports", "SQL dumps"],
}
if data.get("sanitized_evidence_policy") != expected_policy:
    raise SystemExit("sanitized evidence policy drifted")
expected_non_goals = [
    "proving private no-op execution occurred", "granting private execution approval", "executing live Discord messages from repo validation",
    "executing an Engram write", "executing a live readback from Engram", "updating readiness to available-and-proven", "closing issue 211",
]
if data.get("non_goals") != expected_non_goals:
    raise SystemExit("non-goals drifted")
PY

PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash "$READINESS_VALIDATOR" >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash "$RUNBOOK_VALIDATOR" >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash "$HARNESS_VALIDATOR" >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "result packet artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_received: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|private_noop_execution_result_recorded: true|private_noop_execution_passed: true|private_noop_evidence_reviewed: true|readiness_gate_updated: true|accepted_now: true|readiness_result: ready|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "result packet artifacts must not claim private execution, readiness, closure, or production behavior"
fi

echo "Validated fake private no-op execution result packet."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
