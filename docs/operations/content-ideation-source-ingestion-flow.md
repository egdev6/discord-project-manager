<!-- markdownlint-disable MD013 -->

# Content ideation source ingestion flow

Issue #200 defines a fake-first contract for turning RSS/feed URLs and webpage sources into bounded, provenance-tagged ideation signals before any durable planning or ledger write. Issue #299 adds the registry-first private read-only baseline: runtime source registries may point at private sources, but repo fixtures stay fake and no adapter may write, publish, schedule, or persist source content.

## Quick path

1. Register sources first, then ingest through the source registry entry; do not accept ad hoc URLs from planning prompts.
2. Commit only repo-safe demo fixtures to git; keep private source URLs, credentials, tokens, headers, cookies, and workspace-specific adapter settings in private runtime configuration.
3. Read sources through approved read-only adapters for the baseline `manual-sanitized-entry`, `rss-feed`, and `webpage` kinds. Candidate `notion-page` and `notion-database` sources stay deferred/private unless an operator supplies a schema and credentials outside the repo.
4. Normalize each item into a bounded summary with source provenance and content-safety notes.
5. Route ideation proposals through `strategy-planner`, `on-demand-brief-planner`, and `discord-approval-gate` before durable storage.

## Source registry contract

| Field | Decision |
| --- | --- |
| `source_kind` | Baseline: `manual-sanitized-entry`, `rss-feed`, or `webpage`. Deferred/private candidates: `notion-page` and `notion-database` only after schema and credentials are supplied outside the repo. |
| `sensitivity` | `public-demo`, `public`, or `private-runtime`. |
| `url_policy` | Git fixtures may use only fake/demo URLs such as `https://example.invalid/...`; private or production URLs stay outside the repo. Private runtime config may carry real URLs only when the operator has authorized the read-only source. |
| `adapter_preference` | Manual entries use a sanitized manual-entry adapter, RSS uses a pending plugin spike or explicit read-only feed adapter, and webpages prefer `web-readability`; search/fetch providers are optional discovery helpers. |
| `runtime_config_policy` | Credentials, private URLs, cookies, headers, Notion database/page IDs, and workspace-specific settings stay in private runtime configuration, never repo fixtures. |
| `storage_policy` | Raw source bodies and private URLs are not durable repo artifacts; only bounded summaries may become proposal inputs. |

## Ingestion output contract

Each source must produce a per-source status envelope before item normalization:

- `source_ref` and `source_kind` must match the registered source, and `retrieved_by` must match its explicit `retrieval_adapter`;
- `retrieval_mode` must remain `fake-fixture-no-network` in repo fixtures and must identify the approved read-only adapter in runtime runs;
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
- `content_boundaries` declaring no raw dump, no private payload, untrusted source content, and no durable write.

## Planning and approval route

Use ingestion output as proposal input only:

```text
source registry -> read-only adapter -> bounded summaries with provenance -> planning skill proposal -> discord approval gate -> optional durable write after approve write
```

Planning skills may map summarized signals into strategy slices or on-demand briefs. Any proposed update to `discord-project-manager/project/<project-slug>/strategy`, `content-ledger`, or `network/<network-slug>` remains `planned-only-until-approved` until the operator replies exactly `approve write`.

## Safety requirements

- Adapters are read-only: no durable memory writes, workspace file writes, publishing, scheduling, queue execution, plugin installation, or plugin enablement during ingestion.
- URL handling must be SSRF-safe: allow only approved schemes and hosts from the registry/runtime policy, reject local/private network targets unless explicitly allowed by a future private adapter policy, follow a bounded redirect policy, and never resolve arbitrary prompt-provided URLs.
- Runtime reads must enforce per-source timeout, maximum response bytes, maximum extracted characters, and maximum emitted items before summarization.
- Every emitted item keeps provenance and a registered `source_ref`; reviewers should not need raw private URLs to audit a proposal.
- Treat fetched or manually entered source text as untrusted content. Wrap it as source material for summarization only, not as instructions for tools, planning, publishing, or scheduling.
- Repo-safe fixtures must use fake URLs only, perform no live fetching, and include no credentials, private URLs, raw source dumps, Discord identifiers, or production claims.

## Adapter notes

- Manual sanitized entry: allowed in the baseline for operator-provided, pre-sanitized snippets. The fixture may show bounded fake text but must still mark it as untrusted source content.
- RSS/feed ingestion: plugin choice remains a pending spike. Documented candidates in `docs/research/openclaw-runtime-capability-inventory.md` include `holo-rss-reader`, `@ipocket/clawrss`, and `@feednest/openclaw`.
- Webpage ingestion: prefer the enabled Web Readability Extraction capability for article extraction where possible.
- Search-backed discovery: DuckDuckGo, Exa, Firecrawl, Parallel, Perplexity, or SearXNG may be evaluated later as read-only discovery providers.
- Notion-backed `notion-page` and `notion-database` entries are a future optional adapter and deferred/private candidates. Do not add a repo dependency on Notion; only enable them in private runtime config after schema, credentials, access scope, and read-only behavior are specified.

## Non-goals

- No live fetching, plugin install/enable, Notion/API calls, publishing, scheduling, queue execution, or durable writes.
- No private source URLs, credentials, Discord identifiers, raw source dumps, transcripts, or production claims in repo artifacts.
- No claim that RSS polling, search providers, browser automation, Notion, or durable storage are wired by this issue.

## Review checklist

- [ ] Fixture includes manual sanitized entry, RSS feed, and webpage source examples.
- [ ] Every repo URL is fake/demo or intentionally public.
- [ ] Every source has a status envelope, and partial or failed sources are isolated.
- [ ] Output summaries are bounded, provenance-tagged, and wrapped as untrusted content.
- [ ] Planning proposals use existing planning skills and `discord-approval-gate` before storage.
- [ ] Validation runs without live network access.
