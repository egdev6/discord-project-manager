# Discord durable change audit

This contract defines sanitized audit/provenance records for Discord-managed durable changes.

Durable changes include private runtime writes, repo-backed proposals, capability permission/config changes, external-service write proposals, and approval decisions. Audit records must explain what was proposed, who/what approved it, where it may persist, and how to restore or roll it back without storing raw Discord transcripts or private payloads.

This is a fake-first contract only. It does not prove live Discord routing, live Engram writes, GitHub mutations, filesystem access, browser automation, connector calls, publishing, scheduling, or production credentials.

## Quick path

1. Classify the requested artifact and effective runtime envelope.
2. Create an audit proposal before any durable write.
3. Route write-like changes through `discord-approval-gate`.
4. Record the approval decision as sanitized metadata.
5. Include audit metadata in private backup/export when the target is private runtime state.
6. Keep raw Discord messages, screenshots, IDs, secrets, and private payload dumps out of repo artifacts and audit records.

## Audit record schema

```yaml
audit_record:
  schema_version: 1
  audit_id: audit-demo-profile-create
  decision_state: approved
  actor_ref: operator-demo
  actor_role: maintainer-demo
  runtime_namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
  route:
    project_slug: egdev
    network_slug: linkedin
  target:
    artifact_type: private_context
    subtype: profile
    operation: create
    persistence_target: private-runtime
    target_ref: profile:writing.demo-linkedin-b2b
    target_namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
  approval:
    required: true
    gate: discord-approval-gate
    accepted_phrase: approve write
    decision: approve write
  provenance:
    source: discord-runtime-orchestrator
    classification_ref: examples/discord-runtime-orchestrator.fake.yaml#private-profile-create
    resolver_ref: examples/discord-effective-runtime-resolver.fake.yaml#shared-profile-category-resolution
    sanitized_input_summary: fake request to create a demo writing profile
  validation:
    command_ref: scripts/validate-discord-durable-change-audit.sh
    result: passed-demo
  rollback:
    restore_hint: restore previous private profile definition from private backup
    rollback_scope: private-runtime-profile
    backup_ref: private-backup://demo/engram-before-profile-create.sql
    pre_change_snapshot_ref: snapshot:profile-writing-demo-linkedin-b2b-before-create
    restore_command_ref: docs/security/data-handling.md#current-recovery-path
    verification_step: run sanitized profile readback before resuming writes
    owner_ref: operator-demo
  privacy:
    raw_transcript_stored: false
    raw_discord_ids_stored: false
    private_payload_stored: false
    safe_for_repo: true
```

## Required fields

| Field | Purpose |
| --- | --- |
| `audit_id` | Stable sanitized identifier for the audit event. |
| `decision_state` | `proposed`, `approved`, `revised`, `rejected`, or `failed-validation`. |
| `actor_ref` and `actor_role` | Sanitized operator reference and role; never raw Discord IDs. |
| `runtime_namespace` | Existing ADR 0002 runtime namespace. |
| `route` | Resolved project/network route or `none`. |
| `target` | Artifact classification and durable target reference. |
| `approval` | Gate, exact decision, and whether approval was required. |
| `provenance` | Runtime components and fixture/artifact refs that produced the proposal. |
| `validation` | Validation command/result or explicit reason validation was not applicable. |
| `rollback` | Restore/rollback hint, owner, backup/snapshot refs, restore command ref, and verification step appropriate to the persistence target. |
| `privacy` | Explicit booleans proving raw/private material was not stored. |

## Decision states

| State | Meaning | Durable write allowed? |
| --- | --- | --- |
| `proposed` | Proposal shown; waiting for exact approval/revision/rejection. | No |
| `approved` | Exact `approve write` accepted for the displayed target only. | Yes, only for displayed target |
| `revised` | Operator requested `revise: <instruction>`. | No; show revised proposal first |
| `rejected` | Operator rejected the proposal. | No |
| `failed-validation` | Validation failed after approval or during dry-run. | No additional write; report recovery path and restore/fix-forward verification step |

## Target coverage

| Durable change kind | Audit target | Backup/export rule |
| --- | --- | --- |
| Private profile create/update/bind/clone | `private_context` with profile or scope binding ref. | Include audit metadata in private runtime backup/export. |
| Repo-backed proposal | `repo` target path or GitHub metadata ref. | Keep audit summary in PR/issue; no private payload. |
| Capability permission/config change | `runtime_capability` with public capability name and private config state. | Include permission audit in private backup/export; never store secrets. |
| External-service write proposal | `publication_flow` or connector target ref. | Include sanitized decision and rollback hint; credentials stay in secret store. |
| Rejection/revision | Target from the proposal. | Record sanitized decision only; no durable payload write. |

## Privacy rules

Audit records must not contain:

- raw Discord transcripts;
- real Discord user, guild, channel, or message IDs;
- screenshots;
- tokens, credentials, OAuth/session material, or secret variable values;
- private writing profile content, brand strategy text, local sensitive paths, or connector payloads;
- raw Engram exports, SQL dumps, or volume snapshots.

Use sanitized refs such as `operator-demo`, `profile:writing.demo-linkedin-b2b`, and `discord-project-manager/runtime/discord/<guild-id>/<channel-id>` in repo fixtures.

## Related docs

- `docs/architecture/openclaw-artifact-classification.md`
- `docs/architecture/discord-effective-runtime-resolver.md`
- `docs/architecture/discord-memory-gateway.md`
- `docs/security/data-handling.md`
- `skills/discord-approval-gate/SKILL.md`

## Validation checklist

- [ ] Fixture covers proposed, approved, revised, rejected, and failed-validation decisions.
- [ ] Fixture covers private runtime, repo-backed proposal, capability permission, and approval decision audit records.
- [ ] Every write-like audit record references `discord-approval-gate` and exact `approve write` when approved.
- [ ] Private runtime audit records include backup refs, pre-change snapshot refs, restore command refs, owner refs, and verification steps.
- [ ] Records use sanitized actor/route/target refs only.
- [ ] No raw transcripts, real IDs, screenshots, tokens, private payloads, local sensitive paths, production claims, or live write claims are introduced.
