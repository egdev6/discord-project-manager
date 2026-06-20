# Discord admin UX

This contract defines a fake-first Discord admin UX for profiles, scope bindings, effective resolver inspection, scoped skills/capabilities, and backup/export requests.

This is a contract only. It does not prove live Discord command handling, live OpenClaw execution, live Engram calls, durable writes, private profile export, GitHub mutations, production credentials, publishing, or scheduling.

## Quick path

1. Receive an admin command or guided prompt in a managed/admin-capable channel.
2. Classify the admin action as read-only inspection, write-like preview, or backup/export request.
3. Resolve scope through managed channel routing and effective resolver contracts.
4. Return sanitized summary-only output or an approval-gated preview.
5. Keep `write_executed: false` until a future runtime implementation handles exact approval outside this contract.

## Contract dependencies

The admin UX depends on:

- `docs/architecture/discord-managed-channel-routing.md` for persisted semantic channel and scope resolution;
- `docs/architecture/discord-scoped-skills-registry.md` for effective skill resolution and scoped overrides;
- `docs/architecture/discord-effective-runtime-resolver.md` for effective context/skills/capabilities inspection;
- `docs/architecture/discord-runtime-orchestrator.md` for artifact classification and runner boundaries;
- `docs/architecture/discord-memory-gateway.md` for private runtime writeback boundaries;
- `skills/discord-approval-gate/SKILL.md` for exact `approve write` confirmation;
- `docs/operations/private-runtime-backup-restore.md` for backup/export request handling.

## Admin action families

| Family | Mode | Required behavior |
| --- | --- | --- |
| `list_profiles` | read-only | List sanitized profile refs and bindings only; never dump private profile content. |
| `list_scope_bindings` | read-only | Show sanitized global/category/channel binding refs and source scope. |
| `bind_profile_preview` | write-like preview | Propose binding an existing profile to a scope; require approval before persistence. |
| `clone_profile_preview` | write-like preview | Explain clone vs reference and propose clone metadata only; require approval. |
| `inspect_effective_runtime` | read-only | Use effective resolver output for context, skills, and capabilities. |
| `toggle_skill_or_capability_preview` | write-like preview | Propose enable/disable with target scope, impact summary, approval gate, and rollback note. |
| `backup_export_request` | request-routing | Link to backup/restore runbook; do not export data in Discord or repo artifacts. |

## Response schema

| Field | Purpose |
| --- | --- |
| `admin_state` | `summary-only`, `approval-requested`, or `clarification-needed`; backup/export requests use `approval-requested` without attaching exports. |
| `action_family` | One of the admin action families above. |
| `target_scope` | `global`, `category`, `channel`, or `project`. |
| `target_ref` | Sanitized fake target ref. |
| `resolver_source` | Contract used for route/effective-state resolution. |
| `preview_summary` | Sanitized operator-facing summary. |
| `approval_required` | Whether exact `approve write` is required. |
| `approval_skill` | `discord-approval-gate` for write-like flows. |
| `write_executed` | Always `false` in this slice. |
| `private_content_included` | Always `false` in public fixtures. |
| `backup_runbook_ref` | Required for backup/export request flows. |

## Safety rules

- Listing profiles or bindings returns refs and summaries only, never private profile body text.
- Write-like admin actions stop at `approval-requested` with `write_executed: false`.
- Effective runtime inspection must use resolver contracts, not ad hoc channel-name inference.
- Backup/export requests route to the backup/restore runbook and do not attach exports.
- Do not commit real Discord IDs, private profile content, screenshots, raw logs, transcripts, raw exports, SQL dumps, secrets, or private payloads.
- Do not claim live Discord behavior, durable writes, prompt execution, production readiness, publishing, or scheduling.

## Synthetic preview harness

The repo-safe synthetic preview harness is `docker/openclaw/discord-admin-ux-preview-harness.sh`, installed in the OpenClaw image as `discord-project-manager-admin-ux-preview-harness`. It emits sanitized summaries and approval-gated previews for the fixture families only. It does not read live Discord, Engram/private runtime, private profile bodies, exports, SQL dumps, screenshots, raw logs, transcripts, or credentials. Validate it with `scripts/validate-discord-admin-ux-preview-harness.sh`.

## Non-goals

This contract does not:

- implement live slash commands or buttons;
- execute profile binding, clone, skill, capability, backup, or export mutations;
- read or write live Engram/private runtime state;
- expose private profile content;
- replace the approval gate, memory gateway, or effective resolver contracts.

## Validation checklist

- [ ] Fixture covers read-only profile/binding listing and effective resolver inspection.
- [ ] Fixture covers profile bind, clone, and skill/capability toggle previews with approval gates.
- [ ] Fixture covers backup/export request routing without exporting data.
- [ ] Every public scenario has `private_content_included: false` and `write_executed: false`.
- [ ] No live/prod/mutation claims or real Discord identifiers are introduced.
