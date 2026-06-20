# Discord Context and Skill Packs

This contract defines fake-first Context Pack and Skill Pack schemas for Discord prompt preparation. It makes prepared context, resolved skills, provenance, and truncation behavior reviewable before any live pack generation or runtime prompt execution happens.

This is a contract only. It does not prove live pack generation, live Engram calls, live Discord/runtime enforcement, public Discord behavior, production credentials, Buffer activity, publishing, or scheduling.

## Quick path

1. Start from the runtime namespace, route resolution, managed channel metadata, and Memory Gateway hydration rules.
2. Resolve managed Project Manager channels through `docs/architecture/discord-managed-channel-routing.md` when persisted semantic metadata exists.
3. Resolve one semantic channel guide ref from `docs/architecture/discord-semantic-channel-guides.md` for the current `scope` + `field_key`.
4. Build one bounded Context Pack and one bounded Skill Pack for the current turn.
5. Record why each context item or skill was included, excluded, or truncated.
6. Keep writeback proposals outside the packs and return them through Memory Gateway policy plus `discord-approval-gate`.

## Pack inputs

| Input | Source |
| --- | --- |
| `runtime_namespace` | `discord-project-manager/runtime/discord/<guild-id>/<channel-id>` from `docs/architecture/channel-context-namespace-mapping.md` |
| `routing_status` and `resolved_route` | Route outcome from `docs/architecture/channel-context-namespace-mapping.md` |
| `managed_channel_route_ref` | Persisted semantic metadata routing from `docs/architecture/discord-managed-channel-routing.md`, `examples/discord-managed-channel-routing.fake.yaml`, and `scripts/validate-discord-managed-channel-routing.sh` when the channel is bot-managed |
| `channel_guide_ref` | Canonical semantic channel guide lookup from `docs/architecture/discord-semantic-channel-guides.md` |
| `hydrated_context` | Bounded context prepared under `docs/architecture/discord-memory-gateway.md` |
| `effective_skills` | Scoped skills resolved under `docs/architecture/discord-scoped-skills-registry.md` and constrained by `openclaw/config/skill-inventory.yaml` |
| `mandatory_skills` | Global required skills such as `discord-approval-gate` |
| `intent_classification` | Read-only or write-like intent that affects exclusions and downstream runner behavior |

## Context Pack schema

Use the Context Pack to describe only the context prepared for the current turn.

| Field | Purpose |
| --- | --- |
| `pack_kind: context-pack` | Distinguishes the pack type explicitly. |
| `runtime_namespace` | Keeps the pack tied to the Discord runtime turn. |
| `routing_status` | Shows whether the pack came from a matched route or fallback mode. |
| `resolved_route` | Names the approved project/network route or `none`. |
| `provenance` | Lists source contracts, generation mode, and why this pack is safe for repo review. |
| `size_policy` | Defines bounded item counts, char limits, and truncation behavior. |
| `entries` | Ordered context items with scope, source, inclusion reason, exclusion reason, summary, and truncation flag. |

Required context scopes for this slice are:

- `runtime`
- `global`
- `category`
- `channel`
- `thread-session`
- `scoped-skill-context`

The pack may include only the scopes allowed by the route and Memory Gateway hydration policy.

## Skill Pack schema

Use the Skill Pack to describe only the skills prepared for the current turn.

| Field | Purpose |
| --- | --- |
| `pack_kind: skill-pack` | Distinguishes the pack type explicitly. |
| `runtime_namespace` | Keeps the pack tied to the same Discord runtime turn. |
| `provenance` | Shows which contracts and scope rules produced the pack. |
| `mandatory_skills` | Lists skills that must always be present, such as `discord-approval-gate`. |
| `effective_skills` | Ordered active skills with source scope, inclusion reason, and disabled flag. |
| `excluded_skills` | Explicitly lists disabled or overridden skills with exclusion reasons. |
| `size_policy` | Defines item limits and truncation behavior for skill selection. |
| `writeback_out_of_scope` | Confirms that packs do not persist writes directly. |

For this slice, `discord-approval-gate` is always present in `mandatory_skills` and in `effective_skills` for write-like flows. Runtime-core skills (`openclaw-runtime-orchestrator`, `scoped-skill-resolver`, `discord-approval-gate`, `discord-general-advisor`) may be available to prepare the pack, but product workflow skills only appear in `effective_skills` when the scoped resolver selected them for the current route.

## Provenance and exclusion rules

Every included context item or skill must explain why it is present. Every excluded skill must explain why it is absent.

Use these reason families:

- `global-inherited`
- `category-enabled`
- `category-disabled`
- `channel-preferred`
- `channel-disabled`
- `matched-route-context`
- `thread-summary-available`
- `truncated-for-pack-budget`
- `mandatory-global-skill`

Do not silently omit disabled skills. Show them under `excluded_skills` with the disabling reason.

## Size limits and truncation

Packs must stay bounded and explain truncation.

Required markers:

- `max_items`
- `max_chars_per_item`
- `truncation_behavior`
- per-item `truncated: true|false`

Use reviewable defaults in fake fixtures. Do not claim measured runtime limits in this slice.

## Writeback boundary

Writeback is outside the packs.

- Packs may prepare context and selected skills for a future runner.
- Packs may carry a managed channel route ref so context and skills stay bounded to persisted semantic metadata instead of channel-name inference.
- Packs may carry a channel guide ref so runtime scaffolding and helpers can resolve canonical topics and starter/pinned copy.
- Packs must not contain durable writeback execution.
- Any write-like runner output returns through `docs/architecture/discord-memory-gateway.md`.
- Any confirmation-required write must use `skills/discord-approval-gate/SKILL.md` before persistence.

## Scenario expectations

This slice must support two fake scenarios:

1. `egdev-linkedin/#drafts`
2. `stack-and-flow/#github`

Both scenarios stay in matched-route mode, use fake context only, and show why each skill was included or excluded.

## Non-goals

This contract does not:

- implement live pack generation;
- execute prompts or runners;
- perform live Engram calls;
- prove live Discord/runtime enforcement;
- retain raw Discord chat logs as pack content;
- bypass `discord-approval-gate` for write-like outputs;
- introduce new ADR 0002 namespace families;
- enable public Discord behavior, Buffer activity, publishing, or scheduling.

## Validation checklist

- [ ] Fixture uses fake/demo markers only.
- [ ] Context Pack and Skill Pack both declare `pack_kind`.
- [ ] `discord-approval-gate` is mandatory and present in effective write-like flows.
- [ ] Disabled skills are listed with explicit exclusion reasons.
- [ ] Provenance and truncation markers exist for every scenario.
- [ ] `writeback_out_of_scope: true` is present.
- [ ] Runtime namespace is `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`.
- [ ] No raw Discord IDs, credential env names, live/prod claims, or direct writeback behavior are introduced.
