#!/usr/bin/env bash
set -euo pipefail

HARNESS_PATH="docker/openclaw/discord-admin-ux-preview-harness.sh"
DOCKERFILE_PATH="docker/openclaw/Dockerfile"
ADMIN_DOC_PATH="docs/architecture/discord-admin-ux.md"
ADMIN_FIXTURE_PATH="examples/discord-admin-ux.fake.yaml"
ADMIN_VALIDATOR_PATH="scripts/validate-discord-admin-ux.sh"
RUNTIME_DOC_PATH="docs/operations/docker-runtime.md"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for path in "$HARNESS_PATH" "$DOCKERFILE_PATH" "$ADMIN_DOC_PATH" "$ADMIN_FIXTURE_PATH" "$ADMIN_VALIDATOR_PATH" "$RUNTIME_DOC_PATH"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

bash -n "$HARNESS_PATH" || fail "admin UX preview harness has invalid shell syntax"

grep -F "discord-project-manager-admin-ux-preview-harness" "$DOCKERFILE_PATH" >/dev/null || fail "Dockerfile does not install admin UX preview harness"
grep -F "repo-safe-synthetic-admin-preview-only" "$HARNESS_PATH" >/dev/null || fail "harness must report repo-safe synthetic evidence mode"
grep -F "private_profile_content_included: false" "$HARNESS_PATH" >/dev/null || fail "harness must report no private profile content"
grep -F "raw_exports_included: false" "$HARNESS_PATH" >/dev/null || fail "harness must report no raw exports"
grep -F "sql_dumps_included: false" "$HARNESS_PATH" >/dev/null || fail "harness must report no SQL dumps"
grep -F "network_calls_attempted: false" "$HARNESS_PATH" >/dev/null || fail "harness must report no network calls"
grep -F "filesystem_writes_attempted: false" "$HARNESS_PATH" >/dev/null || fail "harness must report no filesystem writes"
grep -F "docs/operations/private-runtime-backup-restore.md" "$HARNESS_PATH" >/dev/null || fail "harness must reference backup/restore runbook"

grep -F "discord-project-manager-admin-ux-preview-harness" "$RUNTIME_DOC_PATH" >/dev/null || fail "docker runtime doc missing admin UX preview harness command"
grep -F "repo-safe synthetic admin UX preview" "$RUNTIME_DOC_PATH" >/dev/null || fail "docker runtime doc must describe admin UX preview as repo-safe synthetic"
grep -F "ADMIN_UX_PREVIEW_HARNESS_DOCKER_SMOKE=1" "$RUNTIME_DOC_PATH" >/dev/null || fail "docker runtime doc missing packaged invocation validation flag"

run_harness() {
  sh "$HARNESS_PATH"
}

assert_contains() {
  local output="$1"
  local expected="$2"
  grep -F "$expected" <<<"$output" >/dev/null || {
    printf '%s\n' "$output" >&2
    fail "missing expected output: $expected"
  }
}

normal_output="$(run_harness)"
for expected in \
  "evidence_mode: repo-safe-synthetic-admin-preview-only" \
  "runtime_namespace: $RUNTIME_NAMESPACE_CONTRACT" \
  "live_discord_connection: false" \
  "live_openclaw_execution: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "durable_writes_enabled: false" \
  "github_mutations_enabled: false" \
  "private_profile_content_included: false" \
  "raw_exports_included: false" \
  "sql_dumps_included: false" \
  "publishing_attempted: false" \
  "scheduling_attempted: false" \
  "network_calls_attempted: false" \
  "filesystem_writes_attempted: false" \
  "name: list-profiles-summary" \
  "name: list-scope-bindings-summary" \
  "name: bind-profile-preview" \
  "name: clone-profile-preview" \
  "name: inspect-effective-runtime" \
  "name: disable-skill-preview" \
  "name: capability-toggle-preview" \
  "name: backup-export-request" \
  "backup_runbook_ref: docs/operations/private-runtime-backup-restore.md"; do
  assert_contains "$normal_output" "$expected"
done

tmp_output="$(mktemp)"
printf '%s\n' "$normal_output" >"$tmp_output"
python3 - "$tmp_output" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text().splitlines()
scenarios = []
current = None
for raw in text:
    if raw.startswith("    - name:"):
        if current:
            scenarios.append(current)
        current = {"name": raw.split(":", 1)[1].strip()}
        continue
    if current and raw.startswith("      ") and ":" in raw:
        key, value = raw.strip().split(":", 1)
        current[key] = value.strip()
if current:
    scenarios.append(current)

expected = {
    "list_profiles",
    "list_scope_bindings",
    "bind_profile_preview",
    "clone_profile_preview",
    "inspect_effective_runtime",
    "toggle_skill_or_capability_preview",
    "backup_export_request",
}
seen = {s.get("action_family") for s in scenarios}
missing = expected - seen
if missing:
    raise SystemExit(f"missing admin preview action families: {sorted(missing)}")

for scenario in scenarios:
    name = scenario.get("name")
    if scenario.get("private_content_included") != "false":
        raise SystemExit(f"{name} must not include private content")
    if scenario.get("write_executed") != "false":
        raise SystemExit(f"{name} must not execute writes")
    if scenario.get("admin_state") == "approval-requested":
        if scenario.get("approval_required") != "true":
            raise SystemExit(f"{name} approval-requested scenario must require approval")
        if scenario.get("approval_skill") != "discord-approval-gate":
            raise SystemExit(f"{name} must use discord-approval-gate")
        if scenario.get("exact_approval_phrase") != "approve write":
            raise SystemExit(f"{name} must require exact approve write phrase")
    if scenario.get("action_family") == "backup_export_request":
        if scenario.get("backup_runbook_ref") != "docs/operations/private-runtime-backup-restore.md":
            raise SystemExit("backup/export preview must route to backup runbook")
        if scenario.get("raw_exports_included") != "false" or scenario.get("sql_dumps_included") != "false":
            raise SystemExit("backup/export preview must not include exports or SQL dumps")
PY

if grep -E '\b[0-9]{17,20}\b' "$HARNESS_PATH" "$ADMIN_DOC_PATH" "$ADMIN_FIXTURE_PATH" "$RUNTIME_DOC_PATH" >/dev/null; then
  fail "admin UX preview artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "$HARNESS_PATH" "$ADMIN_DOC_PATH" "$ADMIN_FIXTURE_PATH" "$RUNTIME_DOC_PATH" >/dev/null; then
  fail "admin UX preview artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_openclaw_execution: true|live_engram_calls: true|live_prompt_execution: true|durable_writes_enabled: true|github_mutations_enabled: true|private_profile_content_included: true|raw_exports_included: true|sql_dumps_included: true|publishing_attempted: true|scheduling_attempted: true|production-ready|live Discord validation passed|export attached|SQL dump attached|profile content included' "$HARNESS_PATH" "$ADMIN_DOC_PATH" "$ADMIN_FIXTURE_PATH" "$RUNTIME_DOC_PATH" >/dev/null; then
  fail "admin UX preview artifacts must not claim live, production, mutation, private export, publishing, scheduling, or execution behavior"
fi

run_packaged_openclaw_invocation() {
  command -v docker >/dev/null 2>&1 || fail "docker command not found for packaged OpenClaw invocation"
  docker compose version >/dev/null 2>&1 || fail "docker compose not available for packaged OpenClaw invocation"
  packaged_output="$(docker compose run --rm --no-deps openclaw discord-project-manager-admin-ux-preview-harness)"
  assert_contains "$packaged_output" "evidence_mode: repo-safe-synthetic-admin-preview-only"
  assert_contains "$packaged_output" "name: backup-export-request"
  assert_contains "$packaged_output" "write_executed: false"
  assert_contains "$packaged_output" "raw_exports_included: false"
  assert_contains "$packaged_output" "sql_dumps_included: false"
}

if [ "${ADMIN_UX_PREVIEW_HARNESS_DOCKER_SMOKE:-0}" = "1" ]; then
  run_packaged_openclaw_invocation
else
  echo "Skipping packaged OpenClaw invocation; set ADMIN_UX_PREVIEW_HARNESS_DOCKER_SMOKE=1 to run docker compose smoke."
fi

echo "Validated synthetic Discord admin UX preview harness."
echo "Harness: $HARNESS_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
