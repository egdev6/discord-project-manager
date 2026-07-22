<!-- markdownlint-disable MD013 -->

# Content ideation source ingestion flow

Issue #200 defines a fake-first contract for turning RSS/feed URLs and webpage sources into bounded, provenance-tagged ideation signals before any durable planning or ledger write.

## Quick path

1. Register only repo-safe demo sources in git; keep private source URLs in private runtime configuration.
2. Read sources through approved read-only adapters: RSS adapter choice is pending spike, webpage extraction should prefer `web-readability`, and search/fetch providers may be evaluated separately.
3. Normalize each item into a bounded summary with source provenance and content-safety notes.
4. Route ideation proposals through `strategy-planner`, `on-demand-brief-planner`, and `discord-approval-gate` before durable storage.

## Source registry contract

| Field | Decision |
| --- | --- |
| `source_kind` | `rss-feed` or `webpage`. |
| `sensitivity` | `public-demo`, `public`, or `private-runtime`. |
| `url_policy` | Git fixtures may use only fake/demo URLs such as `https://example.invalid/...`; private or production URLs stay outside the repo. |
| `adapter_preference` | RSS uses a pending plugin spike; webpages prefer `web-readability`; search/fetch providers are optional discovery helpers. |
| `storage_policy` | Raw source bodies and private URLs are not durable repo artifacts; only bounded summaries may become proposal inputs. |

## Ingestion output contract

Each source must produce a per-source status envelope before item normalization:

- `source_ref` and `source_kind` must match the registered source, and `retrieved_by` must match its explicit `retrieval_adapter`;
- `retrieval_mode` must remain `fake-fixture-no-network` in repo fixtures;
- `status` is `succeeded`, `partial`, or `failed`;
- `items_emitted` is bounded by `max_items_per_source`;
- failed or partial sources include `failure_reason` and `isolated: true` so one inactive source does not block usable output from other sources;
- `durable_write_executed` remains `false`.

Each normalized item must include:

- `item_id` stable within the ingestion batch;
- `source_ref` pointing back to a registered source key, not a private raw URL;
- `provenance` with `source_kind`, `retrieved_by`, `retrieval_mode`, `canonical_url`, and `source_title`, where kind and retrieval adapter match the registered source;
- `summary` capped by `max_summary_chars`;
- `ideation_signals` capped by `max_signals_per_item`;
- `content_boundaries` declaring no raw dump, no private payload, and no durable write.

## Planning and approval route

Use ingestion output as proposal input only:

```text
source registry -> read-only adapter -> bounded summaries -> planning skill proposal -> discord approval gate -> optional durable write after approve write
```

Planning skills may map summarized signals into strategy slices or on-demand briefs. Any proposed update to `discord-project-manager/project/<project-slug>/strategy`, `content-ledger`, or `network/<network-slug>` remains `planned-only-until-approved` until the operator replies exactly `approve write`.

## Adapter notes

- RSS/feed ingestion: plugin choice remains a pending spike. Documented candidates in `docs/research/openclaw-runtime-capability-inventory.md` include `holo-rss-reader`, `@ipocket/clawrss`, and `@feednest/openclaw`.
- Webpage ingestion: prefer the enabled Web Readability Extraction capability for article extraction where possible.
- Search-backed discovery: DuckDuckGo, Exa, Firecrawl, Parallel, Perplexity, or SearXNG may be evaluated later as read-only discovery providers.
- A Notion-backed source registry could be a future optional adapter, but this contract is storage-agnostic and does not depend on Notion.

## Non-goals

- No live fetching, plugin install/enable, Notion/API calls, publishing, scheduling, queue execution, or durable writes.
- No private source URLs, credentials, Discord identifiers, raw source dumps, transcripts, or production claims in repo artifacts.
- No claim that RSS polling, search providers, browser automation, or durable storage are wired by this issue.

## Review checklist

- [ ] Fixture includes at least one RSS feed source and one webpage source.
- [ ] Every repo URL is fake/demo or intentionally public.
- [ ] Every source has a status envelope, and partial or failed sources are isolated.
- [ ] Output summaries are bounded and provenance-tagged.
- [ ] Planning proposals use existing planning skills and `discord-approval-gate` before storage.
- [ ] Validation runs without live network access.
