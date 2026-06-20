#!/usr/bin/env bash
set -euo pipefail

PLAN_PATH="docs/operations/private-discord-noop-rehearsal-plan.md"
FIXTURE_PATH="examples/private-discord-noop-rehearsal-evidence.fake.yaml"
GUIDE_PATH="docs/operations/private-discord-manual-verification-guide.md"
READINESS_FIXTURE="examples/private-discord-engram-rehearsal-readiness.fake.yaml"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
DISCORD_SNOWFLAKE_LIKE_PATTERN='\b[0-9]{17,20}\b'

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd grep
require_cmd python3

for path in "$PLAN_PATH" "$FIXTURE_PATH" "$GUIDE_PATH" "$READINESS_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "Status: preparation only" \
  "does not grant execution approval" \
  "summary-minimum" \
  "bash scripts/validate-discord-approval-guard-cli.sh" \
  "bash scripts/validate-discord-noop-observation-cli.sh" \
  "bash scripts/validate-discord-runtime-boundary-harness.sh" \
  "bash scripts/validate-private-discord-engram-rehearsal-readiness.sh" \
  "bash scripts/validate-repo-safe-evidence.sh" \
  "Current result: \`pass-summary\`" \
  "#211 remains blocked"; do
  grep -F "$required" "$PLAN_PATH" >/dev/null || fail "plan missing marker: $required"
done

for required in \
  "contract: private-discord-noop-rehearsal-evidence" \
  "issue: 233" \
  "parent_issue: 211" \
  "execution_approval_granted: true" \
  "execution_approval_scope: private-noop-observation-only" \
  "rehearsal_executed: true" \
  "private_noop_event_observed: true" \
  "write_like_live_discord_message_sent: false" \
  "live_discord_message_sent: false" \
  "live_engram_write_readback_attempted: false" \
  "readiness_available_and_proven: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "current_status: granted-for-noop-only" \
  "result_state: pass-summary" \
  "writes_attempted: false" \
  "issue_211_status: blocked-for-write-readback"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing marker: $required"
done

for required in \
  "Private Discord no-op rehearsal plan" \
  "docs/operations/private-discord-noop-rehearsal-plan.md" \
  "examples/private-discord-noop-rehearsal-evidence.fake.yaml" \
  "scripts/validate-private-discord-noop-rehearsal-plan.sh" \
  "does not grant execution approval"; do
  grep -F "$required" "$GUIDE_PATH" >/dev/null || fail "guide missing rehearsal marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

fixture = Path(sys.argv[1])
runtime = sys.argv[2]
data = yaml.safe_load(fixture.read_text())

false_flags = [
    "write_like_live_discord_message_sent",
    "live_discord_message_sent",
    "live_engram_write_readback_attempted",
    "live_openclaw_prompt_execution",
    "runtime_enforcement_proven",
    "readiness_available_and_proven",
    "uses_real_discord_ids",
    "raw_discord_chat_logs_included",
    "raw_private_payload_included",
    "screenshots_included",
    "secrets_included",
    "raw_engram_exports_included",
    "sql_dumps_included",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"fixture must keep {key}: false")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

required_gate_ids = {
    "approval-guard-cli",
    "noop-observation-cli",
    "runtime-boundary-harness",
    "rehearsal-readiness",
    "repo-safe-evidence",
    "explicit-noop-execution-approval",
}
gates = {item.get("id"): item for item in data.get("pre_execution_gates", [])}
if set(gates) != required_gate_ids:
    raise SystemExit("pre-execution gates mismatch")
if gates["explicit-noop-execution-approval"].get("current_status") != "granted-for-noop-only":
    raise SystemExit("explicit approval must be scoped to no-op only")
if data.get("execution_approval_scope") != "private-noop-observation-only":
    raise SystemExit("execution approval scope must remain private-noop-observation-only")

boundaries = data.get("planned_no_op_boundaries", {})
for key, value in boundaries.items():
    if value is not False:
        raise SystemExit(f"planned no-op boundary must keep {key}: false")
summary = data.get("current_summary", {})
expected = {
    "result_state": "pass-summary",
    "observed_response_mode": "response-only",
    "observed_operation": "read",
    "observed_persistence_target": "ephemeral",
    "observed_writeback_policy": "reject",
    "writes_attempted": False,
    "live_discord_message": "no-write-like-message-sent",
    "private_event_observation": "pass-summary",
    "engram_write_readback": "not-run",
    "issue_211_status": "blocked-for-write-readback",
}
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"summary mismatch: {key}")
policy = data.get("planned_evidence_policy", {})
for forbidden in ["real Discord guild/channel/user/role/message IDs", "credentials or .env values", "screenshots", "raw logs", "transcripts", "private payloads", "raw Engram exports", "SQL dumps", "backup archives"]:
    if forbidden not in policy.get("forbidden", []):
        raise SystemExit(f"missing forbidden evidence marker: {forbidden}")
PY

review_paths=("$PLAN_PATH" "$FIXTURE_PATH" "$GUIDE_PATH")
if grep -E "$DISCORD_SNOWFLAKE_LIKE_PATTERN" "${review_paths[@]}" >/dev/null; then
  fail "private no-op rehearsal artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'write_like_live_discord_message_sent: true|live_discord_message_sent: true|live_engram_write_readback_attempted: true|readiness_available_and_proven: true|production-ready|live Discord passed|approve write persistence passed' "${review_paths[@]}" >/dev/null; then
  fail "private no-op rehearsal artifacts must not claim write-like execution, readiness, or production behavior"
fi

bash scripts/validate-discord-approval-guard-cli.sh >/dev/null
bash scripts/validate-discord-noop-observation-cli.sh >/dev/null
bash scripts/validate-discord-runtime-boundary-harness.sh >/dev/null
bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

echo "Validated private Discord no-op rehearsal preparation plan."
echo "Plan: $PLAN_PATH"
echo "Fixture: $FIXTURE_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
