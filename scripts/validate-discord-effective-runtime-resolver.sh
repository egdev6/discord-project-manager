#!/usr/bin/env bash
set -euo pipefail

FIXTURE_PATH="${DISCORD_EFFECTIVE_RUNTIME_RESOLVER_FIXTURE:-examples/discord-effective-runtime-resolver.fake.yaml}"
DOC_PATH="docs/architecture/discord-effective-runtime-resolver.md"
SKILL_PATH="skills/scoped-skill-resolver/SKILL.md"
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

[[ -f "$FIXTURE_PATH" ]] || fail "fixture not found: $FIXTURE_PATH"
[[ -f "$DOC_PATH" ]] || fail "doc not found: $DOC_PATH"
[[ -f "$SKILL_PATH" ]] || fail "skill not found: $SKILL_PATH"

for required in \
  "schema_version: 1" \
  "fixture_type: fake-demo" \
  "safe_for_repo: true" \
  "privacy_reviewed: true" \
  "contract: discord-effective-runtime-resolver" \
  "live_discord_connection: false" \
  "live_engram_calls: false" \
  "live_prompt_execution: false" \
  "runtime_enforcement_proven: false" \
  "uses_real_discord_ids: false" \
  "raw_discord_chat_logs_included: false" \
  "private_profile_content_included: false" \
  "durable_memory_writes_allowed: false" \
  "workspace_file_writes_allowed: false" \
  "filesystem_access_enabled: false" \
  "browser_automation_enabled: false" \
  "publishing_enabled: false" \
  "scheduling_enabled: false" \
  "buffer_activity_enabled: false" \
  "runtime_namespace_contract: $RUNTIME_NAMESPACE_CONTRACT" \
  "name: shared-profile-category-resolution" \
  "name: channel-profile-override-resolution" \
  "name: filesystem-capability-blocked"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing required marker: $required"
done

for required in \
  "docs/architecture/openclaw-artifact-classification.md" \
  "docs/architecture/discord-runtime-orchestrator.md" \
  "docs/architecture/discord-scoped-skills-registry.md" \
  "effective_context" \
  "effective_skills" \
  "effective_capabilities" \
  "provenance" \
  "reason" \
  "discord-approval-gate" \
  "available: true" \
  "permitted: false" \
  "content_policy: reference-only-no-private-content" \
  "exact_approval_phrase: approve write"; do
  grep -F "$required" "$FIXTURE_PATH" >/dev/null || fail "fixture missing resolver marker: $required"
done

for required in \
  "Discord effective runtime resolver" \
  "effective_context" \
  "effective_skills" \
  "effective_capabilities" \
  "Capability availability and permission are different decisions" \
  "Shared profile references remain shared" \
  "No raw Discord IDs"; do
  grep -F "$required" "$DOC_PATH" >/dev/null || fail "doc missing resolver marker: $required"
done

for required in \
  "effective_context" \
  "effective_capabilities" \
  "discord-approval-gate" \
  "provenance"; do
  grep -F "$required" "$SKILL_PATH" >/dev/null || fail "skill missing resolver output marker: $required"
done

python3 - "$FIXTURE_PATH" "$RUNTIME_NAMESPACE_CONTRACT" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text().splitlines()
runtime = sys.argv[2]
scenarios = []
current = None
section = None
for raw in text:
    if raw.startswith("  - name:"):
        if current:
            scenarios.append(current)
        current = {"name": raw.split(":", 1)[1].strip(), "sections": set(), "keys": []}
        section = None
        continue
    if not current:
        continue
    if raw.startswith("    ") and not raw.startswith("      ") and raw.rstrip().endswith(":"):
        section = raw.strip()[:-1]
        current["sections"].add(section)
    if raw.startswith("    ") and ":" in raw and not raw.rstrip().endswith(":"):
        key, value = raw.strip().split(":", 1)
        current["keys"].append((section, key, value.strip()))
if current:
    scenarios.append(current)

required_sections = {"artifact_classification", "effective_context", "effective_skills", "effective_capabilities", "write_safety"}
for sc in scenarios:
    missing = required_sections - sc["sections"]
    if missing:
        raise SystemExit(f"scenario {sc['name']} missing resolver sections: {sorted(missing)}")
    kv = sc["keys"]
    if (None, "runtime_namespace", runtime) not in kv and not any(k == "runtime_namespace" and v == runtime for _, k, v in kv):
        raise SystemExit(f"scenario {sc['name']} has wrong runtime namespace")
    for required_key in ["artifact_type", "operation", "persistence_target", "approval_required", "backup_required", "deployment_required", "runner_backend", "writeback_policy"]:
        if not any(section == "artifact_classification" and key == required_key for section, key, _ in kv):
            raise SystemExit(f"scenario {sc['name']} missing artifact field {required_key}")
    if any(key == "writeback_policy" and value == "confirmation-required" for _, key, value in kv):
        if not any(key == "required_skill" and value == "discord-approval-gate" for _, key, value in kv):
            raise SystemExit(f"scenario {sc['name']} write-like flow missing approval gate")
        if not any(key == "writes_attempted" and value == "false" for _, key, value in kv):
            raise SystemExit(f"scenario {sc['name']} must not attempt writes")

# Every resolved context/skill/capability item must carry provenance and reason.
resolver_sections = {"effective_context", "effective_skills", "effective_capabilities"}
current_section = None
current_item = None
items = []
for raw in text:
    stripped = raw.strip()
    if raw.startswith("    effective_") and stripped.endswith(":"):
        current_section = stripped[:-1]
        continue
    if raw.startswith("    ") and not raw.startswith("      ") and stripped.endswith(":") and not raw.startswith("    effective_"):
        if current_item:
            items.append(current_item)
            current_item = None
        current_section = None
        continue
    if current_section in resolver_sections and raw.startswith("        - "):
        if current_item:
            items.append(current_item)
        current_item = {"section": current_section, "keys": set()}
        body = stripped[2:]
        if ":" in body:
            current_item["keys"].add(body.split(":", 1)[0])
        continue
    if current_section in resolver_sections and current_item and raw.startswith("          ") and ":" in stripped:
        current_item["keys"].add(stripped.split(":", 1)[0])
if current_item:
    items.append(current_item)
for item in items:
    identity_keys = {"ref", "skill_name", "capability"}
    if item["keys"] & identity_keys:
        missing = {"provenance", "reason"} - item["keys"]
        if missing:
            raise SystemExit(f"{item['section']} item missing {sorted(missing)}")

fixture = "\n".join(text)
if fixture.count("ref: profile:writing.demo-linkedin-b2b") < 2:
    raise SystemExit("shared profile reference scenario must show reused ref")
if "reason: overridden-by-channel-binding" not in fixture:
    raise SystemExit("channel override scenario must include overridden category profile reason")
if "capability: filesystem" not in fixture or "permitted: false" not in fixture:
    raise SystemExit("capability scenario must distinguish available from permitted")
PY

review_paths=("$FIXTURE_PATH" "$DOC_PATH" "$SKILL_PATH")

if grep -E '\b[0-9]{17,20}\b' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not contain credential variable names"
fi

if grep -E 'live_discord_connection: true|live_engram_calls: true|live_prompt_execution: true|runtime_enforcement_proven: true|uses_real_discord_ids: true|private_profile_content_included: true|durable_memory_writes_allowed: true|workspace_file_writes_allowed: true|filesystem_access_enabled: true|browser_automation_enabled: true|publishing_enabled: true|scheduling_enabled: true|buffer_activity_enabled: true|production-ready|public Discord validation passed|live Discord validation passed|uses production credentials|production credentials enabled' "${review_paths[@]}" >/dev/null; then
  fail "artifacts must not claim live, production, private content, persistence, filesystem/browser, publishing, scheduling, or public Discord behavior"
fi

echo "Validated fake Discord effective runtime resolver contract."
echo "Fixture: $FIXTURE_PATH"
echo "Doc: $DOC_PATH"
echo "Skill: $SKILL_PATH"
echo "Runtime namespace contract: $RUNTIME_NAMESPACE_CONTRACT"
