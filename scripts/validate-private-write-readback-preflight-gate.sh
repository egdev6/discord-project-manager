#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_WRITE_READBACK_PREFLIGHT_GATE_FIXTURE:-examples/private-write-readback-preflight-gate.fake.yaml}"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
LIVE_PREFLIGHT_FIXTURE="examples/private-discord-engram-live-preflight.fake.yaml"
APPROVAL_DOC="docs/operations/discord-approval-responses.md"
AUDIT_DOC="docs/architecture/discord-durable-change-audit.md"
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

for path in "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE" "$LIVE_PREFLIGHT_FIXTURE" "$APPROVAL_DOC" "$AUDIT_DOC"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-write-readback-preflight-gate" \
  "issue: 252" \
  "parent_issue: 211" \
  "parent_issue_status: remains-open-until-private-execution-reviewed" \
  "live_discord_message_sent: false" \
  "live_engram_write_attempted: false" \
  "live_readback_attempted: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "execution_allowed: false" \
  "gate_result: blocked" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "explicit_write_approval: not-granted" \
  "scope_confirmation: not-confirmed" \
  "namespace_confirmation: not-confirmed" \
  "evidence_schema_review: not-reviewed" \
  "project_ref: project/<project-key>" \
  "channel_scope: <guild-id>/<channel-id>" \
  "runtime_namespace: $RUNTIME_NAMESPACE_CONTRACT" \
  "durable_target_namespace: discord-project-manager/project/<project-key>/private-context" \
  "readback_target_namespace: discord-project-manager/project/<project-key>/private-context" \
  "placeholders_only: true" \
  "raw_values_printed: false" \
  "placeholder_only: true" \
  "raw_values_allowed: false" \
  "identifiers_allowed: false" \
  "execution_result_default: not-run" \
  "readback_result_default: not-run" \
  "id: explicit-write-approval" \
  "id: target-scope" \
  "id: target-namespace" \
  "id: evidence-schema" \
  "allowed_now: false" \
  "no private write/readback was executed by this issue" \
  "keep #211 open until actual private execution and readback are separately approved, executed, and reviewed"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "preflight gate fixture missing marker: $required"
done

for required in \
  "Private write/readback preflight gate" \
  "examples/private-write-readback-preflight-gate.fake.yaml" \
  "scripts/validate-private-write-readback-preflight-gate.sh" \
  "execution_allowed: false" \
  "does not execute a private Discord message" \
  "does not execute an Engram write or readback" \
  "#211 remains open"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "manual guide missing preflight gate marker: $required"
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
    "live_discord_message_sent",
    "live_engram_write_attempted",
    "live_readback_attempted",
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
        raise SystemExit(f"preflight gate fixture must keep {key}: false")

if data.get("gate_result") != "blocked":
    raise SystemExit("preflight gate must remain blocked")
if data.get("parent_issue") != 211:
    raise SystemExit("preflight gate must reference parent issue 211")
if data.get("parent_issue_status") != "remains-open-until-private-execution-reviewed":
    raise SystemExit("parent issue must remain open until real execution is reviewed")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_contracts = {
    "docs/operations/private-discord-manual-verification-guide.md",
    "docs/operations/discord-approval-responses.md",
    "docs/architecture/discord-durable-change-audit.md",
    "examples/private-discord-engram-rehearsal-readiness.fake.yaml",
    "examples/private-discord-engram-live-preflight.fake.yaml",
}
if set(data.get("source_contracts", [])) != required_contracts:
    raise SystemExit("source contracts drifted")

operator = data.get("operator_inputs", {})
expected_operator = {
    "requested_operation": "private-write-readback-preflight",
    "explicit_write_approval": "not-granted",
    "scope_confirmation": "not-confirmed",
    "namespace_confirmation": "not-confirmed",
    "evidence_schema_review": "not-reviewed",
    "real_identifiers_committed": False,
    "credentials_committed": False,
    "raw_payloads_committed": False,
}
for key, expected in expected_operator.items():
    if operator.get(key) != expected:
        raise SystemExit(f"operator input mismatch for {key}")

scope = data.get("sanitized_scope_preview", {})
if scope.get("project_ref") != "project/<project-key>":
    raise SystemExit("scope preview must use placeholder project ref")
if scope.get("channel_scope") != "<guild-id>/<channel-id>":
    raise SystemExit("scope preview must use placeholder channel scope")
for key in ["operation_summary", "route_ref"]:
    if not isinstance(scope.get(key), str) or not scope.get(key):
        raise SystemExit(f"scope preview missing {key}")
if scope.get("raw_scope_values_printed") is not False:
    raise SystemExit("scope preview must not print raw scope values")

namespace = data.get("sanitized_namespace_preview", {})
expected_namespace = {
    "runtime_namespace": runtime,
    "durable_target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "readback_target_namespace": "discord-project-manager/project/<project-key>/private-context",
    "placeholders_only": True,
    "raw_values_printed": False,
}
for key, expected in expected_namespace.items():
    if namespace.get(key) != expected:
        raise SystemExit(f"namespace preview mismatch for {key}")

schema = data.get("sanitized_evidence_schema", {})
if schema.get("placeholder_only") is not True or schema.get("raw_values_allowed") is not False or schema.get("identifiers_allowed") is not False:
    raise SystemExit("evidence schema must stay placeholder-only with raw values and identifiers blocked")
required_sections = {
    "approval_state",
    "scope_preview",
    "namespace_preview",
    "execution_result",
    "readback_result",
    "blocked_reason",
}
if set(schema.get("required_sections", [])) != required_sections:
    raise SystemExit("evidence schema required sections drifted")
if schema.get("execution_result_default") != "not-run" or schema.get("readback_result_default") != "not-run":
    raise SystemExit("execution/readback defaults must remain not-run")

checks = {item.get("id"): item for item in data.get("gate_checks", [])}
expected_checks = {
    "explicit-write-approval": ("not-granted", "decision-summary-only"),
    "target-scope": ("not-confirmed", "placeholder-summary-only"),
    "target-namespace": ("not-confirmed", "placeholder-summary-only"),
    "evidence-schema": ("not-reviewed", "schema-summary-only"),
}
if set(checks) != set(expected_checks):
    raise SystemExit("gate check coverage drifted")
for check_id, (status, evidence_mode) in expected_checks.items():
    check = checks[check_id]
    if check.get("status") != status:
        raise SystemExit(f"gate check status drifted: {check_id}")
    if check.get("required_before_execution") is not True:
        raise SystemExit(f"gate check must remain required: {check_id}")
    if check.get("evidence_allowed_in_repo") != evidence_mode:
        raise SystemExit(f"gate check evidence mode drifted: {check_id}")
    if not isinstance(check.get("blocker"), str) or not check.get("blocker"):
        raise SystemExit(f"gate check blocker missing: {check_id}")

execution = data.get("execution_gate", {})
if execution.get("allowed_now") is not False or execution.get("gate_result") != "blocked":
    raise SystemExit("execution gate must remain blocked")
stop_reasons = set(execution.get("stop_reasons", []))
for required in [
    "explicit write approval is not granted",
    "target scope is not confirmed with sanitized placeholders",
    "target namespace is not confirmed with sanitized placeholders",
    "evidence schema review is not completed",
    "no private write/readback was executed by this issue",
]:
    if required not in stop_reasons:
        raise SystemExit(f"missing stop reason: {required}")
next_actions = execution.get("next_safe_actions", [])
for required in [
    "review scope and namespace placeholders without private identifiers",
    "agree the sanitized evidence schema before any private execution request",
    "keep #211 open until actual private execution and readback are separately approved, executed, and reviewed",
]:
    if required not in next_actions:
        raise SystemExit(f"missing next safe action: {required}")

policy = data.get("sanitized_evidence_policy", {})
for allowed in [
    "pass status summary",
    "blocked status summary",
    "not-run status summary",
    "placeholder namespace refs",
    "approval decision summary without identifiers",
    "validator command names and pass/fail summaries",
]:
    if allowed not in policy.get("allowed", []):
        raise SystemExit(f"missing allowed evidence marker: {allowed}")
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
    "executing a private Discord message",
    "executing an Engram write",
    "executing a live readback from Engram",
    "closing issue 211",
]:
    if required not in non_goals:
        raise SystemExit(f"missing non-goal: {required}")
PY

if [[ "${PRIVATE_READINESS_CROSSCHECK_SKIP:-0}" != "1" ]]; then
  bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
fi
PRIVATE_READINESS_CROSSCHECK_SKIP=1 bash scripts/validate-private-discord-engram-live-preflight.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$GUIDE_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "preflight gate artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_message_sent: true|live_engram_write_attempted: true|live_readback_attempted: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|execution_allowed: true|gate_result: ready|issue 211 closed|live Discord write/readback passed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "preflight gate artifacts must not claim live execution, readiness, closure, or production behavior"
fi

echo "Validated fake private write/readback preflight gate."
echo "Fixture: $FIXTURE_PATH"
echo "Guide: $GUIDE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
