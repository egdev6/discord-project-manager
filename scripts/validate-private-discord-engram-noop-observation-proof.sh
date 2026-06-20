#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_DISCORD_ENGRAM_NOOP_OBSERVATION_PROOF_FIXTURE:-examples/private-discord-engram-noop-observation-proof.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
NOOP_PATH="docker/openclaw/discord-noop-observation.sh"
NOOP_FIXTURE="examples/private-discord-engram-noop-observation.fake.yaml"
APPROVAL_PROOF_FIXTURE="examples/runtime-approval-enforcement-proof.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$NOOP_PATH" "$NOOP_FIXTURE" "$APPROVAL_PROOF_FIXTURE" "$READINESS_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done
[[ -x "$NOOP_PATH" ]] || fail "no-op helper is not executable: $NOOP_PATH"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-discord-engram-noop-observation-proof" \
  "issue: 256" \
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
  "noop_observation_proof_level: repo-safe-synthetic-noop-cli" \
  "noop_observation_proven_for_live_private_traffic: false" \
  "readiness_gate_updated: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "id: matched-write-like-noop-observation" \
  "id: unmapped-write-like-noop-observation" \
  "repo_safe_synthetic_status: synthetic-noop-cli-proven" \
  "current_readiness_status: design-only-not-proven" \
  "required_future_status: available-and-proven" \
  "updates_readiness_fixture_now: false"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "no-op proof fixture missing marker: $required"
done

for required in \
  "Private Discord-to-Engram no-op observation proof gate" \
  "examples/private-discord-engram-noop-observation-proof.fake.yaml" \
  "scripts/validate-private-discord-engram-noop-observation-proof.sh" \
  "repo-safe synthetic no-op proof" \
  "does not prove live private no-op observation" \
  "does not update #211 readiness to available-and-proven"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing no-op proof marker: $required"
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
    "noop_observation_proven_for_live_private_traffic",
    "readiness_gate_updated",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"no-op observation proof must keep {key}: false")
if data.get("noop_observation_proof_level") != "repo-safe-synthetic-noop-cli":
    raise SystemExit("proof level must remain repo-safe synthetic no-op CLI")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "docker/openclaw/discord-noop-observation.sh",
    "docker/openclaw/discord-approval-guard.sh",
    "scripts/validate-discord-noop-observation-cli.sh",
    "examples/private-discord-engram-noop-observation.fake.yaml",
    "examples/runtime-approval-enforcement-proof.fake.yaml",
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

boundary = data.get("proof_boundary", {})
for required in [
    "synthetic matched-route write-like envelope stops at approval-requested",
    "synthetic unmapped-channel write-like envelope stops at needs-route",
    "prompt execution remains none",
    "workspace filesystem Engram network publishing scheduling and GitHub mutations remain blocked",
    "evidence policy remains sanitized-summary-only",
]:
    if required not in boundary.get("proves", []):
        raise SystemExit(f"missing proof boundary: {required}")
for required in [
    "live Discord gateway delivery",
    "private redacted event ingestion",
    "live OpenClaw prompt execution safety",
    "server-side proposal binding",
    "Engram write/readback",
    "issue 211 completion",
]:
    if required not in boundary.get("does_not_prove", []):
        raise SystemExit(f"missing non-proof boundary: {required}")

expected = {
    "matched-write-like-noop-observation": ("matched-route", "approval-requested", "guard-denial", True),
    "unmapped-write-like-noop-observation": ("unmapped-channel", "needs-route", "guard-needs-route", False),
}
probes = {item.get("id"): item for item in data.get("synthetic_probe_matrix", [])}
if set(probes) != set(expected):
    raise SystemExit("synthetic probe matrix coverage drifted")
for probe_id, (route, state, event, durable_reads) in expected.items():
    probe = probes[probe_id]
    if probe.get("expected_event_source") != "synthetic-discord-envelope":
        raise SystemExit(f"event source drifted for {probe_id}")
    if probe.get("expected_route_status") != route:
        raise SystemExit(f"route status drifted for {probe_id}")
    if probe.get("expected_response_state") != state:
        raise SystemExit(f"response state drifted for {probe_id}")
    if probe.get("expected_guard_event_type") != event:
        raise SystemExit(f"guard event drifted for {probe_id}")
    if probe.get("durable_reads_allowed") is not durable_reads:
        raise SystemExit(f"durable read expectation drifted for {probe_id}")
    for key in [
        "persistent_writes_allowed",
        "workspace_file_writes_allowed",
        "memory_writes_allowed",
        "engram_writes_allowed",
        "writes_attempted",
        "network_calls_attempted",
        "filesystem_writes_attempted",
        "publishing_attempted",
        "scheduling_attempted",
        "github_mutations_attempted",
    ]:
        if probe.get(key) is not False:
            raise SystemExit(f"probe {probe_id} must keep {key}: false")
    if probe.get("prompt_execution") != "none":
        raise SystemExit(f"probe {probe_id} must keep prompt_execution none")
    if probe.get("evidence_policy") != "sanitized-summary-only":
        raise SystemExit(f"probe {probe_id} must keep sanitized evidence policy")

fail_closed = data.get("fail_closed_expectations", {})
for required in [
    "private topology prepared outside repo",
    "private redacted event ingestion proof",
    "server-side proposal binding proof",
    "explicit human execution approval",
    "sanitized execution/readback evidence review",
]:
    if required not in fail_closed.get("required_before_private_execution", []):
        raise SystemExit(f"missing required before private execution: {required}")
if fail_closed.get("readiness_check_id") != "no-op-observation-path":
    raise SystemExit("readiness check id mismatch")
if fail_closed.get("current_readiness_status") != "design-only-not-proven":
    raise SystemExit("current readiness must remain design-only-not-proven")
if fail_closed.get("repo_safe_synthetic_status") != "synthetic-noop-cli-proven":
    raise SystemExit("repo-safe synthetic status mismatch")
if fail_closed.get("required_future_status") != "available-and-proven":
    raise SystemExit("future readiness status mismatch")
if fail_closed.get("updates_readiness_fixture_now") is not False:
    raise SystemExit("proof gate must not update readiness fixture now")

non_goals = set(data.get("non_goals", []))
for required in [
    "executing live Discord messages",
    "executing an Engram write",
    "executing a live readback from Engram",
    "proving live private no-op observation",
    "updating readiness to available-and-proven",
    "closing issue 211",
]:
    if required not in non_goals:
        raise SystemExit(f"missing non-goal: {required}")
PY

run_noop() {
  local name="$1"
  shift
  "$NOOP_PATH" "$@" >"${TMPDIR:-/tmp}/noop-proof-${name}.out"
  printf '%s\n' "${TMPDIR:-/tmp}/noop-proof-${name}.out"
}

assert_noop_output() {
  local path="$1"
  local expected_route="$2"
  local expected_state="$3"
  local expected_event="$4"
  local expected_durable_reads="$5"

  python3 - "$path" "$expected_route" "$expected_state" "$expected_event" "$expected_durable_reads" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
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
            raise SystemExit(f"duplicate no-op output YAML key rejected: {key}")
        mapping[key] = loader.construct_object(value_node, deep=deep)
    return mapping

UniqueKeyLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    construct_mapping,
)

path = Path(sys.argv[1])
expected_route = sys.argv[2]
expected_state = sys.argv[3]
expected_event = sys.argv[4]
expected_durable_reads = sys.argv[5] == "true"
runtime = sys.argv[6]

data = yaml.load(path.read_text(), Loader=UniqueKeyLoader)
if set(data) != {"noop_observation_result"}:
    raise SystemExit("no-op output must contain only noop_observation_result root")
result = data["noop_observation_result"]

expected_keys = {
    "event_source",
    "live_discord_connection",
    "live_engram_calls",
    "live_openclaw_prompt_execution",
    "runtime_namespace",
    "target_namespace",
    "route_status",
    "content_summary",
    "write_like",
    "response_state",
    "persistent_writes_allowed",
    "workspace_file_writes_allowed",
    "memory_writes_allowed",
    "engram_writes_allowed",
    "durable_reads_allowed",
    "writes_attempted",
    "prompt_execution",
    "guard_event_type",
    "network_calls_attempted",
    "filesystem_writes_attempted",
    "publishing_attempted",
    "scheduling_attempted",
    "github_mutations_attempted",
    "evidence_policy",
}
if set(result) != expected_keys:
    missing = sorted(expected_keys - set(result))
    extra = sorted(set(result) - expected_keys)
    raise SystemExit(f"no-op output schema drifted; missing={missing} extra={extra}")

expected_values = {
    "event_source": "synthetic-discord-envelope",
    "live_discord_connection": False,
    "live_engram_calls": False,
    "live_openclaw_prompt_execution": False,
    "runtime_namespace": runtime,
    "route_status": expected_route,
    "content_summary": "save demo preference",
    "write_like": True,
    "response_state": expected_state,
    "persistent_writes_allowed": False,
    "workspace_file_writes_allowed": False,
    "memory_writes_allowed": False,
    "engram_writes_allowed": False,
    "durable_reads_allowed": expected_durable_reads,
    "writes_attempted": False,
    "prompt_execution": "none",
    "guard_event_type": expected_event,
    "network_calls_attempted": False,
    "filesystem_writes_attempted": False,
    "publishing_attempted": False,
    "scheduling_attempted": False,
    "github_mutations_attempted": False,
    "evidence_policy": "sanitized-summary-only",
}
for key, expected in expected_values.items():
    if result.get(key) != expected:
        raise SystemExit(f"no-op output mismatch for {key}: expected {expected!r}, got {result.get(key)!r}")

target = result.get("target_namespace")
if not isinstance(target, str) or not target.startswith("discord-project-manager/project/"):
    raise SystemExit("no-op output target namespace must be sanitized project namespace")
PY
}

matched=$(run_noop matched --route-status matched-route --content-summary "save demo preference")
assert_noop_output "$matched" "matched-route" "approval-requested" "guard-denial" "true"

unmapped=$(run_noop unmapped --route-status unmapped-channel --content-summary "save demo preference")
assert_noop_output "$unmapped" "unmapped-channel" "needs-route" "guard-needs-route" "false"

rm -f "$matched" "$unmapped"

bash scripts/validate-private-discord-engram-noop-observation.sh >/dev/null
bash scripts/validate-discord-noop-observation-cli.sh >/dev/null
bash scripts/validate-runtime-approval-enforcement-proof.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "no-op proof artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|noop_observation_proven_for_live_private_traffic: true|readiness_gate_updated: true|available-and-proven-now|issue 211 closed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "no-op proof artifacts must not claim live execution, readiness update, closure, or production behavior"
fi

echo "Validated fake private Discord-to-Engram no-op observation proof gate."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
