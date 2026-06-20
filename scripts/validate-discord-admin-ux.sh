#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_ADMIN_UX_FIXTURE:-examples/discord-admin-ux.fake.yaml}"
DOC_PATH="docs/architecture/discord-admin-ux.md"
MANAGED_ROUTING_DOC_PATH="docs/architecture/discord-managed-channel-routing.md"
SCOPED_SKILLS_DOC_PATH="docs/architecture/discord-scoped-skills-registry.md"
EFFECTIVE_RESOLVER_DOC_PATH="docs/architecture/discord-effective-runtime-resolver.md"
ORCH_DOC_PATH="docs/architecture/discord-runtime-orchestrator.md"
MEMORY_GATEWAY_DOC_PATH="docs/architecture/discord-memory-gateway.md"
BACKUP_RUNBOOK_PATH="docs/operations/private-runtime-backup-restore.md"
ROUTING_DOC_PATH="docs/operations/discord-routing.md"
CONFIG_README_PATH="openclaw/config/README.md"
RUNTIME_NAMESPACE_CONTRACT="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for path in "$FIXTURE_PATH" "$DOC_PATH" "$MANAGED_ROUTING_DOC_PATH" "$SCOPED_SKILLS_DOC_PATH" "$EFFECTIVE_RESOLVER_DOC_PATH" "$ORCH_DOC_PATH" "$MEMORY_GATEWAY_DOC_PATH" "$BACKUP_RUNBOOK_PATH" "$ROUTING_DOC_PATH" "$CONFIG_README_PATH"; do
  [[ -f "$path" ]] || fail "required file not found: $path"
done

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-admin-ux" \
  "parent_issue: 196" \
  "live_discord_connection: false" \
  "live_openclaw_execution: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "durable_writes_enabled: false" \
  "github_mutations_enabled: false" \
  "uses_real_discord_ids: false" \
  "private_profile_content_included: false" \
  "raw_discord_chat_logs_included: false" \
  "raw_exports_included: false" \
  "sql_dumps_included: false" \
  "production_credentials: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "name: list-profiles-summary" \
  "name: list-scope-bindings-summary" \
  "name: bind-profile-preview" \
  "name: clone-profile-preview" \
  "name: inspect-effective-runtime" \
  "name: disable-skill-preview" \
  "name: capability-toggle-preview" \
  "name: backup-export-request"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing required marker: $required"
done

for required in \
  "docs/architecture/discord-managed-channel-routing.md" \
  "docs/architecture/discord-scoped-skills-registry.md" \
  "docs/architecture/discord-effective-runtime-resolver.md" \
  "docs/architecture/discord-runtime-orchestrator.md" \
  "docs/architecture/discord-memory-gateway.md" \
  "skills/discord-approval-gate/SKILL.md" \
  "docs/operations/private-runtime-backup-restore.md"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing dependency marker: $required"
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing dependency marker: $required"
done

for required in \
  "Admin action families" \
  "Response schema" \
  "list_profiles" \
  "list_scope_bindings" \
  "bind_profile_preview" \
  "clone_profile_preview" \
  "inspect_effective_runtime" \
  "toggle_skill_or_capability_preview" \
  "backup_export_request" \
  "private_content_included" \
  "write_executed"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing admin UX marker: $required"
done

grep -F "docs/architecture/discord-admin-ux.md" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing admin UX reference"
grep -F "examples/discord-admin-ux.fake.yaml" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing admin UX fixture"
grep -F "scripts/validate-discord-admin-ux.sh" "$ROUTING_DOC_PATH" >/dev/null || fail "routing doc missing admin UX validator"
grep -F "docs/architecture/discord-admin-ux.md" "$CONFIG_README_PATH" >/dev/null || fail "config README missing admin UX reference"

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path

fixture_path = Path(sys.argv[1])
runtime_contract = sys.argv[2]
lines = fixture_path.read_text().splitlines()
scenarios = []
current = None
section = None

for raw in lines:
    if raw.startswith("  - name:"):
        if current:
            scenarios.append(current)
        current = {"name": raw.split(":", 1)[1].strip(), "request": {}, "response": {}}
        section = None
        continue
    if not current:
        continue
    if raw.startswith("    request:"):
        section = "request"; continue
    if raw.startswith("    response:"):
        section = "response"; continue
    if section and raw.startswith("      ") and not raw.startswith("        ") and ":" in raw:
        key, value = raw.strip().split(":", 1)
        current[section][key] = value.strip().strip('"')
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
seen = {s["request"].get("action_family") for s in scenarios}
missing = expected - seen
if missing:
    raise SystemExit(f"missing admin action families: {sorted(missing)}")

for sc in scenarios:
    name = sc["name"]
    req = sc["request"]
    res = sc["response"]
    if req.get("runtime_namespace") != runtime_contract:
        raise SystemExit(f"{name} has wrong runtime namespace")
    for key in ["action_family", "target_scope", "target_ref", "write_like"]:
        if key not in req:
            raise SystemExit(f"{name} missing request field {key}")
    for key in ["admin_state", "action_family", "target_scope", "target_ref", "resolver_source", "preview_summary", "private_content_included", "approval_required", "write_executed"]:
        if key not in res:
            raise SystemExit(f"{name} missing response field {key}")
    for key in ["action_family", "target_scope", "target_ref"]:
        if res.get(key) != req.get(key):
            raise SystemExit(f"{name} response {key} must mirror request {key}")
    if res.get("private_content_included") != "false":
        raise SystemExit(f"{name} must keep private_content_included: false")
    if res.get("write_executed") != "false":
        raise SystemExit(f"{name} must keep write_executed: false")
    if req.get("write_like") == "true":
        if res.get("approval_required") != "true":
            raise SystemExit(f"{name} write-like flow must require approval")
        if res.get("approval_skill") != "discord-approval-gate" or res.get("exact_approval_phrase") != "approve write":
            raise SystemExit(f"{name} write-like flow must name exact approval gate")
        if res.get("admin_state") != "approval-requested":
            raise SystemExit(f"{name} write-like flow must stop at approval-requested")
    if req.get("action_family") == "inspect_effective_runtime":
        if res.get("resolver_source") != "docs/architecture/discord-effective-runtime-resolver.md":
            raise SystemExit("effective runtime inspection must use effective resolver contract")
    if req.get("action_family") == "backup_export_request":
        if res.get("backup_runbook_ref") != "docs/operations/private-runtime-backup-restore.md":
            raise SystemExit("backup/export request must link backup runbook")
        if res.get("raw_exports_included") != "false" or res.get("sql_dumps_included") != "false":
            raise SystemExit("backup/export request must not include raw exports or SQL dumps")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "admin UX artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "${review_paths[@]}" >/dev/null; then
  fail "admin UX artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_openclaw_execution: true|live_engram_calls: true|live_prompt_execution: true|durable_writes_enabled: true|github_mutations_enabled: true|uses_real_discord_ids: true|private_profile_content_included: true|raw_discord_chat_logs_included: true|raw_exports_included: true|sql_dumps_included: true|production_credentials: true|publishing_enabled: true|scheduling_enabled: true|production-ready|live Discord validation passed|prompt execution proven|GitHub mutation executed|profile content included|export attached|SQL dump attached' "${review_paths[@]}" >/dev/null; then
  fail "admin UX artifacts must not claim live, production, mutation, private export, publishing, scheduling, or execution behavior"
fi

echo "Validated fake Discord admin UX contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
