---
name: linkedin-weekly-planner
description: "Define a reviewable weekly LinkedIn planning slice from approved context, cadence, and known assets."
license: MIT
---

# LinkedIn Weekly Planner

Use this skill to turn approved project context into a small LinkedIn weekly plan that humans can review before any drafting, publishing, or durable memory write happens.

This skill defines a planning contract only. It does **not** publish, schedule, sync to Buffer, route Discord traffic, or claim that memory writes are already wired.

## Inputs

Required inputs:

- `project_slug`
- `network_slug: linkedin`
- `timeframe`
- `goals`
- `cadence`
- `constraints`
- `known_assets` or `none`

Optional inputs:

- `brand_context_summary`
- `recent_ledger_summary`
- `normalized_snapshots` for `network: linkedin`
- `trend_signals` scoped to LinkedIn or cross-network strategy
- `weekly_theme`
- `audience_focus`
- `review_preferences`
- `source_context`

## Behavior

1. Start from approved brand context and recent ledger context when they are available.
2. Keep weekly planning separate from cross-network strategy rules.
3. Separate confirmed facts, assumptions, explicit `missing_context`, and proposed post angles.
4. If analytics or trends are supplied, use only sanitized normalized snapshots and trend signals from the shared `docs/operations/social-strategy-analytics-trends-ingestion.md` contract; join LinkedIn metrics through `content_ledger_entry_id`, keep unknown metrics as `unknown`, and include trend provenance, observed timestamp, confidence, and source type in the planning basis.
5. Keep each weekly post idea small enough for human review.
6. Treat memory writes as planned targets until a human approves them.
7. Use only fake/demo values in repository-facing examples.
8. Follow ADR 0002 for all namespace references.

## Output shape

Return a YAML-like structure similar to this:

```yaml
project: <project-slug>
network: linkedin
timeframe: <timeframe>
source_context:
  brand_namespace_key: <brand namespace>
  strategy_namespace_key: <strategy namespace>
  ledger_namespace_key: <content ledger namespace>
  network_namespace_key: <linkedin namespace>
planning_inputs:
  goals:
    - <goal>
  cadence:
    posts_per_week: <count>
    preferred_publish_days:
      - <day>
  constraints:
    - <constraint>
  known_assets:
    - <asset>
planning_basis:
  confirmed_facts:
    - <approved fact from source context>
  assumptions:
    - <planning assumption to review>
  missing_context:
    - <important missing input or evidence to resolve later>
  sanitized_performance_inputs:
    - content_ledger_entry_id: <linkedin ledger id or none>
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
    - <post angle under consideration>
weekly_plan:
  posts:
    - id: <stable-demo-id>
      working_title: <title>
      objective: <why this post exists>
      rationale:
        ties_to_goal: <goal linkage>
        brand_alignment: <approved context>
        ledger_reference: <content history cue or none>
      required_assets:
        - <asset>
      approval_checkpoint:
        - <human review step>
approval:
  status: <pending-human-approval|approved-for-demo-validation>
  checkpoints:
    - <approval rule>
memory_write_targets:
  project_strategy_namespace_key: <strategy namespace>
  network_namespace_key: <linkedin namespace>
  write_mode: <planned-only-until-approved>
out_of_scope:
  - <explicit non-goal>
```

## Memory behavior

### Read candidates

- `discord-project-manager/project/<project-slug>/brand`
- `discord-project-manager/project/<project-slug>/strategy`
- `discord-project-manager/project/<project-slug>/content-ledger`
- `discord-project-manager/project/<project-slug>/network/linkedin`

### Write candidates

- reusable cross-network planning rules under `discord-project-manager/project/<project-slug>/strategy`
- approved LinkedIn-local weekly planning context under `discord-project-manager/project/<project-slug>/network/linkedin`

### Approval gate

Do not write or revise durable LinkedIn weekly planning memory until a human approves the weekly plan.

### Namespace target

Use ADR 0002 exactly:

- `discord-project-manager/project/<project-slug>/strategy`
- `discord-project-manager/project/<project-slug>/network/linkedin`

Canonical ADR examples that this skill may mirror when using fake/demo values:

- `discord-project-manager/project/egdev/strategy`
- `discord-project-manager/project/egdev/network/linkedin`

### Promotion to repo artifact

Promote reusable LinkedIn planning rules, approval checkpoints, and contract changes into repo artifacts when they become canonical, review-facing, or architecture-relevant.

## Safety rules

- Do not claim memory was written unless the runtime actually saved it after approval.
- Do not consume raw scraped pages, screenshots, native exports, provider payloads, account data, credentials, or private metrics; require sanitized normalized snapshots instead.
- Do not claim live browser/API scraping, analytics ingestion, or trend-provider access until a separate approved implementation exists.
- Do not publish or schedule content from this contract alone.
- Do not put durable LinkedIn planning under runtime Discord namespaces.
- Do not include private brand plans, secrets, or real customer data in repo examples.

## Demo example (fake)

```yaml
project: egdev
network: linkedin
timeframe: 2026-W24
source_context:
  brand_namespace_key: discord-project-manager/project/egdev/brand
  strategy_namespace_key: discord-project-manager/project/egdev/strategy
  ledger_namespace_key: discord-project-manager/project/egdev/content-ledger
  network_namespace_key: discord-project-manager/project/egdev/network/linkedin
planning_inputs:
  goals:
    - test whether weekly implementation trade-off posts increase qualified technical replies
  cadence:
    posts_per_week: 2
    preferred_publish_days:
      - tuesday
      - thursday
  constraints:
    - english artifacts only
    - no publishing without human approval
  known_assets:
    - asset://demo/linkedin-outline-03
planning_basis:
  confirmed_facts:
    - approved brand context prefers implementation trade-off breakdowns
  assumptions:
    - engineering leads will respond to compact operational lessons
  missing_context:
    - no approved weekly performance analytics are available for this planning slice
  proposed_angles:
    - single reviewable trade-off memo
weekly_plan:
  posts:
    - id: linkedin-weekly-post-01-demo
      working_title: trade-off memo demo
      objective: open a technical discussion with engineering leads
      rationale:
        ties_to_goal: supports weekly technical-depth testing
        brand_alignment: explain trade-offs before implementation
        ledger_reference: x-post-001-demo inspired follow-up angle
      required_assets:
        - asset://demo/linkedin-outline-03
      approval_checkpoint:
        - approve the weekly angle before drafting
approval:
  status: pending-human-approval
  checkpoints:
    - approve durable memory writes before saving planning state
memory_write_targets:
  project_strategy_namespace_key: discord-project-manager/project/egdev/strategy
  network_namespace_key: discord-project-manager/project/egdev/network/linkedin
  write_mode: planned-only-until-approved
out_of_scope:
  - final copy generation
  - live LinkedIn publishing
  - scheduling or Buffer activity
```

This example is fake/demo data only and must not be treated as a live editorial plan.
