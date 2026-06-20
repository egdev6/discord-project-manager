#!/usr/bin/env sh
set -eu

workspace="${OPENCLAW_WORKSPACE:-/home/node/.openclaw/workspace}"
source_dir="${DISCORD_PROJECT_MANAGER_SKILLS_SOURCE:-/opt/discord-project-manager/skills}"
inventory_path="${DISCORD_PROJECT_MANAGER_SKILL_INVENTORY:-/opt/discord-project-manager/openclaw-config/skill-inventory.yaml}"
target_dir="$workspace/skills"
gentle_enabled="${DISCORD_PROJECT_MANAGER_SYNC_GENTLE_AI:-1}"

mkdir -p "$target_dir"

managed_skill_names() {
  if [ -f "$inventory_path" ]; then
    awk '
      /^active_openclaw_skills:/ { in_list = 1; next }
      in_list && /^[^[:space:]-]/ { in_list = 0 }
      in_list && /^[[:space:]]*-[[:space:]]*[a-z0-9-]+[[:space:]]*$/ {
        value = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        print value
      }
    ' "$inventory_path"
    return 0
  fi

  printf '%s\n' \
    openclaw-runtime-orchestrator \
    scoped-skill-resolver \
    discord-approval-gate \
    discord-general-advisor \
    brand-context \
    content-ledger \
    strategy-planner \
    linkedin-weekly-planner \
    x-queue-planner \
    on-demand-brief-planner
}

sync_project_skills() {
  [ -d "$source_dir" ] || return 0

  for target_skill_dir in "$target_dir"/*; do
    [ -d "$target_skill_dir" ] || continue
    target_skill_name="$(basename "$target_skill_dir")"
    if ! managed_skill_names | grep -Fx "$target_skill_name" >/dev/null 2>&1; then
      rm -rf "${target_skill_dir:?}"
    fi
  done

  managed_skill_names | while IFS= read -r skill_name; do
    [ -n "$skill_name" ] || continue
    rm -rf "${target_dir:?}/$skill_name"

    if [ ! -f "$source_dir/$skill_name/SKILL.md" ]; then
      echo "Configured OpenClaw skill missing from source: $skill_name" >&2
      return 1
    fi

    mkdir -p "$target_dir/$skill_name"
    cp -R "$source_dir/$skill_name"/. "$target_dir/$skill_name"/
  done
}

sync_project_skills

has_gentle_openclaw_core() {
  [ -f "$workspace/AGENTS.md" ] || return 1
  [ -f "$workspace/SOUL.md" ] || return 1
  [ -f "$workspace/.openclaw/skills/sdd-init/SKILL.md" ] || return 1
  grep -F 'gentle-ai:sdd-orchestrator' "$workspace/AGENTS.md" >/dev/null 2>&1 || return 1
  grep -F 'gentle-ai:engram-protocol' "$workspace/AGENTS.md" >/dev/null 2>&1 || return 1
  return 0
}

sync_gentle_ai_openclaw() {
  [ "$gentle_enabled" = "1" ] || return 0
  command -v gentle-ai >/dev/null 2>&1 || {
    echo "gentle-ai binary not found; skipping OpenClaw SDD sync" >&2
    return 0
  }
  [ -f /home/node/.openclaw/openclaw.json ] || {
    echo "OpenClaw config not found yet; skipping Gentle-AI OpenClaw sync" >&2
    return 0
  }

  if has_gentle_openclaw_core; then
    return 0
  fi

  echo "Syncing Gentle-AI SDD/Engram protocol into OpenClaw workspace..." >&2
  if ! gentle-ai install --agent openclaw --preset full-gentleman --scope=workspace >/tmp/gentle-ai-openclaw-sync.log 2>&1; then
    echo "gentle-ai install reported verification warnings; checking required OpenClaw files" >&2
  fi

  if ! has_gentle_openclaw_core; then
    echo "Gentle-AI OpenClaw sync did not produce required SDD/Engram files" >&2
    tail -120 /tmp/gentle-ai-openclaw-sync.log >&2 || true
    return 1
  fi
}

sync_gentle_ai_openclaw
