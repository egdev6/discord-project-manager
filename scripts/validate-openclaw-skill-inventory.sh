#!/usr/bin/env bash
set -euo pipefail

INVENTORY_PATH="openclaw/config/skill-inventory.yaml"
SYNC_SCRIPT_PATH="docker/openclaw/sync-skills.sh"
RUNTIME_DOC_PATH="docs/operations/docker-runtime.md"
ORCHESTRATOR_DOC_PATH="docs/architecture/discord-runtime-orchestrator.md"
SCOPED_DOC_PATH="docs/architecture/discord-scoped-skills-registry.md"
PACKS_DOC_PATH="docs/architecture/discord-context-skill-packs.md"
CONFIG_README_PATH="openclaw/config/README.md"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "missing file: $1"
}

require_file "$INVENTORY_PATH"
require_file "$SYNC_SCRIPT_PATH"
require_file "$RUNTIME_DOC_PATH"
require_file "$ORCHESTRATOR_DOC_PATH"
require_file "$SCOPED_DOC_PATH"
require_file "$PACKS_DOC_PATH"
require_file "$CONFIG_README_PATH"

expected_skills=(
  openclaw-runtime-orchestrator
  scoped-skill-resolver
  discord-approval-gate
  discord-general-advisor
  brand-context
  content-ledger
  strategy-planner
  linkedin-weekly-planner
  x-queue-planner
  on-demand-brief-planner
)

for skill in "${expected_skills[@]}"; do
  require_file "skills/${skill}/SKILL.md"
  grep -F "  - ${skill}" "$INVENTORY_PATH" >/dev/null || fail "inventory active list missing ${skill}"
  grep -F "${skill}" "$SYNC_SCRIPT_PATH" >/dev/null || fail "sync fallback list missing ${skill}"
done

for required in \
  "contract: openclaw-skill-inventory" \
  "runtime-core:" \
  "scoped-workflow:" \
  "preserved-protocol-assets:" \
  "gentle-ai-openclaw-sdd-assets: preserve" \
  "approval_gate_required_for_write_like_flows: discord-approval-gate" \
  "behavior: copy-only-active-openclaw-skills-and-prune-managed-stale-skills"; do
  grep -F "$required" "$INVENTORY_PATH" >/dev/null || fail "inventory missing marker: $required"
done

for required in \
  "inventory_path" \
  "active_openclaw_skills" \
  "sync_project_skills" \
  "target_skill_dir" \
  "Configured OpenClaw skill missing from source"; do
  grep -F "$required" "$SYNC_SCRIPT_PATH" >/dev/null || fail "sync script missing marker: $required"
done

for required in \
  "openclaw-runtime-orchestrator" \
  "scoped-skill-resolver" \
  "discord-general-advisor" \
  "runtime-core" \
  "scoped workflow" \
  "Gentle-AI SDD assets"; do
  grep -F "$required" "$RUNTIME_DOC_PATH" >/dev/null || fail "runtime docs missing skill inventory marker: $required"
done

for required in \
  "skills/openclaw-runtime-orchestrator/SKILL.md" \
  "skills/scoped-skill-resolver/SKILL.md" \
  "skills/discord-general-advisor/SKILL.md"; do
  grep -F "$required" "$ORCHESTRATOR_DOC_PATH" >/dev/null || fail "orchestrator doc missing new core skill reference: $required"
done

for required in \
  "openclaw-runtime-orchestrator" \
  "scoped-skill-resolver" \
  "migrate-behind-scoped-resolution" \
  "Gentle-AI SDD assets"; do
  grep -F "$required" "$SCOPED_DOC_PATH" >/dev/null || fail "scoped registry doc missing inventory/classification marker: $required"
done

grep -F "openclaw/config/skill-inventory.yaml" "$PACKS_DOC_PATH" >/dev/null || fail "packs doc missing inventory reference"
grep -F "openclaw/config/skill-inventory.yaml" "$CONFIG_README_PATH" >/dev/null || fail "config README missing inventory reference"

if grep -E '\b[0-9]{17,20}\b' "$INVENTORY_PATH" skills/openclaw-runtime-orchestrator/SKILL.md skills/scoped-skill-resolver/SKILL.md skills/discord-general-advisor/SKILL.md >/dev/null; then
  fail "skill inventory artifacts must not expose raw Discord snowflake-like IDs"
fi

if grep -E 'BUFFER_[A-Z0-9_]+|DISCORD_[A-Z0-9_]+|OPENAI_[A-Z0-9_]+|ANTHROPIC_[A-Z0-9_]+|GITHUB_TOKEN|ENGRAM_[A-Z0-9_]+' "$INVENTORY_PATH" skills/openclaw-runtime-orchestrator/SKILL.md skills/scoped-skill-resolver/SKILL.md skills/discord-general-advisor/SKILL.md >/dev/null; then
  fail "skill inventory artifacts must not contain credential variable names"
fi

echo "Validated OpenClaw skill inventory and curated sync contract."
echo "Inventory: $INVENTORY_PATH"
echo "Active skills: ${expected_skills[*]}"
