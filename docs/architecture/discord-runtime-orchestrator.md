# Discord Runtime Orchestrator

This contract defines a fake-first OpenClaw Runtime Orchestrator for Discord-originated flows. It makes intent classification, runner selection, permission gates, and execution metadata reviewable before any live Discord routing, prompt execution, or durable write happens.

This is a contract only. It does not prove live Discord/OpenClaw runtime behavior, live Engram calls, prompt execution, Gentle SDD execution, GitHub mutations, production credentials, Buffer activity, publishing, or scheduling.

## Quick path

1. Start from a fake Discord event envelope and resolved origin metadata.
2. Resolve managed Project Manager channels through `docs/architecture/discord-managed-channel-routing.md` when persisted semantic metadata exists.
3. Resolve a channel guide ref from `docs/architecture/discord-semantic-channel-guides.md` for the current semantic channel scope.
4. Reference a Context Pack and Skill Pack for the current turn.
5. Classify the requested artifact and persistence target using `docs/architecture/openclaw-artifact-classification.md`.
6. Classify intent and choose an explainable runner/backend.
7. Route any write-like result back through Memory Gateway policy and `discord-approval-gate`.

## Orchestrator pipeline

```text
Discord event envelope
-> origin resolution
-> managed channel route
-> channel guide ref
-> context pack ref
-> skill pack ref
-> artifact classification
-> intent classification
-> runner selection
-> permission/confirmation gate
-> execution metadata
-> writeback policy
```

## Contract dependencies

The orchestrator depends on:

- `skills/openclaw-runtime-orchestrator/SKILL.md` as the OpenClaw-facing runtime-core entry skill;
- `skills/scoped-skill-resolver/SKILL.md` as the deterministic effective-skill resolver before workflow skills are used;
- `skills/discord-general-advisor/SKILL.md` for response-only operational architecture and routing advice;
- `openclaw/config/skill-inventory.yaml` for the curated active skill inventory synced into the OpenClaw workspace;
- `docs/architecture/channel-context-namespace-mapping.md` for origin resolution, `runtime_namespace`, `routing_status`, and `resolved_route`;
- `docs/architecture/discord-managed-channel-routing.md`, `examples/discord-managed-channel-routing.fake.yaml`, and `scripts/validate-discord-managed-channel-routing.sh` for persisted semantic metadata routing of managed Project Manager channels;
- `docs/architecture/discord-semantic-channel-guides.md` for canonical channel topics and starter/pinned guidance copy;
- `docs/architecture/openclaw-artifact-classification.md` for artifact type, persistence target, approval, backup, and deployment implications;
- `docs/architecture/discord-memory-gateway.md` for hydration and writeback policy;
- `docs/architecture/discord-context-skill-packs.md` for prompt-pack references;
- `docs/architecture/discord-scoped-skills-registry.md` for `effective_skills`;
- `skills/discord-approval-gate/SKILL.md` for confirmation-required writes;
- `docs/adr/0001-runtime-boundary.md` for the boundary that keeps Gentle SDD as a backend, not the primary Discord runtime.

## Event envelope schema

| Field | Purpose |
| --- | --- |
| `origin_kind` | Source surface such as `discord-channel` or future control channel types. |
| `runtime_namespace` | `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`. |
| `routing_status` | `matched-route` or `unmapped-channel`. |
| `resolved_route` | Approved `project_slug` and `network_slug`, or `none`. |
| `normalized_channel_name` | Reviewable fake channel-name evidence. |
| `user_role` | Minimal fake operator role or capability hint. |
| `user_message_language` | Review language tag for the current Discord message. Fake fixtures currently use `en`, `es`, or `und` for unknown/ambiguous language. |

## Artifact classification

Before intent routing, the orchestrator must emit a compact artifact classification block. This keeps persistence and approval decisions explicit before a runner is selected.

Classification fields:

| Field | Required? | Purpose |
| --- | --- |
| `artifact_type` | Yes | Requested artifact family such as `workflow_skill`, `private_context`, `runtime_capability`, `publication_flow`, `sdd_dev_work`, or `ephemeral_draft`. |
| `subtype` | When meaningful | Refinement such as `profile`, `scope_binding`, `skill_contract`, or `capability_config`. Use `none` or omit only when the artifact type has no useful subtype. |
| `operation` | Yes | `read`, `draft`, `create`, `update`, `bind`, `reference`, `unbind`, `clone`, `execute`, or `handoff`. |
| `persistence_target` | Yes | `repo`, `private-runtime`, `external-service`, or `ephemeral`. |
| `approval_required` | Yes | Whether exact `approve write` is required before persistence. |
| `backup_required` | Yes | Whether private backup/restore must cover the resulting state. |
| `deployment_required` | Yes | Whether runtime sync, image rebuild, or release promotion is expected. |
| `runner_backend` | Yes | Selected execution boundary such as `openclaw-skill-surface`, `gentle-sdd`, or `response-only`. |
| `writeback_policy` | Yes | Memory Gateway classification: `auto-save`, `confirmation-required`, `draft`, or `reject`. |

Private context profile operations such as create, update, bind, reference, unbind, or clone must classify as `artifact_type: private_context`, `subtype: profile` or `scope_binding`, `persistence_target: private-runtime`, `approval_required: true`, and `backup_required: true`.

See `docs/architecture/openclaw-artifact-classification.md` for the full taxonomy and examples.

## Intent families

First-slice intent families remain intentionally small:

| Family | Meaning | Default gate |
| --- | --- | --- |
| `planning_content` | Planning or content-shaping work that stays proposal-only in this slice. | `summary-only` |
| `sdd_dev_work` | Development/spec-heavy work that may be delegated to a Gentle SDD backend, including governed OpenClaw skill-development requests for repo-backed `skills/{name}/SKILL.md` contracts. | `summary-only` |
| `clarification_needed` | Ambiguous or unmapped input that must ask for route or intent clarification. | `needs-route` |

Artifact classification carries the detailed artifact/persistence decision. Intent families only decide the broad runner shape.

Future families may include `context_update`, `skill_update`, `memory_query`, or `github_operation`, but they are not modeled beyond mention in this first slice.

## Runner selection

Runner routing must stay configurable and explainable.

| Runner kind | Backend | Use when |
| --- | --- | --- |
| `content-planner` | `openclaw-skill-surface` | Context and skills point to bounded planning/content work selected by `scoped-skill-resolver`. |
| `development-orchestrator` | `gentle-sdd` | Intent is `sdd_dev_work` and the runtime only models a delegated backend selection. |
| `clarification` | `response-only` | Route or intent is ambiguous and no durable read/write should continue. |

Gentle SDD is one runner/backend for `sdd_dev_work`. It is not the primary Discord orchestrator. OpenClaw skill-development requests use this boundary as `openclaw_skill_development` handoffs: OpenClaw classifies, resolves permissions, and gates writeback; Gentle SDD may propose repo-backed `skills/{name}/SKILL.md` artifacts, validation evidence, and rebuild/sync/restart requirements, but no write executes from Discord in this slice. The next contract for this backend is `docs/architecture/discord-gentle-sdd-handoff.md`.

## Runtime skill surface

The active OpenClaw skill surface is curated, not “everything in `skills/` means globally enabled.”

| Class | Active skills | Runtime rule |
| --- | --- | --- |
| Runtime core | `openclaw-runtime-orchestrator`, `scoped-skill-resolver`, `discord-approval-gate`, `discord-general-advisor` | Available to classify, resolve, advise, and gate every Discord-originated turn. |
| Scoped workflow | `brand-context`, `content-ledger`, `strategy-planner`, `linkedin-weekly-planner`, `x-queue-planner`, `on-demand-brief-planner` | Invoked only when selected by global/category/channel scoped resolution. |
| Preserved protocol | Gentle-AI SDD assets under `.openclaw/skills` | Used only through the `gentle-sdd` backend boundary for `sdd_dev_work`; product workflow skills are not selected as the executor for OpenClaw skill-development handoffs. |

## Response-language policy

For Discord-originated turns, user-facing prose replies must match the user's current Discord message language. The language decision is per-message and fake-first in this contract; no live detection is proven. Commands, code snippets, schema keys, routes, paths, skill names, backend names, and exact approval phrases remain English even when the surrounding prose is not English.

Reviewable language metadata:

| Field | Required? | Purpose |
| --- | --- | --- |
| `user_message_language` | Yes | Language tag inferred for the current Discord message in the fake event envelope. |
| `prose_reply_language` | Yes | Language tag used for natural-language, user-facing prose. Must match `user_message_language`; use `und` only for an explicit language-neutral clarification fallback. |
| `language_policy` | Yes | Canonical marker `prose-matches-current-message; technical-tokens-stay-english`. |
| `technical_tokens_language` | Yes | Always `en` for commands, snippets, schema keys, routes, paths, approval phrases, and contract identifiers. |

## Permission and confirmation gates

The orchestrator must separate runner selection from persistence permission.

| Gate state | Meaning |
| --- | --- |
| `summary-only` | No approval needed; no writeback executes. |
| `approval-requested` | A write-like proposal needs the exact `approve write` confirmation path. |
| `needs-route` | No durable reads or writes until route/intent is clarified. |

Write-like outcomes must return through `docs/architecture/discord-memory-gateway.md` and use `skills/discord-approval-gate/SKILL.md` before any persistence.

## Execution metadata

Each orchestrated turn should leave reviewable metadata for the contract:

- origin envelope summary;
- selected managed channel route reference when persisted semantic metadata is available;
- selected channel guide reference;
- selected context pack reference;
- selected skill pack reference;
- artifact type, persistence target, approval, backup, and deployment classification;
- intent family and confidence;
- selected runner/backend;
- permission gate state;
- prompt execution state (`none` in this slice);
- writeback policy classification;
- user message language, prose reply language, technical token language, and the language-policy marker.

## Historical anchors

This slice builds on historical runtime/orchestration anchors:

- #1 `research(runtime): verify Gentle-AI SDD inside dockerized OpenClaw`
- #7 `docs(process): define shared-artifact serialization procedure for Pi and OpenClaw SDD`
- #51 `ops(runtime): validate first local OpenClaw Engram pilot`
- #57 `ops(discord): validate private Discord route pilot`

## Non-goals

This contract does not:

- implement live Discord event handling;
- execute prompts or runners;
- execute Gentle SDD work from Discord;
- perform GitHub mutations;
- perform live Engram calls;
- bypass Memory Gateway writeback policy or `discord-approval-gate`;
- prove public Discord behavior, Buffer activity, publishing, or scheduling.

## Validation checklist

- [ ] Fixture uses fake/demo markers only.
- [ ] All scenarios carry `runtime_namespace` and route status.
- [ ] Every scenario includes artifact type, operation, persistence target, approval, backup, deployment, runner backend, and writeback policy.
- [ ] Private context/profile writes require approval and backup coverage.
- [ ] `sdd_dev_work` routes to `backend: gentle-sdd` only.
- [ ] Clarification fallback stays `response-only` and `reject` for writeback.
- [ ] Prompt execution remains `none` in every scenario.
- [ ] Every scenario includes `user_message_language`, matching `prose_reply_language`, `language_policy: prose-matches-current-message; technical-tokens-stay-english`, and `technical_tokens_language: en`.
- [ ] No raw Discord IDs, credential env names, live/prod claims, or GitHub mutation claims are introduced.
