---
name: x-queue-planner
description: "Define a reviewable X queue planning slice from approved context or source ingestion before any persistence."
license: MIT
---

# X Queue Planner

Use this skill to turn approved project context or source ingestion into a small X queue plan that humans can review before any drafting, publishing, scheduling, or durable memory write happens.

This skill defines a planning contract only. It does **not** publish, schedule, sync to Buffer, route Discord traffic, or claim that memory writes are already wired.

## Inputs

Required inputs:

- `project_slug`
- `network_slug: x`
- `timeframe`
- `topics`
- `cadence`
- `tone`
- `constraints`
- `known_assets` or `none`

Optional inputs:

- `brand_context_summary`
- `recent_ledger_summary`
- `normalized_snapshots` for `network: x`
- `trend_signals` scoped to X or cross-network strategy
- `queue_goal`
- `review_preferences`
- `source_context`
- `source_ingestion`

## Behavior

1. Start from approved brand context and recent ledger context when they are available.
2. Treat source ingestion as a normalization step that produces proposal-only queue candidates, never a durable write.
3. Keep X queue planning separate from cross-network strategy rules.
4. Separate confirmed facts, assumptions, variation rules, and proposed angles or candidate updates.
5. If analytics or trends are supplied, use only sanitized normalized snapshots and trend signals from the shared `docs/operations/social-strategy-analytics-trends-ingestion.md` contract; join X metrics through `content_ledger_entry_id`, keep unknown metrics as `unknown`, and include trend provenance, observed timestamp, confidence, and source type in the planning basis.
6. Keep each queued item small enough for human review before any drafting or publishing.
7. Treat memory writes as planned targets until a human approves the queue.
8. For write-like Discord requests, load `skills/discord-approval-gate/SKILL.md` and ask for explicit approval before any persistence.
9. Use only fake/demo values in repository-facing examples.
10. Follow ADR 0002 for all namespace references.

## Output shape

Return a YAML-like structure similar to this:

```yaml
project: <project-slug>
network: x
timeframe: <timeframe>
source_context:
  brand_namespace_key: <brand namespace>
  strategy_namespace_key: <strategy namespace>
  ledger_namespace_key: <content ledger namespace>
  network_namespace_key: <x namespace>
source_ingestion:
  source_type: <fake-manual-input|approved normalized source>
  normalized_signals:
    - <reviewable source cue>
planning_inputs:
  topics:
    - <topic>
  cadence:
    items_per_week: <count>
    preferred_publish_days:
      - <day>
  tone:
    - <tone cue>
  constraints:
    - <constraint>
  known_assets:
    - <asset>
planning_basis:
  confirmed_facts:
    - <approved fact from source context>
  assumptions:
    - <planning assumption to review>
  variation_rules:
    - <queue diversity rule>
  sanitized_performance_inputs:
    - content_ledger_entry_id: <x ledger id or none>
      insight: <normalized analytics cue>
  trend_inputs:
    - source_type: <rss|web|search|trend-provider|manual-sanitized-entry>
      observed_at: <timestamp>
      confidence: <0.0-1.0>
      provenance:
        source_kind: <rss-feed|webpage|search-result|trend-report|manual-note>
        retrieved_by: <fake adapter or human-sanitized-entry>
        retrieval_mode: fake-fixture-no-network
        canonical_url: https://example.invalid/<path>
        source_title: <bounded title>
      strategy_signal: <normalized trend cue>
  proposed_angles:
    - <queued angle under consideration>
queue_plan:
  status: <draft-review|approved-for-demo-validation>
  entries:
    - id: <stable-demo-id>
      entry_type: <single-post|thread>
      working_title: <title>
      objective: <why this item exists>
      rationale:
        ties_to_topic: <topic linkage>
        brand_alignment: <approved context>
        ledger_reference: <content history cue or none>
      variation_note: <how this item differs from adjacent queue items>
      required_assets:
        - <asset>
      approval_checkpoint:
        - <human review step>
approval:
  status: <pending-human-approval|approved-for-demo-validation>
  checkpoints:
    - <approval rule>
approval_request:
  state: <approval-requested>
  reply_options:
    - approve write
    - "revise: <instruction>"
    - reject
memory_write_targets:
  project_strategy_namespace_key: <strategy namespace>
  network_namespace_key: <x namespace>
  write_mode: <planned-only-until-approved>
```

## Memory behavior

### Read candidates

- `discord-project-manager/project/<project-slug>/brand`
- `discord-project-manager/project/<project-slug>/strategy`
- `discord-project-manager/project/<project-slug>/content-ledger`
- `discord-project-manager/project/<project-slug>/network/x`

### Write candidates

- reusable cross-network queue-planning rules under `discord-project-manager/project/<project-slug>/strategy`
- approved X-local queue planning context under `discord-project-manager/project/<project-slug>/network/x`

### Approval gate

Do not write or revise durable X queue planning memory until a human approves the queue. Source ingestion must stop at proposal-only queue candidates until the operator replies with `approve write`.

### Namespace target

Use ADR 0002 exactly:

- `discord-project-manager/project/<project-slug>/strategy`
- `discord-project-manager/project/<project-slug>/network/x`

Canonical ADR examples that this skill may mirror when using fake/demo values:

- `discord-project-manager/project/egdev/strategy`
- `discord-project-manager/project/egdev/network/x`

### Promotion to repo artifact

Promote reusable X queue planning rules, approval checkpoints, and contract changes into repo artifacts when they become canonical, review-facing, or architecture-relevant.

## Safety rules

- Do not claim memory was written unless the runtime actually saved it after approval.
- Do not consume raw scraped pages, screenshots, native exports, provider payloads, account data, credentials, or private metrics; require sanitized normalized snapshots instead.
- Do not claim live browser/API scraping, analytics ingestion, or trend-provider access until a separate approved implementation exists.
- Do not publish or schedule content from this contract alone.
- Do not put durable X queue planning under runtime Discord namespaces.
- Do not include private brand plans, secrets, or real customer data in repo examples.

## Demo example (fake)

```yaml
project: egdev
network: x
timeframe: 2026-W24
source_context:
  brand_namespace_key: discord-project-manager/project/egdev/brand
  strategy_namespace_key: discord-project-manager/project/egdev/strategy
  ledger_namespace_key: discord-project-manager/project/egdev/content-ledger
  network_namespace_key: discord-project-manager/project/egdev/network/x
planning_inputs:
  topics:
    - technical specificity in short-form posts
  cadence:
    items_per_week: 3
    preferred_publish_days:
      - monday
      - wednesday
      - friday
  tone:
    - direct
    - technical
  constraints:
    - no publishing without human approval
  known_assets:
    - asset://demo/x-thread-outline-002
planning_basis:
  confirmed_facts:
    - approved brand context prefers practical technical framing
  assumptions:
    - short threads will outperform generic single-line hooks
  variation_rules:
    - alternate between single-post and thread entries
  proposed_angles:
    - one queue item about reviewability discipline
queue_plan:
  status: draft-review
  entries:
    - id: x-queue-item-01-demo
      entry_type: thread
      working_title: reviewability thread demo
      objective: open a technical discussion without hype framing
      rationale:
        ties_to_topic: reinforces technical specificity
        brand_alignment: explain trade-offs before implementation
        ledger_reference: x-post-001-demo follow-up angle
      variation_note: longer thread to avoid repeating a prior single-post hook
      required_assets:
        - asset://demo/x-thread-outline-002
      approval_checkpoint:
        - approve the queue entry before drafting
approval:
  status: pending-human-approval
  checkpoints:
    - approve queue entries before drafting or publishing
memory_write_targets:
  project_strategy_namespace_key: discord-project-manager/project/egdev/strategy
  network_namespace_key: discord-project-manager/project/egdev/network/x
  write_mode: planned-only-until-approved
```

This example is fake/demo data only and must not be treated as a live editorial plan.
