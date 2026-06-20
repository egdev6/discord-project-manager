#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_DISCORD_ENGRAM_READINESS_FIXTURE:-examples/private-discord-engram-rehearsal-readiness.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
APPROVAL_DOC="docs/operations/discord-approval-responses.md"
SLICE_FIXTURE="examples/private-discord-engram-vertical-slice.fake.yaml"
APPROVAL_FIXTURE="examples/discord-approval-gate.fake.yaml"
NOOP_FIXTURE="examples/private-discord-engram-noop-observation.fake.yaml"
NOOP_PROOF_FIXTURE="examples/private-discord-engram-noop-observation-proof.fake.yaml"
REPAIR_FIXTURE="examples/runtime-approval-enforcement-repair.fake.yaml"
APPROVAL_PROOF_FIXTURE="examples/runtime-approval-enforcement-proof.fake.yaml"
PREFLIGHT_GATE_FIXTURE="examples/private-write-readback-preflight-gate.fake.yaml"
PROPOSAL_BINDING_FIXTURE="examples/proposal-binding-boundary.fake.yaml"
NOOP_REVIEW_PACKET_FIXTURE="examples/private-noop-ingestion-evidence-review-packet.fake.yaml"
NOOP_REVIEW_HARNESS="docker/openclaw/private-noop-ingestion-review-harness.sh"
NOOP_REVIEW_HARNESS_VALIDATOR="scripts/validate-private-noop-ingestion-review-harness.sh"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$APPROVAL_DOC" "$SLICE_FIXTURE" "$APPROVAL_FIXTURE" "$NOOP_FIXTURE" "$NOOP_PROOF_FIXTURE" "$REPAIR_FIXTURE" "$APPROVAL_PROOF_FIXTURE" "$PREFLIGHT_GATE_FIXTURE" "$PROPOSAL_BINDING_FIXTURE" "$NOOP_REVIEW_PACKET_FIXTURE" "$NOOP_REVIEW_HARNESS" "$NOOP_REVIEW_HARNESS_VALIDATOR"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-discord-engram-rehearsal-readiness" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "execution_allowed: false" \
  "readiness_result: blocked" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "id: runtime-approval-enforcement" \
  "status: repo-safe-synthetic-proof-only" \
  "proof_ref: examples/runtime-approval-enforcement-proof.fake.yaml" \
  "id: no-op-observation-path" \
  "proof_ref: examples/private-discord-engram-noop-observation-proof.fake.yaml" \
  "id: server-side-proposal-binding" \
  "proof_ref: examples/proposal-binding-boundary.fake.yaml" \
  "id: no-op-ingestion-review-harness" \
  "status: repo-safe-synthetic-review-only" \
  "packet_ref: examples/private-noop-ingestion-evidence-review-packet.fake.yaml" \
  "harness_ref: docker/openclaw/private-noop-ingestion-review-harness.sh" \
  "validator_ref: scripts/validate-private-noop-ingestion-review-harness.sh" \
  "id: explicit-human-approval" \
  "status: not-granted" \
  "allowed_now: false" \
  "private redacted event ingestion, no-op ingestion review, and server-side proposal binding are not proven" \
  "prove private redacted no-op event ingestion before write-like traffic" \
  "review private no-op ingestion sanitized summary with the repo-safe harness contract" \
  "prove server-side proposal binding before writes"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "readiness fixture missing marker: $required"
done

for required in \
  "Private Discord-to-Engram rehearsal readiness gate" \
  "examples/private-discord-engram-rehearsal-readiness.fake.yaml" \
  "scripts/validate-private-discord-engram-rehearsal-readiness.sh" \
  "execution_allowed: false" \
  "does not close #211"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing readiness marker: $required"
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

UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping,
)

fixture = Path(sys.argv[1])
runtime = sys.argv[2]
data = yaml.load(fixture.read_text(), Loader=UniqueKeyLoader)

def load_yaml(path):
    return yaml.load(Path(path).read_text(), Loader=UniqueKeyLoader)

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
    "execution_allowed",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"readiness fixture must keep {key}: false")

if data.get("readiness_result") != "blocked":
    raise SystemExit("readiness result must remain blocked")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "docs/operations/private-discord-manual-verification-guide.md",
    "docs/operations/discord-approval-responses.md",
    "examples/private-discord-engram-vertical-slice.fake.yaml",
    "examples/discord-approval-gate.fake.yaml",
    "examples/private-discord-engram-noop-observation.fake.yaml",
    "examples/private-discord-engram-noop-observation-proof.fake.yaml",
    "examples/runtime-approval-enforcement-repair.fake.yaml",
    "examples/runtime-approval-enforcement-proof.fake.yaml",
    "examples/private-write-readback-preflight-gate.fake.yaml",
    "examples/proposal-binding-boundary.fake.yaml",
    "examples/private-noop-ingestion-evidence-review-packet.fake.yaml",
    "docker/openclaw/private-noop-ingestion-review-harness.sh",
    "scripts/validate-private-noop-ingestion-review-harness.sh",
    "docs/operations/runtime-version-baseline.md",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

approval_proof = load_yaml("examples/runtime-approval-enforcement-proof.fake.yaml")
noop_proof = load_yaml("examples/private-discord-engram-noop-observation-proof.fake.yaml")
for proof_name, proof in [
    ("runtime approval enforcement proof", approval_proof),
    ("no-op observation proof", noop_proof),
    ("proposal binding proof", load_yaml("examples/proposal-binding-boundary.fake.yaml")),
]:
    fail_closed = proof.get("fail_closed_expectations", {})
    if fail_closed.get("current_readiness_status") != "repo-safe-synthetic-proof-only":
        raise SystemExit(f"{proof_name} current readiness must match readiness fixture repo-safe synthetic status")
    if fail_closed.get("required_future_status") != "available-and-proven":
        raise SystemExit(f"{proof_name} must still require future live/private available-and-proven status")
    if fail_closed.get("updates_readiness_fixture_now") is not False:
        raise SystemExit(f"{proof_name} must not update readiness fixture to executable")

inputs = data.get("operator_inputs", {})
for key in ["private_non_production_guild", "private_non_production_channel", "non_production_credentials"]:
    if inputs.get(key) != "required-outside-repo":
        raise SystemExit(f"operator input must stay outside repo: {key}")
if inputs.get("explicit_execution_approval") != "not-granted":
    raise SystemExit("execution approval must not be granted in repo fixture")
for key in ["real_identifiers_committed", "credentials_committed"]:
    if inputs.get(key) is not False:
        raise SystemExit(f"operator input hygiene must keep {key}: false")

readiness_items = data.get("readiness_checks", [])
readiness_ids = [item.get("id") for item in readiness_items]
if len(readiness_ids) != len(set(readiness_ids)):
    duplicates = sorted({item_id for item_id in readiness_ids if readiness_ids.count(item_id) > 1})
    raise SystemExit(f"duplicate readiness check ids rejected: {duplicates}")
checks = {item.get("id"): item for item in readiness_items}
required_checks = {
    "runtime-baseline",
    "approval-gate-lifecycle",
    "runtime-approval-enforcement",
    "no-op-observation-path",
    "server-side-proposal-binding",
    "no-op-ingestion-review-harness",
    "private-discord-topology",
    "explicit-human-approval",
    "private-backup-restore-ready",
}
if set(checks) != required_checks:
    raise SystemExit("readiness check coverage drifted")
for check_id, check in checks.items():
    if check.get("required_before_execution") is not True:
        raise SystemExit(f"readiness check must be required: {check_id}")

if checks["runtime-approval-enforcement"].get("status") != "repo-safe-synthetic-proof-only":
    raise SystemExit("runtime approval enforcement must remain repo-safe-synthetic-proof-only until live/private proof exists")
if checks["runtime-approval-enforcement"].get("contract_ref") != "examples/runtime-approval-enforcement-repair.fake.yaml":
    raise SystemExit("runtime approval enforcement must reference repair contract")
if checks["runtime-approval-enforcement"].get("proof_ref") != "examples/runtime-approval-enforcement-proof.fake.yaml":
    raise SystemExit("runtime approval enforcement must reference synthetic proof")
if checks["no-op-observation-path"].get("status") != "repo-safe-synthetic-proof-only":
    raise SystemExit("no-op observation path must remain repo-safe-synthetic-proof-only until live/private proof exists")
if checks["no-op-observation-path"].get("contract_ref") != "examples/private-discord-engram-noop-observation.fake.yaml":
    raise SystemExit("no-op observation path must reference no-op design contract")
if checks["no-op-observation-path"].get("proof_ref") != "examples/private-discord-engram-noop-observation-proof.fake.yaml":
    raise SystemExit("no-op observation path must reference synthetic proof")
if checks["server-side-proposal-binding"].get("status") != "repo-safe-synthetic-proof-only":
    raise SystemExit("server-side proposal binding must remain repo-safe-synthetic-proof-only until live/private proof exists")
if checks["server-side-proposal-binding"].get("proof_ref") != "examples/proposal-binding-boundary.fake.yaml":
    raise SystemExit("server-side proposal binding must reference synthetic proof")
if checks["no-op-ingestion-review-harness"].get("status") != "repo-safe-synthetic-review-only":
    raise SystemExit("no-op ingestion review harness must remain repo-safe-synthetic-review-only until private review exists")
if checks["no-op-ingestion-review-harness"].get("packet_ref") != "examples/private-noop-ingestion-evidence-review-packet.fake.yaml":
    raise SystemExit("no-op ingestion review harness must reference evidence review packet")
if checks["no-op-ingestion-review-harness"].get("harness_ref") != "docker/openclaw/private-noop-ingestion-review-harness.sh":
    raise SystemExit("no-op ingestion review harness must reference harness")
if checks["no-op-ingestion-review-harness"].get("validator_ref") != "scripts/validate-private-noop-ingestion-review-harness.sh":
    raise SystemExit("no-op ingestion review harness must reference validator")
if checks["explicit-human-approval"].get("status") != "not-granted":
    raise SystemExit("explicit human approval must remain not-granted")
if checks["private-discord-topology"].get("status") != "required-outside-repo":
    raise SystemExit("private topology must remain outside repo")

execution = data.get("execution_gate", {})
if execution.get("allowed_now") is not False:
    raise SystemExit("execution gate must not allow live run")
required_state = execution.get("required_state_before_live_discord_message", {})
expected_required_state = {
    "runtime-baseline": "passed-private-run",
    "approval-gate-lifecycle": "repo-contract-ready",
    "runtime-approval-enforcement": "available-and-proven",
    "no-op-observation-path": "available-and-proven",
    "server-side-proposal-binding": "available-and-proven",
    "no-op-ingestion-review-harness": "private-pass-summary-reviewed",
    "private-discord-topology": "prepared-outside-repo",
    "explicit-human-approval": "granted",
    "private-backup-restore-ready": "repo-contract-ready",
}
if required_state != expected_required_state:
    raise SystemExit("required execution gate state drifted")
stop_reasons = set(execution.get("stop_reasons", []))
for required in [
    "runtime approval enforcement is repo-safe-synthetic-proof-only, not live/private available-and-proven",
    "no-op observation path is repo-safe-synthetic-proof-only, not live/private available-and-proven",
    "server-side proposal binding is repo-safe-synthetic-proof-only, not live/private available-and-proven",
    "no-op ingestion review harness is repo-safe-synthetic-review-only, not private-pass-summary-reviewed",
    "explicit execution approval is not granted",
    "private topology and credentials are not represented in repo-safe evidence",
    "private redacted event ingestion, no-op ingestion review, and server-side proposal binding are not proven",
]:
    if required not in stop_reasons:
        raise SystemExit(f"missing stop reason: {required}")
if execution.get("permitted_next_actions") != [
    "prepare private topology outside repo with sanitized placeholders only",
    "prove private redacted no-op event ingestion before write-like traffic",
    "review private no-op ingestion sanitized summary with the repo-safe harness contract",
    "prove server-side proposal binding before writes",
]:
    raise SystemExit("permitted next actions drifted")

policy = data.get("sanitized_evidence_policy", {})
for allowed in ["pass status summary", "blocked status summary", "not-run status summary"]:
    if allowed not in policy.get("allowed", []):
        raise SystemExit(f"missing allowed evidence marker: {allowed}")
for forbidden in ["real Discord guild/channel/user/message IDs", "credentials or .env values", "screenshots", "raw logs", "transcripts", "private payloads", "raw Engram exports", "SQL dumps"]:
    if forbidden not in policy.get("forbidden", []):
        raise SystemExit(f"missing forbidden evidence marker: {forbidden}")
PY

bash scripts/validate-runtime-version-baseline.sh >/dev/null
bash scripts/validate-discord-approval-gate.sh >/dev/null
bash scripts/validate-private-runtime-backup-restore.sh >/dev/null
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash "$NOOP_REVIEW_HARNESS_VALIDATOR" >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH" "$APPROVAL_DOC" "$SLICE_FIXTURE" "$APPROVAL_FIXTURE" "$NOOP_FIXTURE" "$NOOP_PROOF_FIXTURE" "$REPAIR_FIXTURE" "$APPROVAL_PROOF_FIXTURE" "$PREFLIGHT_GATE_FIXTURE" "$PROPOSAL_BINDING_FIXTURE" "$NOOP_REVIEW_PACKET_FIXTURE" "$NOOP_REVIEW_HARNESS")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "private rehearsal readiness artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|execution_allowed: true|readiness_result: ready|live Discord-to-Engram validation passed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "readiness artifacts must not claim live execution, readiness, or production behavior"
fi

echo "Validated fake private Discord-to-Engram rehearsal readiness gate."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
