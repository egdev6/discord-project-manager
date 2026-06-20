#!/usr/bin/env sh
set -eu

RUNTIME_NAMESPACE="discord-project-manager/runtime/discord/<guild-id>/<channel-id>"
PROJECT_REF="project-demo-egdev"
CHANNEL_REF="channel-demo-egdev-linkedin-strategy"
BACKUP_RUNBOOK_REF="docs/operations/private-runtime-backup-restore.md"
ADMIN_CONTRACT_REF="docs/architecture/discord-admin-ux.md"
APPROVAL_SKILL="discord-approval-gate"
APPROVAL_PHRASE="approve write"

usage() {
  cat <<'USAGE'
Usage: discord-project-manager-admin-ux-preview-harness

Repo-safe synthetic admin UX preview harness.
It emits sanitized response-only admin summaries and approval-gated previews.
It does not read live Discord, Engram/private runtime, private profile bodies,
exports, SQL dumps, screenshots, raw logs, transcripts, or credentials.
USAGE
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
fi

cat <<EOF
admin_ux_preview_harness_result:
  evidence_mode: repo-safe-synthetic-admin-preview-only
  admin_contract_ref: $ADMIN_CONTRACT_REF
  runtime_namespace: $RUNTIME_NAMESPACE
  live_discord_connection: false
  live_openclaw_execution: false
  live_engram_calls: false
  live_prompt_execution: false
  durable_writes_enabled: false
  github_mutations_enabled: false
  private_profile_content_included: false
  raw_exports_included: false
  sql_dumps_included: false
  publishing_attempted: false
  scheduling_attempted: false
  network_calls_attempted: false
  filesystem_writes_attempted: false
  scenarios:
    - name: list-profiles-summary
      action_family: list_profiles
      target_scope: project
      target_ref: $PROJECT_REF
      admin_state: summary-only
      resolver_source: docs/architecture/discord-managed-channel-routing.md
      preview_summary: sanitized-profile-refs-and-binding-counts-only
      private_content_included: false
      approval_required: false
      write_executed: false
    - name: list-scope-bindings-summary
      action_family: list_scope_bindings
      target_scope: channel
      target_ref: $CHANNEL_REF
      admin_state: summary-only
      resolver_source: docs/architecture/discord-scoped-skills-registry.md
      preview_summary: sanitized-scope-bindings-with-source-scope-only
      private_content_included: false
      approval_required: false
      write_executed: false
    - name: bind-profile-preview
      action_family: bind_profile_preview
      target_scope: channel
      target_ref: $CHANNEL_REF
      admin_state: approval-requested
      resolver_source: docs/architecture/discord-memory-gateway.md
      preview_summary: bind-existing-profile-ref-to-channel-scope
      private_content_included: false
      approval_required: true
      approval_skill: $APPROVAL_SKILL
      exact_approval_phrase: $APPROVAL_PHRASE
      write_executed: false
    - name: clone-profile-preview
      action_family: clone_profile_preview
      target_scope: project
      target_ref: $PROJECT_REF
      admin_state: approval-requested
      resolver_source: docs/architecture/discord-memory-gateway.md
      preview_summary: clone-vs-reference-explained-without-profile-body
      private_content_included: false
      approval_required: true
      approval_skill: $APPROVAL_SKILL
      exact_approval_phrase: $APPROVAL_PHRASE
      write_executed: false
    - name: inspect-effective-runtime
      action_family: inspect_effective_runtime
      target_scope: channel
      target_ref: $CHANNEL_REF
      admin_state: summary-only
      resolver_source: docs/architecture/discord-effective-runtime-resolver.md
      preview_summary: effective-context-skills-capabilities-from-resolver-output
      private_content_included: false
      approval_required: false
      write_executed: false
    - name: disable-skill-preview
      action_family: toggle_skill_or_capability_preview
      target_scope: project
      target_ref: $PROJECT_REF
      admin_state: approval-requested
      resolver_source: docs/architecture/discord-scoped-skills-registry.md
      preview_summary: proposed-scoped-skill-disable-with-impact-summary
      private_content_included: false
      approval_required: true
      approval_skill: $APPROVAL_SKILL
      exact_approval_phrase: $APPROVAL_PHRASE
      write_executed: false
    - name: capability-toggle-preview
      action_family: toggle_skill_or_capability_preview
      target_scope: global
      target_ref: global-runtime-config
      admin_state: approval-requested
      resolver_source: docs/architecture/discord-runtime-orchestrator.md
      preview_summary: proposed-capability-disable-with-runtime-sync-note
      private_content_included: false
      approval_required: true
      approval_skill: $APPROVAL_SKILL
      exact_approval_phrase: $APPROVAL_PHRASE
      write_executed: false
    - name: backup-export-request
      action_family: backup_export_request
      target_scope: project
      target_ref: $PROJECT_REF
      admin_state: approval-requested
      resolver_source: $BACKUP_RUNBOOK_REF
      backup_runbook_ref: $BACKUP_RUNBOOK_REF
      preview_summary: route-to-private-backup-runbook-without-attaching-export
      private_content_included: false
      raw_exports_included: false
      sql_dumps_included: false
      approval_required: true
      approval_skill: $APPROVAL_SKILL
      exact_approval_phrase: $APPROVAL_PHRASE
      write_executed: false
EOF
