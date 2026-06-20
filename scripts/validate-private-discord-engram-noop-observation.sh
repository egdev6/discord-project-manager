#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_DISCORD_ENGRAM_NOOP_FIXTURE:-examples/private-discord-engram-noop-observation.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
VERTICAL_FIXTURE="examples/private-discord-engram-vertical-slice.fake.yaml"
APPROVAL_FIXTURE="examples/discord-approval-gate.fake.yaml"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$VERTICAL_FIXTURE" "$APPROVAL_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-discord-engram-noop-observation" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "execution_allowed: false" \
  "observation_design_status: design-only-not-proven" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "name: no-op-observation-preview" \
  "prompt_execution_allowed: false" \
  "workspace_file_writes_allowed: false" \
  "durable_memory_writes_allowed: false" \
  "engram_writes_allowed: false" \
  "response_state: approval-requested" \
  "approved_for_write_allowed: false" \
  "route_status: matched-route" \
  "route_status: unmapped-channel" \
  "expected_next_state: needs-route" \
  "runner_backend: response-only" \
  "writes_attempted: false" \
  "prompt_execution: none" \
  "current_status: design-only-not-proven" \
  "required_future_status: available-and-proven"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "no-op fixture missing marker: $required"
done

for required in \
  "Private Discord-to-Engram no-op observation design" \
  "examples/private-discord-engram-noop-observation.fake.yaml" \
  "scripts/validate-private-discord-engram-noop-observation.sh" \
  "design-only-not-proven" \
  "does not update the readiness gate"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing no-op observation marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

fixture = Path(sys.argv[1])
runtime = sys.argv[2]
data = yaml.safe_load(fixture.read_text())

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
        raise SystemExit(f"no-op fixture must keep {key}: false")
if data.get("observation_design_status") != "design-only-not-proven":
    raise SystemExit("no-op observation design must remain not proven")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

objective = data.get("objective", {})
if objective.get("proves_runtime_behavior") is not False or objective.get("updates_readiness_gate") is not False:
    raise SystemExit("no-op design must not claim runtime proof or readiness update")

envelope = data.get("synthetic_event_envelope", {})
for key in ["guild_id", "channel_id", "message_id"]:
    expected = f"<{key.replace('_', '-')}>"
    if envelope.get(key) != expected:
        raise SystemExit(f"synthetic envelope must use placeholder for {key}")
if envelope.get("raw_content_committed") is not False or envelope.get("real_identifiers_committed") is not False:
    raise SystemExit("synthetic envelope must not commit raw content or identifiers")

mode = data.get("observation_mode", {})
if mode.get("name") != "no-op-observation-preview":
    raise SystemExit("observation mode name drifted")
for key in [
    "prompt_execution_allowed",
    "workspace_file_writes_allowed",
    "durable_memory_writes_allowed",
    "engram_writes_allowed",
    "filesystem_writes_allowed",
    "publishing_allowed",
    "scheduling_allowed",
    "github_mutations_allowed",
]:
    if mode.get(key) is not False:
        raise SystemExit(f"observation mode must keep {key}: false")
network = mode.get("network_calls_allowed", {})
for key in ["discord_gateway", "engram_cloud", "buffer_or_social_api"]:
    if network.get(key) is not False:
        raise SystemExit(f"network call must remain blocked: {key}")

preview = data.get("expected_preview", {})
if preview.get("response_state") != "approval-requested" or preview.get("approved_for_write_allowed") is not False:
    raise SystemExit("preview must stop at approval-requested")
routing_outcomes = {item.get("route_status"): item for item in preview.get("routing_outcomes", [])}
if set(routing_outcomes) != {"matched-route", "unmapped-channel"}:
    raise SystemExit("preview must distinguish matched-route and unmapped-channel outcomes")
if routing_outcomes["matched-route"].get("expected_next_state") != "approval-requested" or routing_outcomes["matched-route"].get("durable_writes") != "none":
    raise SystemExit("matched route preview must stop at approval-requested with no writes")
if routing_outcomes["unmapped-channel"].get("expected_next_state") != "needs-route" or routing_outcomes["unmapped-channel"].get("durable_reads") != "none" or routing_outcomes["unmapped-channel"].get("durable_writes") != "none":
    raise SystemExit("unmapped route preview must need route and avoid durable reads/writes")
if preview.get("runtime_namespace") != runtime:
    raise SystemExit("preview runtime namespace mismatch")
mandatory = set(preview.get("mandatory_skills", []))
for required in ["openclaw-runtime-orchestrator", "scoped-skill-resolver", "discord-approval-gate"]:
    if required not in mandatory:
        raise SystemExit(f"preview missing mandatory skill: {required}")
classification = preview.get("artifact_classification", {})
expected_classification = {
    "artifact_type": "private_context",
    "subtype": "profile",
    "operation": "update",
    "persistence_target": "private-runtime",
    "approval_required": True,
    "backup_required": True,
    "deployment_required": False,
    "runner_backend": "response-only",
    "writeback_policy": "confirmation-required",
}
for key, expected in expected_classification.items():
    if classification.get(key) != expected:
        raise SystemExit(f"classification mismatch: {key}")
boundaries = preview.get("no_op_boundaries", {})
if boundaries.get("writes_attempted") is not False:
    raise SystemExit("no-op preview must not attempt writes")
if boundaries.get("prompt_execution") != "none" or boundaries.get("durable_writes") != "none":
    raise SystemExit("no-op preview must not execute prompts or durable writes")

checks = {item.get("id"): item for item in data.get("acceptance_checks", [])}
for required in ["no-prompt-execution", "no-workspace-writes", "approval-requested-only", "approval-gate-visible", "namespace-placeholders-only"]:
    if checks.get(required, {}).get("expected") is not True:
        raise SystemExit(f"missing acceptance check: {required}")

blocked = data.get("blocked_until_proven", {})
if blocked.get("readiness_check_id") != "no-op-observation-path":
    raise SystemExit("blocked section must reference no-op-observation-path")
if blocked.get("current_status") != "design-only-not-proven" or blocked.get("required_future_status") != "available-and-proven":
    raise SystemExit("blocked status must remain design-only-not-proven until proven")
if "separately approved runtime run summary" not in str(blocked.get("proof_required", "")):
    raise SystemExit("proof must require separately approved runtime run summary")
if blocked.get("fixture_only_evidence_satisfies_proof") is not False or blocked.get("synthetic_fixture_only_satisfies_proof") is not False:
    raise SystemExit("fixture-only or synthetic-fixture-only evidence must not satisfy proof")
if blocked.get("readiness_fixture_ref") != "examples/private-discord-engram-rehearsal-readiness.fake.yaml":
    raise SystemExit("blocked section must reference readiness fixture")

policy = data.get("sanitized_evidence_policy", {})
for forbidden in ["real Discord guild/channel/user/message IDs", "credentials or .env values", "screenshots", "raw logs", "transcripts", "private payloads", "raw Engram exports", "SQL dumps"]:
    if forbidden not in policy.get("forbidden", []):
        raise SystemExit(f"missing forbidden evidence marker: {forbidden}")
PY

if [[ "${PRIVATE_READINESS_CROSSCHECK_SKIP:-0}" != "1" ]]; then
  bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
fi
bash scripts/validate-discord-approval-gate.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$VERTICAL_FIXTURE" "$APPROVAL_FIXTURE")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "no-op observation artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|execution_allowed: true|observation_design_status: proven|proves_runtime_behavior: true|updates_readiness_gate: true|live no-op observation passed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "no-op observation artifacts must not claim live execution, runtime proof, readiness update, or production behavior"
fi

echo "Validated fake private Discord-to-Engram no-op observation design."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
