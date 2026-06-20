# Discord Memory Gateway

This contract defines a fake-first Memory Gateway / Context Broker for Discord-originated flows. It keeps memory hydration and writeback reviewable before any durable Engram write happens.

This is a contract only. It does not prove live Engram calls, live Discord/runtime enforcement, public Discord behavior, production credentials, Buffer activity, publishing, or scheduling.

## Quick path

1. Start from the runtime namespace and resolved route.
2. Hydrate only the context allowed by the routing and scoped-skill contracts.
3. Classify writeback as `auto-save`, `confirmation-required`, `draft`, or `reject`.
4. Use `skills/discord-approval-gate/SKILL.md` for any confirmation-required durable write.
5. Record sanitized audit/provenance metadata for durable change proposals and decisions.
6. Never store raw Discord chat logs as unbounded memory.

## Contract inputs

| Input | Decision |
| --- | --- |
| `runtime_namespace` | Always `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`. |
| `routing_status` | Reuse `matched-route` or `unmapped-channel` from `docs/architecture/channel-context-namespace-mapping.md`. |
| `resolved_route` | Project/network slugs from the routing contract, or `none`. |
| `effective_skills` | Scoped skills resolved from `docs/architecture/discord-scoped-skills-registry.md`. |
| `intent_classification` | `read-only` or `write-like`. |
| `writeback_proposals` | Candidate memory updates returned by skills or runners. |

## Read hydration policy

| Layer | Rule |
| --- | --- |
| Runtime | The gateway may summarize channel-local runtime context from `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`. |
| Global | May hydrate approved reusable context such as project brand or strategy only after a matched route or approved global control-channel origin. |
| Category | May hydrate category-scoped context only when the route and scoped skills resolve that category. |
| Channel | May hydrate channel-local reviewed context only when the route is matched. |
| Thread/session | May hydrate bounded thread/session summaries when they are explicitly modeled, never raw chat logs. |
| Scoped skill context | May hydrate only the context required by the resolved `effective_skills`. |
| Unmapped fallback | Must not hydrate durable brand, strategy, content-ledger, or network memory. |

The gateway depends on:

- `docs/architecture/channel-context-namespace-mapping.md` for routing and durable-read boundaries;
- `docs/architecture/discord-scoped-skills-registry.md` for effective skill resolution;
- `skills/discord-approval-gate/SKILL.md` for confirmation-required writes.

## Topic key taxonomy

Topic keys are record metadata, not new ADR 0002 namespace families.

| Topic key family | Purpose |
| --- | --- |
| `discord/context/route-resolution` | Summarized route outcome and resolver notes. |
| `discord/context/hydration-summary` | Bounded summary of what context the gateway prepared. |
| `discord/context/scoped-skills` | Effective skills used for the current turn. |
| `discord/writeback/strategy-update` | Candidate cross-network strategy writeback. |
| `discord/writeback/network-update` | Candidate network-local writeback such as queue state. |
| `discord/writeback/content-ledger-entry` | Candidate content-ledger writeback. |
| `discord/writeback/global-governance` | Candidate global identity/style/principle change. |
| `discord/audit/approval-decision` | Approval, revision, rejection, or validation decision summary for the current turn. |
| `discord/audit/durable-change` | Sanitized audit/provenance record for a durable Discord-managed change. |

Use these topic keys inside records stored under existing ADR 0002 namespaces such as `discord-project-manager/runtime/discord/<guild-id>/<channel-id>` or `discord-project-manager/project/<project-slug>/...`.

## Writeback policy

| Classification | Meaning | Durable write allowed? |
| --- | --- | --- |
| `auto-save` | Runtime-local audit or bounded summary explicitly allowed by contract. | Not to durable project memory in this slice. |
| `confirmation-required` | Strategy, network, content-ledger, or global governance change. | Only after exact `approve write`. |
| `draft` | Proposal-only artifact for later review. | No. |
| `reject` | Refused or unsafe writeback. | No. |

Global identity, style, or principle changes require explicit confirmation or approved global control-channel origin. Durable writeback proposals must show the runtime audit namespace `discord-project-manager/runtime/discord/<guild-id>/<channel-id>` and the target durable namespaces before persistence.

Durable write proposals and approval decisions must also produce sanitized audit/provenance metadata using `docs/architecture/discord-durable-change-audit.md`. Audit records are metadata, not raw transcripts: they may include actor role refs, target refs, decision state, validation result, and rollback/restore hints, but not private payload dumps.

## Historical anchors

This slice builds on existing memory/runtime anchors:

- #3 `docs(adr): define Engram namespace contract for shared operational memory`
- #51 `ops(runtime): validate first local OpenClaw Engram pilot`

## Non-goals

The Memory Gateway contract does not:

- implement live Engram calls;
- store raw Discord transcripts or chat logs as unbounded memory;
- store raw private payloads as audit/provenance records;
- bypass `discord-approval-gate` for confirmation-required writes;
- introduce new ADR 0002 namespace families;
- prove live Discord/runtime enforcement;
- enable public Discord behavior, Buffer activity, publishing, or scheduling.

## Validation checklist

- [ ] Fixture uses fake/demo markers only.
- [ ] Topic keys are modeled as record metadata, not namespace paths.
- [ ] Matched-route hydration differs from unmapped fallback.
- [ ] `discord-approval-gate` is present in effective skills for write-like flows.
- [ ] Confirmation-required writes stop at approval-requested before persistence.
- [ ] Runtime audit namespace is `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`.
- [ ] Durable write proposals include sanitized audit/provenance metadata and rollback or restore hints.
- [ ] No raw Discord chat logs, real Discord IDs, credential env names, or production claims are introduced.
