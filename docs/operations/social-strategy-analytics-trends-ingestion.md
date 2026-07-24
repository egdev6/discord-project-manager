# Social strategy analytics and trends ingestion

This contract defines a fake-first ingestion surface for social strategy planning. It builds on the content-ledger join model and the existing LinkedIn/X analytics snapshot contracts without claiming that live browser, API, or scraping ingestion exists.

## Source option matrix

| Source option | Reliability | Privacy exposure | ToS risk | Implementation effort | Approval status |
|---|---|---|---|---|---|
| Manual sanitized entry | medium | low when values are aggregated and demo-safe | low | low | approved for fake fixtures and human-entered sanitized snapshots |
| Native platform export | medium-high when exported by an authorized operator | medium; exports may contain account/private metrics before normalization | medium; depends on platform export terms | medium | requires separate approval before any real export is committed or processed |
| Approved provider/API | high when documented analytics endpoints exist | medium; credentials and account scopes must stay outside the repo | medium; provider terms must be reviewed | high | pending per-provider approval; not implemented here |
| RSS, web, search, or trend providers | medium; best for topic signals, not account analytics | medium; public sources still need summaries only | medium; source-specific usage limits apply | medium | allowed only as fake/demo normalized trend fixtures here |
| Browser scraping or browser automation | medium and brittle | high; pages may expose account data or private metrics | high | high | not approved; explicitly out of scope until separately reviewed |

## Normalized snapshot schema

Repository-facing strategy inputs must use normalized snapshots, not raw provider payloads. A social strategy ingestion fixture contains:

```yaml
schema_version: 1
contract: social-strategy-analytics-trends-ingestion
project: <project-slug>
fake: true
safe_for_repo: true
live_scraping_enabled: false
live_api_ingestion_enabled: false
browser_automation_enabled: false
raw_provider_payloads_included: false
screenshots_included: false
account_data_included: false
private_metrics_included: false
credential_material_included: false
source_options:
  - option: <source-option>
    reliability: <low|medium|medium-high|high>
    privacy: <low|medium|high>
    tos_risk: <low|medium|high>
    implementation_effort: <low|medium|high>
    approval_status: <approved-for-fake-fixtures|requires-separate-approval|pending-provider-approval|not-approved>
normalized_snapshots:
  - snapshot_id: <stable-demo-id>
    project: <project-slug>
    network: <linkedin|x|...>
    strategy_namespace_key: discord-project-manager/project/<project-slug>/strategy
    content_ledger_namespace_key: discord-project-manager/project/<project-slug>/content-ledger
    network_namespace_key: discord-project-manager/project/<project-slug>/network/<network>
    source_type: manual-sanitized-entry
    source_approval_status: approved-for-fake-fixtures
    captured_at: <RFC3339 UTC timestamp string ending in Z>
    snapshot_window:
      start: <date>
      end: <date>
    metrics:
      - content_ledger_entry_id: <stable content-ledger id>
        planning_reference_id: <planner id or historical-ledger-entry>
        published_at: <RFC3339 UTC timestamp string ending in Z; on or before captured_at and with date inside snapshot_window>
        values:
          # LinkedIn values are exactly:
          impressions: <non-negative-integer|unknown>
          reactions: <non-negative-integer|unknown>
          comments: <non-negative-integer|unknown>
          shares: <non-negative-integer|unknown>
          clicks: <non-negative-integer|unknown>
          engagement_rate: <0.0-1.0|unknown>
          # X values are exactly: impressions, likes, replies, reposts, quote_posts, clicks, engagement_rate.
          # Account-level/private metrics such as followers_gained are not allowed.
trend_signals:
  - trend_id: <stable-demo-id>
    project: <project-slug>
    strategy_namespace_key: discord-project-manager/project/<project-slug>/strategy
    network_scope:
      - <network>
    source_type: <rss|web|search|trend-provider|manual-sanitized-entry>
    provenance:
      source_kind: <rss-feed|webpage|search-result|trend-report|manual-note>
      retrieved_by: <fake adapter or human-sanitized-entry>
      retrieval_mode: fake-fixture-no-network
      canonical_url: https://example.invalid/<path>
      source_title: <bounded title>
    observed_at: <RFC3339 UTC timestamp string ending in Z>
    confidence: <0.0-1.0>
    signal_summary: <bounded summary, no raw dump; max 280 characters>
metadata:
  fixture_type: fake-demo
  safe_for_repo: true
  note: <bounded fixture note; no live-ingestion claims>
```

Required safety flags are top-level booleans. Repository fixtures for this contract must set `fake` and `safe_for_repo` to `true`, and must set `live_scraping_enabled`, `live_api_ingestion_enabled`, `browser_automation_enabled`, `raw_provider_payloads_included`, `screenshots_included`, `account_data_included`, `private_metrics_included`, and `credential_material_included` to `false`.

Machine enum values required by the validator:

- `source_options[].option`: `manual-sanitized-entry`, `native-platform-export`, `approved-provider-api`, `rss-web-search-trend-provider`, `browser-scraping-automation`.
- `source_options[].reliability`: `low`, `medium`, `medium-high`, `high`.
- `source_options[].privacy`, `source_options[].tos_risk`, `source_options[].implementation_effort`: `low`, `medium`, `high`.
- `source_options[].approval_status`: `approved-for-fake-fixtures`, `requires-separate-approval`, `pending-provider-approval`, `not-approved`.
- `normalized_snapshots[].network`: currently `linkedin` and `x` for the combined fixture.
- `normalized_snapshots[].source_type`: `manual-sanitized-entry` for repository fake analytics snapshots; trend providers stay under `trend_signals`, and native export/provider/API snapshots require a separate approved implementation before they can be validated here.
- `normalized_snapshots[].source_approval_status`: `approved-for-fake-fixtures`.
- `trend_signals[].source_type`: `rss`, `web`, `search`, `trend-provider`, `manual-sanitized-entry`.
- `trend_signals[].provenance.source_kind`: `rss-feed`, `webpage`, `search-result`, `trend-report`, `manual-note`.
- `trend_signals[].provenance.retrieval_mode`: `fake-fixture-no-network`.

## Strategy consumption rules

- Strategy skills consume `normalized_snapshots` and `trend_signals` after content-ledger normalization.
- Per-content analytics must join through `content_ledger_entry_id`; strategy output must not depend on provider-specific post IDs alone.
- Timestamps (`captured_at`, metric `published_at`, and trend `observed_at`) must be quoted RFC3339 UTC strings in `YYYY-MM-DDTHH:MM:SSZ` form; YAML timestamp scalars/datetime objects and space-separated timestamp strings are not accepted.
- Metric `published_at` must be on or before the snapshot `captured_at`, and its date must fall inside the inclusive `snapshot_window.start` through `snapshot_window.end` range.
- Trend inputs must preserve `source_type`, `provenance`, `observed_at`, and numeric `confidence` so planners can separate confirmed facts from weak signals.
- Count metrics (`impressions`, `reactions`, `comments`, `shares`, `clicks`, `likes`, `replies`, `reposts`, `quote_posts`) must be non-negative integers or `unknown`; `engagement_rate` must be numeric from `0.0` to `1.0` inclusive or `unknown`.
- Unknown metrics remain `unknown`; planners must not invent private metrics or infer account-level results from missing fields.

## Non-goals and safety constraints

This slice does not implement live scraping, browser automation, native export processing, OAuth, account analytics APIs, publishing, scheduling, or dashboard synchronization. Do not commit raw provider payloads, screenshots, account data, private metrics, credentials, or real source URLs. Browser/API scraping must not be described as live or production-ready until a separate implementation and approval path exists.
