# Discord Gentle SDD handoff

This contract defines a fake-first handoff from OpenClaw Runtime Orchestrator to Gentle SDD for `sdd_dev_work`. It makes the handoff envelope, return envelope, writeback proposals, and shared-artifact claims reviewable before any live Discord/OpenClaw handoff, prompt execution, SDD execution, GitHub mutation, or durable write happens.

## Quick path

1. OpenClaw resolves origin, route, context, skills, and intent.
2. OpenClaw sends Gentle a bounded handoff envelope for `sdd_dev_work`.
3. Gentle returns reviewable summaries, artifact proposals, and writeback proposals.
4. OpenClaw routes any write-like proposal back through Memory Gateway policy plus `discord-approval-gate`.

## Contract dependencies

This handoff depends on:

- `docs/architecture/discord-runtime-orchestrator.md` for `backend: gentle-sdd` selection;
- `docs/architecture/discord-context-skill-packs.md` for resolved Context Pack and Skill Pack inputs;
- `docs/architecture/discord-memory-gateway.md` for writeback proposals and approval states;
- `docs/adr/0001-runtime-boundary.md` for the boundary that keeps Gentle SDD as an adaptation target/backend, not the primary Discord runtime;
- `docs/process/shared-artifact-serialization.md` for single-writer claim/release on repo artifacts;
- `docs/adr/0002-engram-namespace-contract.md` for existing runtime and durable namespace families;
- `skills/discord-approval-gate/SKILL.md` for exact `approve write` confirmation behavior.

## Input handoff envelope

Gentle receives resolved context and skills from OpenClaw. It must not query Discord directly or resolve Discord topology by itself.

| Field | Purpose |
| --- | --- |
| `runtime_namespace` | `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`. |
| `routing_status` and `resolved_route` | Approved route outcome from OpenClaw. |
| `intent_family` | `sdd_dev_work` in this slice. |
| `context_pack_ref` or sanitized snapshot | Reviewable context input from `docs/architecture/discord-context-skill-packs.md`. |
| `skill_pack_ref` or sanitized snapshot | Reviewable skill input with `discord-approval-gate` included. |
| `mandatory_skills` | Required safety skills for the turn. |
| `requested_sdd_mode` | Bounded requested mode or phase, not live execution. |
| `development_intent` | Optional narrowed intent such as `openclaw_skill_development` for repo-backed OpenClaw skill work. |
| `target_artifact_paths[]` | Optional proposed repo paths such as `skills/{name}/SKILL.md`, still proposal-only. |
| `execution_mode` | `delegated-contract-only` in this slice. |
| `approval_policy` | Whether a returned proposal needs `approve write`. |

## Return envelope

Gentle returns reviewable outputs only.

| Field | Purpose |
| --- | --- |
| `execution_state` | `contract-only` or `none`. |
| `prompt_execution` | Always `none` in this slice. |
| `turn_summary` | Bounded summary for the current handoff result. |
| `decisions` | Reviewable architecture or workflow decisions. |
| `tasks` | Next concrete work items when applicable. |
| `artifact_proposals[]` | Optional repo-artifact proposals with no write executed. |
| `writeback_proposals[]` | Optional Memory Gateway proposals with target namespace and topic key. |
| `shared_artifact_claims[]` | Optional claim/release metadata when repo artifacts or issue metadata are proposed. |
| `validation_evidence[]` | Commands or checks Gentle expects the owning repo session to run before enabling the proposal. |
| `runtime_sync_requirements[]` | Whether Docker rebuild, skill sync, restart, or release promotion is required after approval and merge. |

## Writeback target scopes

Reuse existing ADR 0002 namespace families plus Memory Gateway topic keys. Do not invent a new namespace family for this handoff.

| Proposal scope | Durable target | Topic key | Approval rule |
| --- | --- | --- | --- |
| `global` | Existing project namespace such as `discord-project-manager/project/<project-slug>/brand` or `.../strategy` | `discord/writeback/global-governance` | Global governance, identity, or style proposals require confirmation unless explicitly authorized. |
| `category` | Existing project namespace such as `discord-project-manager/project/<project-slug>/network/<network-slug>` | `discord/writeback/network-update` | Reviewable only; no persistence before gateway approval. |
| `channel` | Runtime audit or bounded local proposal tied to the resolved route | `discord/audit/approval-decision` or approved writeback topic key | No durable write outside Memory Gateway policy. |

All write-like outcomes return through `docs/architecture/discord-memory-gateway.md` and `skills/discord-approval-gate/SKILL.md` before persistence.

## Shared-artifact claims

If Gentle proposes repo artifacts such as `openspec/`, `docs/`, `skills/`, or GitHub issue metadata, the proposal must include:

- exact target paths or target identifiers for non-file metadata;
- `docs/process/shared-artifact-serialization.md` as the serialization contract reference;
- `claim_required: true` and `release_required: true`;
- `single_writer: true`;
- `write_executed: false` until the owning session claims and applies the change.

For OpenClaw skill development, product capability skills must target `skills/{name}/SKILL.md` as repo-backed artifacts and must report whether `openclaw/config/skill-inventory.yaml`, scoped-skill registry docs/fixtures, Docker image rebuild, skill sync, or runtime restart are required.

## Non-goals

This contract does not:

- implement live Discord/OpenClaw handoff;
- execute prompts or Gentle SDD phases;
- perform GitHub mutations;
- perform live Engram calls;
- bypass `discord-approval-gate` or shared-artifact serialization;
- prove public Discord behavior, production credentials, Buffer activity, publishing, or scheduling.

## Validation checklist

- [ ] Handoff envelope includes runtime namespace, route, pack refs, and `sdd_dev_work`.
- [ ] Gentle receives resolved context/skills and does not query Discord directly.
- [ ] Return envelope includes summary, artifact proposals, and writeback proposals.
- [ ] Global governance proposals stay `approval-requested` until exact `approve write`.
- [ ] OpenClaw skill-development handoffs use `development_intent: openclaw_skill_development` and proposal-only `skills/{name}/SKILL.md` targets.
- [ ] Repo-artifact proposals include claim/release metadata and `single_writer: true`.
- [ ] Prompt execution remains `none`.
- [ ] No raw Discord IDs, credential env names, live/prod claims, or GitHub mutation claims are introduced.
