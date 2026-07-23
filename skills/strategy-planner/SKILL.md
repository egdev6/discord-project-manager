---
name: strategy-planner
description: "Produce small planning outputs for network-specific content workflows using approved brand context."
license: MIT
---

# Strategy Planner

Use this skill to turn approved brand context into a compact planning slice such as a weekly LinkedIn outline, an X queue draft, or a scoped campaign brief.

This skill proposes plans only. It does **not** publish, schedule, or claim that Discord, Buffer, or Engram write paths are already fully wired.

## Inputs

Required inputs:

- `project_slug`
- `network_slug`
- `brand_context_summary`
- `timeframe`
- `goals`
- `constraints`

Optional inputs:

- `campaign_name`
- `recent_ledger_summary`
- `normalized_snapshots` from `social-strategy-analytics-trends-ingestion`
- `trend_signals` from `social-strategy-analytics-trends-ingestion`
- `known_assets`
- `review_preferences`

## Behavior

1. Start from approved brand context when available.
2. Separate confirmed facts from assumptions.
3. Produce concise planning structures instead of long prose.
4. When analytics or trends are provided, consume only sanitized normalized snapshots and trend signals from the shared `docs/operations/social-strategy-analytics-trends-ingestion.md` contract; join analytics through `content_ledger_entry_id`, keep unknown metrics as `unknown`, and preserve trend provenance, timestamp, confidence, and source type in the planning basis.
5. Put cross-network planning rules in project strategy memory and network-local planning state in the network subtree.
6. Keep execution steps for publishing, analytics, and Discord operations out of scope.
7. Use only fake/demo values in repository-facing examples.
8. Follow ADR 0002 for all namespace references.

## Output shape

Return a YAML-like structure similar to this:

```yaml
project: <project-slug>
network: <network-slug>
timeframe: <timeframe>
strategy_slice:
  goals:
    - <goal>
  assumptions:
    - <assumption>
  sanitized_performance_inputs:
    - content_ledger_entry_id: <ledger id or none>
      network: <network>
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
  planned_items:
    - title: <item>
      purpose: <why>
      required_assets:
        - <asset>
  review_checkpoints:
    - <checkpoint>
  out_of_scope:
    - <explicit non-goal>
```

## Memory behavior

### Read candidates

- `discord-project-manager/project/<project-slug>/brand`
- `discord-project-manager/project/<project-slug>/strategy`
- `discord-project-manager/project/<project-slug>/content-ledger`
- `discord-project-manager/project/<project-slug>/network/<network-slug>`

### Write candidates

- cross-network strategy rules under `discord-project-manager/project/<project-slug>/strategy`
- network-local planning context under `discord-project-manager/project/<project-slug>/network/<network-slug>`

### Approval gate

Do not write or revise durable planning memory until a human approves the proposed strategy slice.

### Namespace target

Use ADR 0002 exactly:

- `discord-project-manager/project/<project-slug>/strategy`
- `discord-project-manager/project/<project-slug>/network/<network-slug>`

Canonical ADR examples that this skill may mirror when using fake/demo values:

- `discord-project-manager/project/egdev/strategy`
- `discord-project-manager/project/egdev/network/stack-and-flow`
- `discord-project-manager/project/egdev/network/youtube`
- `discord-project-manager/project/egdev/network/twitch`

### Promotion to repo artifact

Promote reusable planning rules, review checkpoints, and skill behavior into repo artifacts when they become canonical, reusable, or architecture-relevant. Temporary drafts may remain in Engram until approved.

## Safety rules

- Do not pretend memory writes, Discord routing, or Buffer analytics are already operational.
- Do not consume raw scraped pages, screenshots, native exports, provider payloads, account data, credentials, or private metrics; require sanitized normalized snapshots instead.
- Do not claim live browser/API scraping, analytics ingestion, or trend-provider access until a separate approved implementation exists.
- Do not publish or schedule content from this contract alone.
- Do not put durable cross-network strategy inside runtime Discord namespaces.
- Keep repository examples generic and fake.

## Demo example (fake)

```yaml
project: egdev
network: stack-and-flow
timeframe: 2026-W23
strategy_slice:
  goals:
    - test whether short technical clips create demand for longer live sessions
  assumptions:
    - audience prefers implementation trade-offs over motivational framing
  planned_items:
    - title: stack-and-flow demo clip 01
      purpose: tease a longer build breakdown
      required_assets:
        - asset://demo/clip-outline-01
  review_checkpoints:
    - confirm tone still matches project brand context
  out_of_scope:
    - direct publishing
```

This example is fake/demo data only and must not be treated as a live editorial plan.
