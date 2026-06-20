#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PROPOSAL_BINDING_BOUNDARY_FIXTURE:-examples/proposal-binding-boundary.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
APPROVAL_PROOF_FIXTURE="examples/runtime-approval-enforcement-proof.fake.yaml"
PREFLIGHT_GATE_FIXTURE="examples/private-write-readback-preflight-gate.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$APPROVAL_PROOF_FIXTURE" "$PREFLIGHT_GATE_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: proposal-binding-boundary" \
  "issue: 260" \
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
  "proposal_binding_proof_level: repo-safe-synthetic-contract" \
  "proposal_binding_proven_for_live_private_traffic: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "id: valid-displayed-proposal" \
  "id: missing-proposal-ref" \
  "id: stale-proposal-ref" \
  "id: cross-target-namespace" \
  "id: actor-mismatch" \
  "id: invalid-approval-phrase" \
  "current_readiness_status: repo-safe-synthetic-proof-only" \
  "required_future_status: available-and-proven" \
  "updates_readiness_fixture_now: false"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "proposal binding fixture missing marker: $required"
done

for required in \
  "Proposal binding proof gate" \
  "examples/proposal-binding-boundary.fake.yaml" \
  "scripts/validate-proposal-binding-boundary.sh" \
  "repo-safe synthetic proposal binding proof" \
  "does not prove live private proposal binding" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing proposal binding marker: $required"
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

false_flags = [
    "live_discord_connection",
    "live_engram_calls",
    "live_openclaw_prompt_execution",
    "live_discord_message_sent",
    "live_engram_write_attempted",
    "live_readback_attempted",
    "uses_real_discord_ids",
    "raw_discord_chat_logs_included",
    "raw_private_payload_included",
    "screenshots_included",
    "secrets_included",
    "proposal_binding_proven_for_live_private_traffic",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"proposal binding fixture must keep {key}: false")
if data.get("proposal_binding_proof_level") != "repo-safe-synthetic-contract":
    raise SystemExit("proof level must remain repo-safe synthetic contract")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "docker/openclaw/discord-approval-guard.sh",
    "examples/runtime-approval-enforcement-proof.fake.yaml",
    "examples/private-write-readback-preflight-gate.fake.yaml",
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

binding = data.get("binding_contract", {})
required_fields = {
    "proposal_ref",
    "route_ref",
    "actor_ref",
    "runtime_namespace",
    "target_namespace",
    "operation_fingerprint",
    "approval_phrase",
}
if set(binding.get("required_binding_fields", [])) != required_fields:
    raise SystemExit("binding required fields drifted")
expected_binding = {
    "exact_approval_phrase": "approve write",
    "approval_scope": "displayed-proposal-only",
    "replay_allowed": False,
    "cross_target_approval_allowed": False,
    "stale_proposal_allowed": False,
    "missing_binding_allowed": False,
    "server_side_binding_required_before_write": True,
}
for key, expected in expected_binding.items():
    if binding.get(key) != expected:
        raise SystemExit(f"binding contract mismatch for {key}")

base_binding = {
    "proposal_ref": "proposal/demo-write-001",
    "route_ref": "route/demo-project-context",
    "actor_ref": "operator-demo",
    "runtime_namespace": runtime,
    "target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "operation_fingerprint": "fingerprint/demo-write-001",
    "approval_phrase": "approve write",
}
expected_matrix = {
    "valid-displayed-proposal": {**base_binding, "expected_binding_state": "binding-verification-required", "expected_write_allowed": False, "expected_reason": "exact approval still requires server-side binding and execution gate checks"},
    "missing-proposal-ref": {**base_binding, "proposal_ref": "none", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "proposal reference is missing"},
    "stale-proposal-ref": {**base_binding, "proposal_ref": "proposal/demo-write-expired", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "proposal reference is stale"},
    "cross-target-namespace": {**base_binding, "target_namespace": "discord-project-manager/project/<other-project-key>/private-context", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "target namespace does not match displayed proposal"},
    "actor-mismatch": {**base_binding, "actor_ref": "operator-other", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "actor does not match displayed proposal"},
    "route-mismatch": {**base_binding, "route_ref": "route/other-project-context", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "route does not match displayed proposal"},
    "runtime-namespace-mismatch": {**base_binding, "runtime_namespace": "discord-project-manager/runtime/discord/<other-guild-id>/<other-channel-id>", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "runtime namespace does not match displayed proposal"},
    "operation-fingerprint-mismatch": {**base_binding, "operation_fingerprint": "fingerprint/other-write-001", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "operation fingerprint does not match displayed proposal"},
    "invalid-approval-phrase": {**base_binding, "approval_phrase": "approve", "expected_binding_state": "blocked", "expected_write_allowed": False, "expected_reason": "exact approve write phrase is required"},
}
items = data.get("synthetic_binding_matrix", [])
ids = [item.get("id") for item in items]
if len(ids) != len(set(ids)):
    duplicates = sorted({item_id for item_id in ids if ids.count(item_id) > 1})
    raise SystemExit(f"duplicate synthetic binding ids rejected: {duplicates}")
scenarios = {item.get("id"): item for item in items}
if set(scenarios) != set(expected_matrix):
    raise SystemExit("synthetic binding scenario coverage drifted")
for scenario_id, expected_values in expected_matrix.items():
    scenario = scenarios[scenario_id]
    expected_keys = set(base_binding) | {"id", "expected_binding_state", "expected_write_allowed", "expected_reason"}
    if set(scenario) != expected_keys:
        missing = sorted(expected_keys - set(scenario))
        extra = sorted(set(scenario) - expected_keys)
        raise SystemExit(f"binding scenario schema drifted for {scenario_id}; missing={missing} extra={extra}")
    for key, expected in expected_values.items():
        if scenario.get(key) != expected:
            raise SystemExit(f"binding scenario {scenario_id} mismatch for {key}: expected {expected!r}, got {scenario.get(key)!r}")

fail_closed = data.get("fail_closed_expectations", {})
for required in [
    "proposal binding implemented in live/private runtime",
    "private topology prepared outside repo",
    "private redacted event ingestion proof",
    "explicit human execution approval",
    "sanitized execution/readback evidence review",
]:
    if required not in fail_closed.get("required_before_private_execution", []):
        raise SystemExit(f"missing private execution prerequisite: {required}")
if fail_closed.get("readiness_check_id") != "server-side-proposal-binding":
    raise SystemExit("readiness check id mismatch")
if fail_closed.get("current_readiness_status") != "repo-safe-synthetic-proof-only":
    raise SystemExit("current readiness must remain repo-safe synthetic proof only")
if fail_closed.get("required_future_status") != "available-and-proven":
    raise SystemExit("future readiness must require available-and-proven")
if fail_closed.get("updates_readiness_fixture_now") is not False:
    raise SystemExit("proposal binding proof must not update readiness fixture now")

non_goals = set(data.get("non_goals", []))
for required in [
    "executing live Discord messages",
    "executing an Engram write",
    "executing a live readback from Engram",
    "proving live private proposal binding",
    "updating readiness to available-and-proven",
    "closing issue 211",
]:
    if required not in non_goals:
        raise SystemExit(f"missing non-goal: {required}")
PY

PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-runtime-approval-enforcement-proof.sh >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-write-readback-preflight-gate.sh >/dev/null
if [[ "${PRIVATE_READINESS_CROSSCHECK_SKIP:-0}" != "1" ]]; then
  bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
fi
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "proposal binding artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|proposal_binding_proven_for_live_private_traffic: true|readiness_gate_updated: true|expected_write_allowed: true|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "proposal binding artifacts must not claim live execution, write allowance, readiness update, closure, or production behavior"
fi

echo "Validated fake proposal binding boundary."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
