# Discord routing runbook

Use this runbook when configuring or reviewing Discord channels for the OpenClaw runtime.

> **Legacy/fallback status:** This runbook documents the older channel-first `<network-slug>-<project-slug>` transport baseline. It is not the current #132 manual rehearsal path. For current Project Manager rehearsal, use managed global/project scaffolding and persisted semantic metadata/IDs.

This is an operations contract only. It does not prove live Discord bot routing yet.

For pilot sequencing after #70-#74, use `docs/operations/discord-context-skill-pilot-roadmap.md`. The channel-first routing rules here remain a transport baseline/fallback, not the target workflow model.

## Quick path

1. Use `docs/operations/private-discord-manual-verification-guide.md` to prepare the private topology, channel roles, and sanitized evidence plan.
2. Use `docs/architecture/openclaw-global-channel-guides.md` and `examples/openclaw-global-channel-guides.fake.yaml` as the canonical source for reserved `OpenClaw Global` control-channel topics and starter guidance.
3. Use `docs/architecture/discord-semantic-channel-guides.md` and `examples/discord-semantic-channel-guides.fake.yaml` as the canonical source for managed Project Manager channel topics and starter/pinned prompts.
4. Use `docs/architecture/discord-project-manager-global-init.md` and `examples/discord-project-manager-global-init.fake.yaml` when reviewing the fake `/project-manager init` global category setup contract.
5. Use `docs/architecture/discord-project-manager-project-create.md` and `examples/discord-project-manager-project-create.fake.yaml` when reviewing the fake `/project create` per-project category setup contract.
6. Use `docs/architecture/discord-project-manager-project-delete.md` and `examples/discord-project-manager-project-delete.fake.yaml` when reviewing the fake `/project delete` preview/tombstone contract.
7. Use `docs/architecture/discord-channel-scaffolding-status-repair.md` and `examples/discord-channel-scaffolding-status-repair.fake.yaml` when reviewing fake status and repair previews for missing, renamed, or unmanaged managed scaffolding.
8. Use `docs/architecture/discord-managed-channel-routing.md` and `examples/discord-managed-channel-routing.fake.yaml` when reviewing persisted semantic metadata routing for managed Project Manager channels.
9. Install the external OpenClaw Discord plugin before live validation.
10. For current Project Manager flows, resolve managed channels from persisted semantic metadata/IDs.
11. Use `<network-slug>-<project-slug>` only when explicitly validating the legacy fallback route.
12. Keep real guild and channel IDs outside the repo.
13. Route channel-local memory by raw Discord IDs.
14. Route durable project reads by approved project/network slugs.
15. Ask for human approval before durable project writes.
16. Load `skills/discord-approval-gate/SKILL.md` for Discord write-like intents before any persistence.
17. Use `docs/operations/discord-approval-responses.md` for approval prompts and audit trail requirements.
18. Use `docs/architecture/channel-context-namespace-mapping.md` and `examples/discord-channel-context.fake.yaml` as the resolver reference and fake fixture.
19. Use `docs/architecture/discord-topology-reconciliation.md` and `examples/discord-topology-reconciliation.fake.yaml` when validating category/channel discovery before provisioning.
20. Use `docs/architecture/discord-context-namespace-provisioning.md` and `examples/discord-context-provisioning.fake.yaml` when reviewing approved draft context artifacts.

## Naming examples

| Channel name | Reads durable context from |
|---|---|
| `linkedin-egdev` | `discord-project-manager/project/egdev/network/linkedin` |
| `x-egdev` | `discord-project-manager/project/egdev/network/x` |
| `youtube-egdev` | `discord-project-manager/project/egdev/network/youtube` |
| `twitch-egdev` | `discord-project-manager/project/egdev/network/twitch` |
| `stack-and-flow-egdev` | `discord-project-manager/project/egdev/network/stack-and-flow` |

All of these may also read shared project context:

```text
discord-project-manager/project/egdev/brand
discord-project-manager/project/egdev/strategy
discord-project-manager/project/egdev/content-ledger
```

The canonical resolver contract lives in `docs/architecture/channel-context-namespace-mapping.md`, and `examples/discord-channel-context.fake.yaml` provides fake matched/unmapped fixtures. For reserved `OpenClaw Global` control-channel copy, use `docs/architecture/openclaw-global-channel-guides.md` and `examples/openclaw-global-channel-guides.fake.yaml`; validate with `bash scripts/validate-openclaw-global-channel-guides.sh`. For managed global/project scaffolding copy, use `docs/architecture/discord-semantic-channel-guides.md` and `examples/discord-semantic-channel-guides.fake.yaml` instead of duplicating topics or starter prompts in handlers. For global Project Manager initialization, use `docs/architecture/discord-project-manager-global-init.md` and `examples/discord-project-manager-global-init.fake.yaml` as the fake-first command/topology contract. For per-project category creation, use `docs/architecture/discord-project-manager-project-create.md` and `examples/discord-project-manager-project-create.fake.yaml` as the fake-first project creation contract. For safe project deletion, use `docs/architecture/discord-project-manager-project-delete.md` and `examples/discord-project-manager-project-delete.fake.yaml`; validate with `bash scripts/validate-discord-project-manager-project-delete.sh`. For status and repair previews over managed scaffolding drift, use `docs/architecture/discord-channel-scaffolding-status-repair.md` and `examples/discord-channel-scaffolding-status-repair.fake.yaml` before proposing any recreate or metadata refresh. For managed channel prompt routing, use `docs/architecture/discord-managed-channel-routing.md` and `examples/discord-managed-channel-routing.fake.yaml` so scope/field decisions come from persisted semantic metadata, not channel names.

## Runtime prerequisite

Live Discord validation requires the external OpenClaw Discord plugin. If `docker compose exec openclaw openclaw config get plugins.entries.discord` reports `plugin not installed: discord`, install it before debugging bot tokens, guild IDs, or channel names:

```bash
docker compose exec openclaw openclaw plugins install @openclaw/discord
docker compose restart openclaw
```

A valid `channels.discord` config without this plugin leaves the bot offline and produces no useful Discord route validation.

## Routing checklist

For each Discord message:

- [ ] Capture runtime guild ID and channel ID from the event.
- [ ] Build runtime namespace as `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`.
- [ ] If the channel is managed by Project Manager, resolve scope, field, project, and allowed operations from persisted semantic metadata; do not infer from the display name.
- [ ] If the channel is not managed by Project Manager, normalize the display name only for the legacy `<network-slug>-<project-slug>` fallback route.
- [ ] If matched by metadata or fallback route, read only the relevant durable context for that boundary.
- [ ] If unmatched, stay in runtime-only fallback mode.
- [ ] Require human approval before durable project memory, global governance, skills registry, or ledger writes.

## Unknown channel behavior

Unknown channels are safe by default:

- use response-only fallback unless the runtime provides explicitly non-durable scratch state;
- do not read project brand, strategy, ledger, or network memory;
- do not write durable project memory or workspace files;
- ask the operator to select or create an approved route;
- keep temporary notes out of persistent channel-local runtime memory until a route and write are approved.

Example response shape:

```text
I cannot map this channel to a project/network yet.
Current runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Choose an approved route before I read or write durable project memory.
```

## Approval boundary

Routing can select context. It cannot approve actions.

Still require explicit human approval before:

- writing project strategy memory;
- writing network-local planning memory;
- writing content-ledger entries;
- drafting final public copy;
- publishing or scheduling content.

Use `docs/operations/discord-approval-responses.md` for the response states, approval prompt shape, and runtime audit trail fields.

## Local validation

For this documentation-only routing slice, validate with:

```bash
git diff --check
npx --yes yaml-lint examples/discord-channel-scaffolding-status-repair.fake.yaml examples/discord-managed-channel-routing.fake.yaml examples/discord-project-manager-project-create.fake.yaml examples/discord-project-manager-project-delete.fake.yaml examples/discord-project-manager-global-init.fake.yaml examples/discord-semantic-channel-guides.fake.yaml examples/openclaw-global-channel-guides.fake.yaml examples/discord-channel-context.fake.yaml examples/discord-topology-reconciliation.fake.yaml examples/discord-context-provisioning.fake.yaml examples/discord-approval-gate.fake.yaml examples/discord-runtime-orchestrator.fake.yaml examples/discord-effective-runtime-resolver.fake.yaml examples/discord-durable-change-audit.fake.yaml examples/discord-gentle-sdd-handoff.fake.yaml examples/openclaw-global-brand-context-refresh.fake.yaml examples/content-ledger-utility-flow.fake.yaml examples/category-strategy-planning-flow.fake.yaml examples/linkedin-weekly-planning-flow.fake.yaml examples/on-demand-brief-flow.fake.yaml
bash scripts/validate-discord-channel-scaffolding-status-repair.sh
bash scripts/validate-discord-managed-channel-routing.sh
bash scripts/validate-discord-project-manager-project-create.sh
bash scripts/validate-discord-project-manager-project-delete.sh
bash scripts/validate-discord-project-manager-global-init.sh
bash scripts/validate-discord-semantic-channel-guides.sh
bash scripts/validate-openclaw-global-channel-guides.sh
bash scripts/validate-discord-topology-reconciliation.sh
bash scripts/validate-discord-context-provisioning.sh
bash scripts/validate-discord-approval-gate.sh
bash scripts/validate-discord-runtime-orchestrator.sh
bash scripts/validate-discord-effective-runtime-resolver.sh
bash scripts/validate-discord-durable-change-audit.sh
bash scripts/validate-discord-gentle-sdd-handoff.sh
bash scripts/validate-openclaw-global-brand-context-refresh.sh
bash scripts/validate-content-ledger-utility-flow.sh
bash scripts/validate-category-strategy-planning-flow.sh
bash scripts/validate-linkedin-weekly-planning-flow.sh
bash scripts/validate-on-demand-brief-flow.sh
npx --yes markdownlint-cli2@0.18.1 "**/*.md"
```

Live validation belongs to a later Discord/OpenClaw runtime issue.
