# OpenClaw artifact classification and persistence

This contract defines how OpenClaw classifies Discord-originated requests before selecting skills, runners, approval gates, persistence, backup behavior, or deployment actions.

The goal is simple: every Discord request must say what kind of artifact it is trying to affect, where that artifact may live, who governs it, and what approval is required before any durable write.

This is a contract only. It does not prove live Discord routing, live Engram writes, GitHub mutations, publishing, browser automation, filesystem actions, or production credential handling.

## Quick path

1. Classify the requested artifact before runner selection.
2. Assign one `persistence_target`.
3. Decide whether the request is read-only, proposal-only, or write-like.
4. Route write-like requests through `discord-approval-gate` before durable persistence.
5. Keep private/personal guidance out of public repo artifacts unless explicitly sanitized and promoted.

## Classification block

Every Discord-originated turn should produce a compact classification block before execution:

```yaml
artifact_type: private_context
subtype: profile
operation: create
persistence_target: private-runtime
approval_required: true
backup_required: true
deployment_required: false
runner_backend: openclaw-skill-surface
writeback_policy: confirmation-required
```

| Field | Required? | Purpose |
| --- | --- | --- |
| `artifact_type` | Yes | What kind of thing the user is asking to read, draft, create, update, or route. |
| `subtype` | When meaningful | Refinement such as `profile`, `scope_binding`, `skill_contract`, or `capability_config`. Use `none` or omit only when the artifact type has no useful subtype. |
| `operation` | Yes | `read`, `draft`, `create`, `update`, `bind`, `reference`, `unbind`, `clone`, `execute`, or `handoff`. |
| `persistence_target` | Yes | Where the durable result may live. |
| `approval_required` | Yes | Whether exact `approve write` is required before persistence. |
| `backup_required` | Yes | Whether the durable state must be covered by private backup/restore. |
| `deployment_required` | Yes | Whether image rebuild, runtime sync, or release promotion is expected. |
| `runner_backend` | Yes | Selected execution boundary such as `openclaw-skill-surface`, `gentle-sdd`, or `response-only`. |
| `writeback_policy` | Yes | Memory Gateway classification: `auto-save`, `confirmation-required`, `draft`, or `reject`. |

## Artifact types

| Artifact type | Meaning | Default persistence target | Owner | Default gate |
| --- | --- | --- | --- | --- |
| `workflow_skill` | Repo-backed skill contract or workflow skill source. | `repo` | Development workflow / GitHub review | `approval-requested` for writes |
| `private_context` | Private runtime context such as writing style, brand voice, audience, preferences, or reusable profiles. | `private-runtime` | OpenClaw runtime operator | `approval-requested` for writes |
| `runtime_capability` | Capability/plugin permission or config, for example filesystem, browser, connector, or image generation access. | `private-runtime` or `repo` depending on sensitivity | Runtime operator + repo review for public contracts | `approval-requested` |
| `publication_flow` | Queue, ledger, schedule, or connector-facing publication operation. | `external-service` or `private-runtime` | Runtime operator | `approval-requested` |
| `sdd_dev_work` | Development/spec work that should be handed to Gentle SDD as a backend. | `repo` proposal until applied | GitHub/OpenSpec review | `summary-only` until a write proposal exists |
| `ephemeral_draft` | Temporary answer, plan, or draft with no durable storage. | `ephemeral` | Current Discord turn | `summary-only` |

## Persistence targets

| Persistence target | Durable location | Approval and backup rule |
| --- | --- | --- |
| `repo` | `docs/`, `openspec/`, `skills/`, source code, or GitHub issue/PR metadata. | Requires normal issue/PR review. Private data must be sanitized before promotion. |
| `private-runtime` | Engram/Postgres, OpenClaw workspace volume, or another explicitly private runtime store. | Requires exact approval for writes and private backup/restore coverage. |
| `external-service` | Buffer, Discord, browser session, publishing platform, analytics provider, or future connector. | Requires approval plus connector-specific capability permission. Secrets stay outside git. |
| `ephemeral` | Current response/session only. | No durable write. Do not rely on it after the turn. |

## Private context profiles

A profile is reusable private runtime context, not a repo-backed skill.

Profile definitions and scope bindings are separate artifacts:

| Artifact | Example | Persistence | Rule |
| --- | --- | --- | --- |
| Profile definition | `writing.linkedin-b2b` | `private-runtime` | Stores private style or preference content. Never commit real profile content. |
| Scope binding | `category:linkedin -> writing.linkedin-b2b` | `private-runtime` | References a profile from global/category/channel scope. |
| Override | `channel:linkedin/experiments -> writing.x-short` | `private-runtime` | Must include provenance and reason. |
| Sanitized example | `writing.demo-b2b` | `repo` fixture/docs | Fake placeholders only. |

Example classification:

```yaml
artifact_type: private_context
subtype: profile
operation: bind
profile_ref: writing.linkedin-b2b
persistence_target: private-runtime
scope_bindings:
  - category:linkedin
  - category:x
approval_required: true
backup_required: true
deployment_required: false
runner_backend: openclaw-skill-surface
writeback_policy: confirmation-required
```

Clone and reference are different operations:

- `bind` or `reference` keeps one shared profile definition across scopes.
- `clone` creates a new profile definition and should record why the copy must diverge.
- Restore validation must preserve shared references instead of silently duplicating profiles.

## Example classifications

| User request shape | Artifact type | Operation | Persistence target | Runner/backend | Writeback policy |
| --- | --- | --- | --- | --- | --- |
| “Remember this as my LinkedIn writing style.” | `private_context/profile` | `create` | `private-runtime` | `openclaw-skill-surface` | `confirmation-required` |
| “Use the same writing profile for LinkedIn and X.” | `private_context/scope_binding` | `bind` | `private-runtime` | `openclaw-skill-surface` | `confirmation-required` |
| “Add a safe local filesystem capability for content drafts.” | `runtime_capability/capability_config` | `draft` or `update` | `repo` contract plus private config | `gentle-sdd` or `openclaw-skill-surface` | `draft` or `confirmation-required` |
| “Create a publication flow for Buffer.” | `publication_flow/connector_flow` | `create` | `repo` contract plus `external-service` config | `openclaw-skill-surface` | `confirmation-required` |
| “Build a new OpenClaw skill for weekly LinkedIn planning.” | `sdd_dev_work/workflow_skill` | `handoff` | `repo` proposal | `gentle-sdd` | `draft` until write proposal |
| “Draft three post ideas.” | `ephemeral_draft/none` | `draft` | `ephemeral` | `openclaw-skill-surface` | `draft` |

The table is a summary. Executable fixtures and runtime metadata must still include the full classification block: `artifact_type`, `operation`, `persistence_target`, `approval_required`, `backup_required`, `deployment_required`, `runner_backend`, and `writeback_policy`.

## Approval, backup, and deployment implications

| Condition | Required behavior |
| --- | --- |
| Durable private runtime write | Use `discord-approval-gate`; include audit metadata; include in backup/export coverage. |
| Repo-backed artifact proposal | Use issue/PR review and shared-artifact serialization for multi-agent writes. |
| Capability permission/config change | Separate public contract from private config/secrets; require approval before enablement. |
| External connector action | Require connector capability permission and keep credentials outside git. |
| Docker rebuild or runtime sync required | Document the sync/rebuild step and expected validated runtime version. |
| Ephemeral draft | Do not persist unless the user explicitly requests a durable write and approves it. |

## Related contracts

- `docs/security/data-handling.md`
- `docs/architecture/public-private-boundaries.md`
- `docs/architecture/discord-runtime-orchestrator.md`
- `docs/architecture/discord-memory-gateway.md`
- `docs/architecture/discord-scoped-skills-registry.md`
- `docs/architecture/discord-gentle-sdd-handoff.md`
- `docs/adr/0001-runtime-boundary.md`
- `docs/adr/0002-engram-namespace-contract.md`

## Validation checklist

- [ ] Every fixture scenario includes `artifact_type`, `operation`, `persistence_target`, `approval_required`, `backup_required`, `deployment_required`, `runner_backend`, and `writeback_policy`.
- [ ] Write-like classifications include `approval_required: true` unless explicitly documented otherwise.
- [ ] Private profile scenarios keep real profile content out of repo fixtures.
- [ ] Runtime capability scenarios distinguish public contract from private config/secrets.
- [ ] SDD development work routes to `backend: gentle-sdd` without making Gentle the Discord-facing authority.
- [ ] Ephemeral drafts have no durable writeback.
