#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_NOOP_EXECUTION_RUNBOOK_GATE_FIXTURE:-examples/private-noop-execution-runbook-gate.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_VALIDATOR="scripts/validate-private-discord-engram-rehearsal-readiness.sh"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_VALIDATOR" "$HARNESS_VALIDATOR"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-noop-execution-runbook-gate" \
  "issue: 274" \
  "parent_issue: 211" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "live_discord_message_received: false" \
  "live_discord_message_sent: false" \
  "live_engram_write_attempted: false" \
  "live_readback_attempted: false" \
  "uses_real_discord_ids: false" \
  "private_noop_execution_approved: false" \
  "private_noop_execution_run: false" \
  "private_noop_evidence_reviewed: false" \
  "readiness_gate_updated: false" \
  "runbook_gate_proof_level: repo-safe-operator-sequence-only" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "allowed_now: false" \
  "readiness_result: blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "runbook gate fixture missing marker: $required"
done

for required in \
  "Private no-op execution runbook gate" \
  "examples/private-noop-execution-runbook-gate.fake.yaml" \
  "scripts/validate-private-noop-execution-runbook-gate.sh" \
  "repo-safe operator sequence only" \
  "does not prove private no-op execution occurred" \
  "does not execute Engram write/readback" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing runbook gate marker: $required"
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

allowed_top_level = {
    "schema_version",
    "fixture_type",
    "safe_for_repo",
    "privacy_reviewed",
    "contract",
    "issue",
    "parent_issue",
    "live_discord_connection",
    "live_engram_calls",
    "live_openclaw_prompt_execution",
    "live_discord_message_received",
    "live_discord_message_sent",
    "live_engram_write_attempted",
    "live_readback_attempted",
    "uses_real_discord_ids",
    "raw_discord_chat_logs_included",
    "raw_private_payload_included",
    "screenshots_included",
    "secrets_included",
    "runbook_gate_proof_level",
    "private_noop_execution_approved",
    "private_noop_execution_run",
    "private_noop_evidence_reviewed",
    "readiness_gate_updated",
    "runtime_namespace_contract",
    "source_contracts",
    "operator_sequence",
    "fail_closed_matrix",
    "execution_gate",
    "sanitized_evidence_policy",
    "non_goals",
}
unknown_top_level = sorted(set(data) - allowed_top_level)
if unknown_top_level:
    raise SystemExit(f"unsupported top-level keys rejected: {unknown_top_level}")

expected_top = {
    "schema_version": 1,
    "fixture_type": "fake-demo",
    "safe_for_repo": True,
    "privacy_reviewed": True,
    "contract": "private-noop-execution-runbook-gate",
    "issue": 274,
    "parent_issue": 211,
}
for key, expected in expected_top.items():
    if data.get(key) != expected:
        raise SystemExit(f"runbook gate top-level field mismatch for {key}: expected {expected!r}, got {data.get(key)!r}")

false_flags = [
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution",
    "live_discord_message_received", "live_discord_message_sent", "live_engram_write_attempted",
    "live_readback_attempted", "uses_real_discord_ids", "raw_discord_chat_logs_included",
    "raw_private_payload_included", "screenshots_included", "secrets_included",
    "private_noop_execution_approved", "private_noop_execution_run",
    "private_noop_evidence_reviewed", "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"runbook gate must keep {key}: false")
if data.get("runbook_gate_proof_level") != "repo-safe-operator-sequence-only":
    raise SystemExit("runbook proof level mismatch")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

expected_sources = {
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-redacted-noop-ingestion-packet.fake.yaml",
    "examples/private-execution-approval-packet.fake.yaml",
    "examples/private-noop-ingestion-evidence-review-packet.fake.yaml",
    "docker/openclaw/private-noop-ingestion-review-harness.sh",
    "docs/operations/private-discord-manual-verification-guide.md",
}
if set(data.get("source_contracts", [])) != expected_sources:
    raise SystemExit("source contracts drifted")

expected_sequence = {
    "confirm-private-topology": ("required-outside-repo", "placeholder-summary-only"),
    "confirm-proposal-binding": ("repo-safe-synthetic-proof-only", "validator-output-only"),
    "request-explicit-noop-approval": ("not-granted", "decision-summary-only"),
    "execute-redacted-noop-only": ("not-run", "sanitized-summary-only"),
    "review-sanitized-summary-with-harness": ("repo-safe-harness-ready-only", "validator-output-only"),
    "keep-write-readback-blocked": ("blocked", "blocked-status-only"),
}
items = data.get("operator_sequence", [])
ids = [item.get("id") for item in items]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate operator sequence ids rejected: {duplicates}")
if set(ids) != set(expected_sequence):
    raise SystemExit("operator sequence coverage drifted")
allowed_sequence_keys = {"id", "required_before_execution", "status", "repo_evidence_allowed", "stop_if_missing"}
for item in items:
    extra_keys = sorted(set(item) - allowed_sequence_keys)
    if extra_keys:
        raise SystemExit(f"unsupported operator sequence keys rejected for {item.get('id')}: {extra_keys}")
    status, evidence = expected_sequence[item["id"]]
    if item.get("required_before_execution") is not True:
        raise SystemExit(f"operator sequence item must be required: {item['id']}")
    if item.get("status") != status or item.get("repo_evidence_allowed") != evidence or item.get("stop_if_missing") is not True:
        raise SystemExit(f"operator sequence item drifted: {item['id']}")

expected_matrix = {
    "missing-explicit-approval": "explicit private no-op execution approval is not granted",
    "missing-review-harness": "no-op ingestion review harness is not green",
    "raw-private-evidence": "raw private evidence is forbidden",
    "write-readback-attempt": "write/readback attempts are outside no-op execution",
    "readiness-overclaim": "no-op runbook cannot claim available-and-proven readiness",
}
matrix = data.get("fail_closed_matrix", [])
ids = [item.get("id") for item in matrix]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate fail-closed matrix ids rejected: {duplicates}")
if set(ids) != set(expected_matrix):
    raise SystemExit("fail-closed matrix coverage drifted")
allowed_matrix_keys = {"id", "expected_state", "expected_execution_allowed", "reason"}
for item in matrix:
    extra_keys = sorted(set(item) - allowed_matrix_keys)
    if extra_keys:
        raise SystemExit(f"unsupported fail-closed matrix keys rejected for {item.get('id')}: {extra_keys}")
    if item.get("expected_state") != "blocked" or item.get("expected_execution_allowed") is not False:
        raise SystemExit(f"fail-closed matrix item must stay blocked: {item.get('id')}")
    if item.get("reason") != expected_matrix[item["id"]]:
        raise SystemExit(f"fail-closed reason drifted: {item['id']}")

expected_gate = {
    "allowed_now": False,
    "readiness_result": "blocked",
    "stop_reasons": [
        "private no-op execution approval is not granted",
        "private no-op execution has not run",
        "sanitized no-op evidence has not been reviewed",
        "write/readback remains blocked",
        "issue 211 must remain open",
    ],
    "next_safe_actions": [
        "request explicit private no-op-only approval outside repo",
        "execute only redacted no-op ingestion after approval",
        "review only sanitized summary with the repo-safe harness contract",
        "keep #211 open until write/readback is separately approved executed and reviewed",
    ],
}
if data.get("execution_gate") != expected_gate:
    raise SystemExit("execution gate drifted")

expected_policy = {
    "allowed": [
        "placeholder topology summary",
        "approval decision summary without identifiers",
        "sanitized no-op outcome summary",
        "harness pass/fail summary",
        "blocked write/readback status",
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
if data.get("sanitized_evidence_policy") != expected_policy:
    raise SystemExit("sanitized evidence policy drifted")

expected_non_goals = [
    "granting private no-op execution approval",
    "proving private no-op execution occurred",
    "executing live Discord messages from repo validation",
    "executing an Engram write",
    "executing a live readback from Engram",
    "updating readiness to available-and-proven",
    "closing issue 211",
]
if data.get("non_goals") != expected_non_goals:
    raise SystemExit("non-goals drifted")
PY

PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash "$READINESS_VALIDATOR" >/dev/null
bash "$HARNESS_VALIDATOR" >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "runbook gate artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_received: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|private_noop_execution_approved: true|private_noop_execution_run: true|private_noop_evidence_reviewed: true|readiness_gate_updated: true|allowed_now: true|readiness_result: ready|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "runbook gate artifacts must not claim private execution, readiness, closure, or production behavior"
fi

echo "Validated fake private no-op execution runbook gate."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
