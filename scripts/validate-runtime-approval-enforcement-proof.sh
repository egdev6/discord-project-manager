#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${RUNTIME_APPROVAL_ENFORCEMENT_PROOF_FIXTURE:-examples/runtime-approval-enforcement-proof.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
GUARD_PATH="docker/openclaw/discord-approval-guard.sh"
REPAIR_FIXTURE="examples/runtime-approval-enforcement-repair.fake.yaml"
PREFLIGHT_FIXTURE="examples/private-write-readback-preflight-gate.fake.yaml"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$GUARD_PATH" "$REPAIR_FIXTURE" "$PREFLIGHT_FIXTURE" "$READINESS_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done
[[ -x "$GUARD_PATH" ]] || fail "guard is not executable: $GUARD_PATH"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: runtime-approval-enforcement-proof" \
  "issue: 254" \
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
  "runtime_enforcement_proof_level: repo-safe-synthetic-guard-cli" \
  "runtime_enforcement_proven_for_live_private_traffic: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "id: matched-write-without-approval" \
  "id: matched-write-invalid-approval" \
  "id: matched-write-exact-approval" \
  "id: unmapped-write-like-route" \
  "repo_safe_synthetic_status: synthetic-guard-cli-proven" \
  "current_readiness_status: repo-safe-synthetic-proof-only" \
  "required_future_status: available-and-proven" \
  "updates_readiness_fixture_now: false"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "approval enforcement proof fixture missing marker: $required"
done

for required in \
  "Runtime approval enforcement proof gate" \
  "examples/runtime-approval-enforcement-proof.fake.yaml" \
  "scripts/validate-runtime-approval-enforcement-proof.sh" \
  "repo-safe synthetic guard proof" \
  "does not prove live private Discord approval enforcement" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing proof marker: $required"
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
    "runtime_enforcement_proven_for_live_private_traffic",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"approval enforcement proof must keep {key}: false")
if data.get("runtime_enforcement_proof_level") != "repo-safe-synthetic-guard-cli":
    raise SystemExit("proof level must remain repo-safe synthetic guard CLI")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "docker/openclaw/discord-approval-guard.sh",
    "scripts/validate-discord-approval-guard-cli.sh",
    "examples/runtime-approval-enforcement-repair.fake.yaml",
    "examples/private-write-readback-preflight-gate.fake.yaml",
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

boundary = data.get("proof_boundary", {})
for required in [
    "synthetic write-like request stops at approval-requested before prompt execution or persistence",
    "invalid approval input does not write",
    "exact approve write stops at approval-verification-required pending server-side proposal binding",
    "unmapped write-like route stops at needs-route without durable reads or writes",
    "workspace filesystem Engram publishing and scheduling writes remain blocked",
]:
    if required not in boundary.get("proves", []):
        raise SystemExit(f"missing proof boundary: {required}")
for required in [
    "live Discord gateway delivery",
    "private Discord event ingestion",
    "live OpenClaw prompt execution safety",
    "server-side proposal binding",
    "Engram write/readback",
    "issue 211 completion",
]:
    if required not in boundary.get("does_not_prove", []):
        raise SystemExit(f"missing non-proof boundary: {required}")

expected = {
    "matched-write-without-approval": ("approval-requested", "guard-denial", False, True, False),
    "matched-write-invalid-approval": ("approval-requested", "guard-invalid-approval", False, True, False),
    "matched-write-exact-approval": ("approval-verification-required", "guard-approval-verification-required", True, True, True),
    "unmapped-write-like-route": ("needs-route", "guard-needs-route", False, False, False),
}
probe_items = data.get("synthetic_probe_matrix", [])
probe_ids = [item.get("id") for item in probe_items]
if len(probe_ids) != len(set(probe_ids)):
    duplicates = sorted({item_id for item_id in probe_ids if probe_ids.count(item_id) > 1})
    raise SystemExit(f"duplicate synthetic probe ids rejected: {duplicates}")
probes = {item.get("id"): item for item in probe_items}
if set(probes) != set(expected):
    raise SystemExit("synthetic probe matrix coverage drifted")
for probe_id, (state, event, exact, durable_reads, audit_required) in expected.items():
    probe = probes[probe_id]
    if probe.get("expected_response_state") != state:
        raise SystemExit(f"response state drifted for {probe_id}")
    if probe.get("expected_guard_event_type") != event:
        raise SystemExit(f"guard event drifted for {probe_id}")
    if probe.get("exact_approval_received") is not exact:
        raise SystemExit(f"approval exactness drifted for {probe_id}")
    if probe.get("durable_reads_allowed") is not durable_reads:
        raise SystemExit(f"durable read expectation drifted for {probe_id}")
    if probe_id == "matched-write-exact-approval" and probe.get("audit_required") is not audit_required:
        raise SystemExit("exact approval probe must require audit")
    for key in [
        "persistent_writes_allowed",
        "workspace_file_writes_allowed",
        "memory_writes_allowed",
        "engram_writes_allowed",
        "writes_attempted",
    ]:
        if probe.get(key) is not False:
            raise SystemExit(f"probe {probe_id} must keep {key}: false")
    if probe.get("prompt_execution") != "none":
        raise SystemExit(f"probe {probe_id} must keep prompt_execution none")

fail_closed = data.get("fail_closed_expectations", {})
for required in [
    "server-side proposal binding proof",
    "private no-op observation path proof",
    "private topology prepared outside repo",
    "explicit human execution approval",
    "sanitized execution/readback evidence review",
]:
    if required not in fail_closed.get("required_before_private_execution", []):
        raise SystemExit(f"missing required before private execution: {required}")
if fail_closed.get("readiness_check_id") != "runtime-approval-enforcement":
    raise SystemExit("readiness check id mismatch")
if fail_closed.get("current_readiness_status") != "repo-safe-synthetic-proof-only":
    raise SystemExit("current readiness must remain repo-safe-synthetic-proof-only")
if fail_closed.get("repo_safe_synthetic_status") != "synthetic-guard-cli-proven":
    raise SystemExit("repo-safe synthetic status mismatch")
if fail_closed.get("required_future_status") != "available-and-proven":
    raise SystemExit("future readiness status mismatch")
if fail_closed.get("updates_readiness_fixture_now") is not False:
    raise SystemExit("proof gate must not update readiness fixture now")

policy = data.get("sanitized_evidence_policy", {})
for forbidden in [
    "real Discord guild/channel/user/message IDs",
    "credentials or .env values",
    "screenshots",
    "raw logs",
    "transcripts",
    "private payloads",
    "raw Engram exports",
    "SQL dumps",
]:
    if forbidden not in policy.get("forbidden", []):
        raise SystemExit(f"missing forbidden evidence marker: {forbidden}")

non_goals = set(data.get("non_goals", []))
for required in [
    "executing live Discord messages",
    "executing an Engram write",
    "executing a live readback from Engram",
    "proving live private runtime approval enforcement",
    "updating readiness to available-and-proven",
    "closing issue 211",
]:
    if required not in non_goals:
        raise SystemExit(f"missing non-goal: {required}")
PY

run_guard() {
  local name="$1"
  shift
  "$GUARD_PATH" "$@" >"${TMPDIR:-/tmp}/approval-proof-${name}.out"
  printf '%s\n' "${TMPDIR:-/tmp}/approval-proof-${name}.out"
}

assert_output() {
  local path="$1"
  shift
  local marker
  for marker in "$@"; do
    grep -F "$marker" "$path" >/dev/null || fail "guard output $path missing marker: $marker"
  done
  if grep -E 'persistent_writes_allowed: true|workspace_file_writes_allowed: true|memory_writes_allowed: true|engram_writes_allowed: true|publishing_allowed: true|scheduling_allowed: true|writes_attempted: true' "$path" >/dev/null; then
    fail "guard output $path enabled a forbidden write surface"
  fi
  if grep -E '^  prompt_execution: ' "$path" | grep -Fv 'prompt_execution: none' >/dev/null; then
    fail "guard output $path enabled prompt execution"
  fi
}

matched_denial=$(run_guard matched-denial --route-status matched-route --request "save demo preference")
assert_output "$matched_denial" \
  "response_state: approval-requested" \
  "guard_event_type: guard-denial" \
  "exact_approval_received: false" \
  "persistent_writes_allowed: false" \
  "workspace_file_writes_allowed: false" \
  "memory_writes_allowed: false" \
  "engram_writes_allowed: false" \
  "writes_attempted: false" \
  "prompt_execution: none"

invalid_approval=$(run_guard invalid-approval --route-status matched-route --request "save demo preference" --approval "approve")
assert_output "$invalid_approval" \
  "response_state: approval-requested" \
  "guard_event_type: guard-invalid-approval" \
  "exact_approval_received: false" \
  "writes_attempted: false" \
  "prompt_execution: none"

exact_approval=$(run_guard exact-approval --route-status matched-route --request "save demo preference" --approval "approve write" --prior-proposal proposal-demo)
assert_output "$exact_approval" \
  "response_state: approval-verification-required" \
  "guard_event_type: guard-approval-verification-required" \
  "exact_approval_received: true" \
  "audit_required: true" \
  "persistent_writes_allowed: false" \
  "engram_writes_allowed: false" \
  "writes_attempted: false" \
  "prompt_execution: none"

unmapped=$(run_guard unmapped --route-status unmapped-channel --request "save demo preference")
assert_output "$unmapped" \
  "response_state: needs-route" \
  "guard_event_type: guard-needs-route" \
  "durable_reads_allowed: false" \
  "persistent_writes_allowed: false" \
  "writes_attempted: false" \
  "prompt_execution: none"

rm -f "$matched_denial" "$invalid_approval" "$exact_approval" "$unmapped"

bash scripts/validate-runtime-approval-enforcement-repair.sh >/dev/null
bash scripts/validate-discord-approval-guard-cli.sh >/dev/null
bash scripts/validate-private-write-readback-preflight-gate.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "approval enforcement proof artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|runtime_enforcement_proven_for_live_private_traffic: true|readiness_gate_updated: true|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "approval enforcement proof artifacts must not claim live execution, readiness update, closure, or production behavior"
fi

echo "Validated fake runtime approval enforcement proof gate."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
