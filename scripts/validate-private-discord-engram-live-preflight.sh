#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${PRIVATE_DISCORD_ENGRAM_LIVE_PREFLIGHT_FIXTURE:-examples/private-discord-engram-live-preflight.fake.yaml}"
REPORT_PATH="docs/operations/private-discord-engram-live-preflight-report.md"
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

for path in "$FIXTURE_PATH" "$REPORT_PATH" "$READINESS_FIXTURE"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: sanitized-private-preflight-summary" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: private-discord-engram-live-preflight" \
  "live_discord_message_sent: false" \
  "live_engram_write_attempted: false" \
  "live_openclaw_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "screenshots_included: false" \
  "secrets_included: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "private_environment_values_printed: false" \
  "raw_values_printed: false" \
  "private_discord_engram_readiness_contract: blocked-expected" \
  "plugin_connected: true" \
  "raw_status_committed: false" \
  "execution_allowed: false" \
  "readiness_result: blocked" \
  "live_message_blocked_reason: readiness gate is not available-and-proven"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "live preflight fixture missing marker: $required"
done

for required in \
  "Private Discord-to-Engram live preflight report" \
  'Status: `blocked`' \
  "The local private runtime and Discord plugin were ready enough for a preflight" \
  "Live Discord message | not run" \
  "Live Engram write/readback | not run" \
  "explicit-execution-approval" \
  "until all three are satisfied" \
  "after both runtime paths are proven and separate explicit execution approval is granted" \
  "examples/private-discord-engram-live-preflight.fake.yaml" \
  "scripts/validate-private-discord-engram-live-preflight.sh"; do
  grep -F "$required" "$REPORT_PATH" >/dev/null || fail "live preflight report missing marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path
import yaml

fixture = Path(sys.argv[1])
runtime = sys.argv[2]
data = yaml.safe_load(fixture.read_text())

false_flags = [
    "live_discord_message_sent",
    "live_engram_write_attempted",
    "live_openclaw_prompt_execution",
    "runtime_enforcement_proven",
    "uses_real_discord_ids",
    "raw_discord_chat_logs_included",
    "raw_private_payload_included",
    "screenshots_included",
    "secrets_included",
]
for key in false_flags:
    if data.get(key) is not False:
        raise SystemExit(f"live preflight fixture must keep {key}: false")
if data.get("runtime_namespace_contract") != runtime:
    raise SystemExit("runtime namespace contract mismatch")

operator = data.get("operator_decision", {})
if operator.get("evidence_policy") != "summary-minimum" or operator.get("private_environment_values_printed") is not False:
    raise SystemExit("operator evidence policy must stay summary-minimum with no private values printed")

results = data.get("sanitized_preflight_results", {})
if results.get("git_branch") != "develop" or results.get("git_clean") is not True:
    raise SystemExit("preflight must record clean develop branch")
env = results.get("env_presence", {})
for key in ["discord_bot_token_present", "discord_guild_id_present", "openclaw_gateway_token_present", "engram_cloud_token_present"]:
    if env.get(key) is not True:
        raise SystemExit(f"preflight env presence missing {key}")
if env.get("raw_values_printed") is not False:
    raise SystemExit("preflight must not print raw env values")
validators = results.get("validators", {})
for key in ["runtime_version_baseline", "openclaw_gentle_runtime_static", "repo_safe_evidence"]:
    if validators.get(key) != "pass":
        raise SystemExit(f"validator result must pass: {key}")
if validators.get("private_discord_engram_readiness_contract") != "blocked-expected":
    raise SystemExit("readiness contract must remain blocked-expected")
runtime_results = results.get("docker_runtime", {})
for key in ["compose_config", "openclaw_setup", "compose_up", "openclaw_health", "engram_health", "postgres_health"]:
    if runtime_results.get(key) != "pass":
        raise SystemExit(f"runtime preflight result must pass: {key}")
plugin = results.get("discord_plugin", {})
for key in ["plugin_present", "plugin_enabled", "plugin_connected", "bot_identity_redacted"]:
    if plugin.get(key) is not True:
        raise SystemExit(f"plugin preflight missing {key}")
if plugin.get("raw_status_committed") is not False:
    raise SystemExit("raw plugin status must not be committed")

gate = data.get("readiness_gate", {})
if gate.get("execution_allowed") is not False or gate.get("readiness_result") != "blocked":
    raise SystemExit("readiness gate must remain blocked")
for blocker in ["runtime approval enforcement repair is design-only-not-implemented", "no-op observation path is design-only-not-proven", "explicit execution approval for actual Discord message must be separated from this preflight"]:
    if blocker not in gate.get("blockers", []):
        raise SystemExit(f"missing readiness blocker: {blocker}")
if "repeat sanitized preflight only after both runtime paths are proven and separate explicit execution approval is granted" not in data.get("next_safe_actions", []):
    raise SystemExit("next safe actions must include explicit approval before repeated preflight")
PY

bash scripts/validate-private-discord-engram-rehearsal-readiness.sh >/dev/null
bash scripts/validate-repo-safe-evidence.sh >/dev/null

review_paths=("$FIXTURE_PATH" "$REPORT_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "live preflight artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'live_discord_message_sent: true|live_engram_write_attempted: true|live_openclaw_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|screenshots_included: true|secrets_included: true|live Discord message routed|live Engram write passed|production-ready' "${review_paths[@]}" >/dev/null; then
  fail "live preflight artifacts must not claim live message routing, live writes, runtime proof, or production behavior"
fi

echo "Validated sanitized private Discord-to-Engram live preflight report."
echo "Fixture: $FIXTURE_PATH"
echo "Report: $REPORT_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
