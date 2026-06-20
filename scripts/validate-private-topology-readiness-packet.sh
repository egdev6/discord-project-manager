#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_TOPOLOGY_READINESS_PACKET_FIXTURE:-examples/private-topology-readiness-packet.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
PREFLIGHT_GATE_FIXTURE="examples/private-write-readback-preflight-gate.fake.yaml"
PROPOSAL_BINDING_FIXTURE="examples/proposal-binding-boundary.fake.yaml"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() { echo "ERROR: $*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"; }
require_cmd grep
require_cmd python3

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$PREFLIGHT_GATE_FIXTURE" "$PROPOSAL_BINDING_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-topology-readiness-packet" \
  "issue: 262" \
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
  "private_topology_proof_level: repo-safe-placeholder-readiness" \
  "private_topology_prepared_for_live_execution: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "placeholders_only: true" \
  "raw_values_printed: false" \
  "raw_env_values_allowed_in_repo: false" \
  "env_file_committed: false" \
  "allowed_now: false" \
  "readiness_result: blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "topology fixture missing marker: $required"
done

for required in \
  "Private topology readiness packet" \
  "examples/private-topology-readiness-packet.fake.yaml" \
  "scripts/validate-private-topology-readiness-packet.sh" \
  "repo-safe placeholder readiness" \
  "does not prove private topology is prepared for live execution" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing topology packet marker: $required"
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
    "contract": "private-topology-readiness-packet",
    "issue": 262,
    "parent_issue": 211,
}
for key, expected in expected_top_level.items():
    if data.get(key) != expected:
        raise SystemExit(f"topology packet top-level field mismatch for {key}: expected {expected!r}, got {data.get(key)!r}")

false_flags = [
    "live_discord_connection", "live_engram_calls", "live_openclaw_prompt_execution",
    "live_discord_message_sent", "live_engram_write_attempted", "live_readback_attempted",
    "uses_real_discord_ids", "raw_discord_chat_logs_included", "raw_private_payload_included",
    "screenshots_included", "secrets_included", "private_topology_prepared_for_live_execution",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"topology packet must keep {key}: false")
if data.get("private_topology_proof_level") != "repo-safe-placeholder-readiness":
    raise SystemExit("topology proof level mismatch")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-write-readback-preflight-gate.fake.yaml",
    "examples/proposal-binding-boundary.fake.yaml",
    "docs/operations/private-discord-manual-verification-guide.md",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

topology = data.get("placeholder_topology", {})
expected_topology = {
    "guild_ref": "<guild-id>",
    "channel_ref": "<channel-id>",
    "actor_ref": "<operator-ref>",
    "message_ref": "<message-id>",
    "project_ref": "project/<project-key>",
    "runtime_namespace": runtime,
    "durable_target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "readback_target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "placeholders_only": True,
    "raw_values_printed": False,
}
if topology != expected_topology:
    raise SystemExit("placeholder topology drifted")

env = data.get("private_environment_requirements", {})
for key in ["discord_bot_token", "discord_guild_id", "discord_channel_id", "engram_access_token", "openclaw_gateway_secret"]:
    if env.get(key) != "required-outside-repo":
        raise SystemExit(f"private env requirement must remain outside repo: {key}")
if env.get("raw_env_values_allowed_in_repo") is not False or env.get("env_file_committed") is not False:
    raise SystemExit("private env values must not be allowed or committed")

expected_checks = {
    "non-production-guild-selected": "pending-private-run",
    "managed-channel-selected": "pending-private-run",
    "runtime-namespace-previewed": "repo-placeholder-ready",
    "durable-target-namespace-previewed": "repo-placeholder-ready",
    "credentials-present-privately": "pending-private-run",
    "private-redacted-event-ingestion": "not-proven",
}
items = data.get("private_checklist", [])
ids = [item.get("id") for item in items]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate private checklist ids rejected: {duplicates}")
checks = {item.get("id"): item for item in items}
if set(checks) != set(expected_checks):
    raise SystemExit("private checklist coverage drifted")
for check_id, expected_status in expected_checks.items():
    check = checks[check_id]
    if check.get("status") != expected_status:
        raise SystemExit(f"private checklist status drifted for {check_id}")
    if check.get("fail_closed_if_missing") is not True:
        raise SystemExit(f"private checklist must fail closed: {check_id}")
    if not str(check.get("evidence_allowed_in_repo", "")).endswith("summary-only"):
        raise SystemExit(f"private checklist repo evidence must be summary-only: {check_id}")

execution = data.get("execution_gate", {})
if execution.get("allowed_now") is not False or execution.get("readiness_result") != "blocked":
    raise SystemExit("topology packet execution gate must remain blocked")
for required in [
    "private topology values are placeholders only in repo",
    "credentials are required outside repo and not printed",
    "private redacted event ingestion is not proven",
    "explicit execution approval is not granted",
    "no private write/readback was executed by this issue",
]:
    if required not in execution.get("stop_reasons", []):
        raise SystemExit(f"missing topology stop reason: {required}")
for required in [
    "verify private topology outside repo without copying raw identifiers into git",
    "run private redacted no-op event ingestion before write-like traffic",
    "keep #211 open until actual private execution and readback are separately approved executed and reviewed",
]:
    if required not in execution.get("next_safe_actions", []):
        raise SystemExit(f"missing next safe action: {required}")

non_goals = set(data.get("non_goals", []))
for required in [
    "executing live Discord messages", "executing an Engram write", "executing a live readback from Engram",
    "proving private redacted event ingestion", "updating readiness to available-and-proven", "closing issue 211",
]:
    if required not in non_goals:
        raise SystemExit(f"missing non-goal: {required}")
PY

bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
bash scripts/validate-private-write-readback-preflight-gate.sh >/dev/null
bash scripts/validate-proposal-binding-boundary.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "topology packet artifacts must not expose raw Discord snowflake-like IDs"
fi
if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|private_topology_prepared_for_live_execution: true|readiness_gate_updated: true|allowed_now: true|readiness_result: ready|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "topology packet artifacts must not claim live execution, readiness update, closure, or production behavior"
fi

echo "Validated fake private topology readiness packet."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
