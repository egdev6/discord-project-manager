# Private runtime backup and restore

This contract defines the fake-first backup/restore path for private OpenClaw runtime state managed from Discord.

It covers private profiles, scope bindings, overrides, disabled bindings, capability permission metadata, and durable audit records. It does not store real private profile content, raw Discord payloads, secrets, screenshots, logs, database dumps, or volume snapshots in the repository.

This is a contract and sanitized validation path only. It does not prove live Docker restore, live Engram writes, public Discord behavior, production credentials, publishing, scheduling, filesystem access, or connector activity.

## Quick path

1. Stop write-like runtime operations.
2. Export private runtime storage outside the repo.
3. Preserve profile definitions separately from scope bindings.
4. Preserve audit records with backup refs, snapshot refs, owner refs, restore command refs, and verification steps.
5. Restore only into a private rehearsal environment.
6. Compare sanitized effective resolution before and after restore.
7. Resume writes only after shared profile references, overrides, disabled bindings, and audit metadata match.

## Canonical private stores

| State | Canonical private store | Public repo rule |
| --- | --- | --- |
| Profile definitions | Engram/Postgres or explicit private OpenClaw workspace state | Never commit real content. Use refs only. |
| Scope bindings | Engram/Postgres or explicit private OpenClaw workspace state | Commit fake binding fixtures only. |
| Overrides and disabled bindings | Engram/Postgres or explicit private OpenClaw workspace state | Commit fake metadata only. |
| Capability permission/config | Private runtime config or secret store | Public docs may describe capability name and config state only. |
| Durable audit metadata | Runtime audit namespace and private backup/export | Commit sanitized audit records only. |
| Secrets and connector credentials | `.env` or secret manager | Never commit. |

Current Docker Compose private state lives in named volumes such as `engram-postgres` and `openclaw-home`; see `docs/security/data-handling.md#current-recovery-path`.

## Backup manifest shape

```yaml
backup_manifest:
  manifest_id: backup-demo-private-runtime
  source_runtime_namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
  created_by_ref: operator-demo
  storage_location: private-backup://demo/private-runtime-backup.tgz
  public_repo_storage_allowed: false
  includes:
    profile_definitions: true
    scope_bindings: true
    overrides: true
    disabled_bindings: true
    capability_permissions: true
    durable_audit_records: true
  integrity:
    sanitized_manifest_hash: sha256-demo-placeholder
    raw_export_committed: false
    manifest_only_in_repo: true
```

## Restore validation shape

```yaml
restore_rehearsal:
  restore_id: restore-demo-private-runtime
  backup_manifest_ref: backup-demo-private-runtime
  target_environment: private-rehearsal
  restore_command_ref: docs/security/data-handling.md#current-recovery-path
  owner_ref: operator-demo
  writes_enabled_during_restore: false
  verification_step: compare sanitized effective resolution before enabling writes
pre_restore_effective_resolution:
  ref: effective-resolution-before-restore
  included_context: []
  excluded_context: []
  capability_permissions: []
  audit_refs: []
post_restore_effective_resolution:
  ref: effective-resolution-after-restore
  included_context: []
  excluded_context: []
  capability_permissions: []
  audit_refs: []
restore_assertions:
  shared_profile_refs_preserved: true
  profile_bindings_preserved: true
  overrides_preserved: true
  disabled_bindings_preserved: true
  audit_metadata_preserved: true
  capability_permissions_preserved: true
  duplicate_profile_defs_created: false
  writes_enabled_after_restore: false
```

## Restore invariants

| Invariant | Required result |
| --- | --- |
| Shared profile reference | The same profile ref remains shared across scopes after restore. |
| Channel override | The overridden category binding remains excluded with provenance; channel override remains included. |
| Disabled binding | Disabled bindings remain disabled and explain why. |
| Audit metadata | Approval decision, backup ref, snapshot ref, restore command ref, owner ref, and verification step remain available. |
| Capability permission | Capability availability remains separate from scoped permission/config. |
| Write safety | Writes stay disabled until sanitized readback passes. |

## Sanitized validation

Use `examples/private-runtime-backup-restore.fake.yaml` and `scripts/validate-private-runtime-backup-restore.sh` to validate this contract without touching real runtime state.

Required local validation:

```bash
git diff --check
bash scripts/validate-private-runtime-backup-restore.sh
bash scripts/validate-discord-effective-runtime-resolver.sh
bash scripts/validate-discord-durable-change-audit.sh
bash scripts/validate-repo-safe-evidence.sh
```

## Non-goals

This contract does not:

- execute live backup or restore commands;
- commit private backups, SQL dumps, volume snapshots, or raw Engram exports;
- prove production RPO/RTO;
- enable live Discord writes;
- enable filesystem, browser, publishing, scheduling, or connector actions.

## Related docs

- `docs/security/data-handling.md`
- `docs/architecture/openclaw-artifact-classification.md`
- `docs/architecture/discord-effective-runtime-resolver.md`
- `docs/architecture/discord-durable-change-audit.md`
- `docs/architecture/discord-memory-gateway.md`
- `docs/operations/docker-runtime.md`
