<!-- markdownlint-disable MD013 -->

# OpenClaw runtime capability inventory

Issue #197 maps requested product capabilities to the current OpenClaw runtime surface, likely ClawHub spikes, private configuration needs, governance risk, and rollout order. Evidence is sanitized: no account data, raw runtime paths, local private paths, Discord identifiers, screenshots, or live values are included.

## Evidence snapshot

| Check | Sanitized result |
| --- | --- |
| `docker compose ps` | Runtime available; `engram`, `openclaw`, and `postgres` services are present; OpenClaw is running and healthy. |
| `openclaw plugins --help` | Plugin registry workflow is supported: `list`, `search`, `inspect`, `install`, `enable`, `disable`, `doctor`, and `registry`. |
| `openclaw plugins list` | Runtime inventory is available; 67 of 98 plugins are enabled; raw source paths were redacted. |
| Enabled plugin groups | AI/model providers including Anthropic, Google, OpenAI, OpenRouter, Runway, FAL, ElevenLabs, Deepgram; Browser, Canvas, Document Extraction, File Transfer, Web Readability Extraction; Device Pairing, Phone Control, Discord. |
| Disabled plugin groups | Active Memory, Admin HTTP RPC, LLM Task, Memory Wiki, Policy, Webhooks, Workboard; DuckDuckGo, Exa, Firecrawl, Parallel, Perplexity, SearXNG; iMessage, IRC, Mattermost, Signal, SMS, Telegram, Thread Ownership. |

## Classification key

Each requested capability has exactly one classification.

| Classification | Meaning |
| --- | --- |
| `existing-plugin` | Present and enabled in the runtime inventory with no expected private setup beyond normal runtime operation. |
| `existing-plugin+config` | Present in the runtime inventory, but safe product use requires private runtime configuration or route policy. |
| `community-plugin-spike` | Candidate exists in ClawHub search evidence; inspect/install/enable is a separate spike. |
| `custom-plugin` | No sufficient verified runtime or ClawHub fit; build a project-owned plugin if the product need is approved. |
| `skill-only` | Best handled by project skills and docs without a runtime plugin. |
| `external-service` | Requires an external product/API surface rather than OpenClaw-native execution alone. |

## Capability inventory

| Capability | Classification | Verified current runtime / candidates | Required scope permission | Private config needs | Governance risk |
| --- | --- | --- | --- | --- | --- |
| Discord managed-channel intake and replies | `existing-plugin+config` | Discord plugin enabled. | `discord:read`, `discord:reply`, route-bound write approval for persistent actions. | Bot/app runtime setup, allowlist/routing, non-repo private channel mapping. | High: can expose private conversation context or write to the wrong route. |
| Engram-backed memory reads/writes | `existing-plugin+config` | `engram` service is available; Active Memory and Memory Wiki plugins are disabled. | `memory:read`; `memory:write` only after approval gate. | Project namespace mapping and private service endpoint policy. | High: durable memory may retain private payloads if not sanitized. |
| Project filesystem workspace | `community-plugin-spike` | ClawHub search found `memory-markdown`; File Transfer plugin is enabled but is not a full product filesystem contract. | `filesystem:read`; `filesystem:write` only inside approved namespaces. | Workspace root mapping, allowlist, backup/restore policy. | High: path traversal, accidental repo/private-state mixing, or large file exfiltration. |
| Browser automation | `community-plugin-spike` | Browser plugin enabled; candidates include `browser-use-plugin`, `openclaw-browser-automation`, `openclaw-browser-agent`, `@clawnify/browser-tabs`, `@ichiorca/openclaw-webmcp-browser-agents`, `oh-my-browser`, `@websirnik/patchright-stealth`, `olostep-web-agent`. | `browser:read`; `browser:act` only per approved task. | Browser profile isolation, session policy, download limits. | High: account/session exposure and unintended web actions. |
| Web article extraction | `existing-plugin` | Web Readability Extraction plugin enabled. | `web:read`. | None beyond outbound access policy. | Medium: citation/source quality and copyrighted content handling. |
| Search-backed discovery | `community-plugin-spike` | DuckDuckGo, Exa, Firecrawl, Parallel, Perplexity, and SearXNG are present but disabled. | `search:read`. | Provider selection, usage limits, optional private provider setup. | Medium: source trust, cost, and result provenance. |
| RSS/feed ingestion | `community-plugin-spike` | ClawHub candidates: `holo-rss-reader`, `@ipocket/clawrss`, `@feednest/openclaw`. | `rss:read`; `content-ledger:write` only after approval. | Feed allowlist and polling cadence. | Medium: stale sources, duplicated items, feed licensing. |
| Document extraction | `existing-plugin+config` | Document Extraction plugin enabled. | `document:read` for approved uploads/attachments. | File size/type policy and retention rules. | Medium: uploaded documents may contain private data. |
| Image generation and transformation | `community-plugin-spike` | Enabled providers include Runway and FAL; candidates include `@wolf521/openclaw-generate-image`, `@lilywlj/openclaw-image-gen-js`, `html-image`, `@clawnify/html-to-image`, `openclaw-draw-things`, `@pruna-ai/p-image*`. | `media:image:create`; `media:image:publish` excluded. | Provider account setup, model policy, output retention. | High: brand safety, rights, consent, and generated-media disclosure. |
| Video generation and editing | `community-plugin-spike` | Enabled providers include Runway; candidates include `openclaw-ai-video-editor`, `automated-video-generator`, `@pruna-ai/p-video*`, `openclaw-plugin-heygen`, `@openclaw/pixverse-provider`, `openclaw-venice-media`. | `media:video:create`; `media:video:publish` excluded. | Provider account setup, rendering budget, asset retention. | High: likeness rights, cost spikes, moderation, and disclosure. |
| Voice/audio transcription or generation | `existing-plugin+config` | ElevenLabs and Deepgram provider plugins enabled. | `audio:transcribe`, `audio:generate`; publishing excluded. | Provider setup, consent policy, retention limits. | High: voice consent and sensitive recording handling. |
| Social content planning | `skill-only` | Existing project skills cover strategy, ledgers, LinkedIn planning, X queues, and on-demand briefs. | `planning:read`, `draft:create`; no external posting. | Project skill inventory and scoped context only. | Medium: stale brand context or unapproved claims. |
| Social posting connector | `community-plugin-spike` | Candidates: `clawsocial-plugin`, `@zeelabs/openclaw-postzee`, `@agntdata/openclaw-linkedin`, `@agntdata/openclaw-youtube`, `@agntdata/openclaw-tiktok`, `@agntdata/openclaw-x`, `postiz-mcp`, `@growthnation/plugin`. | `social:post` only after explicit approval. | Per-network account setup, route allowlist, audit trail. | Critical: live publication, account reputation, compliance. |
| Buffer queue integration | `external-service` | ClawHub search found no Buffer candidates. | `buffer:read`, `buffer:queue` only after explicit approval. | Buffer workspace/API setup outside repo. | Critical: scheduling mistakes become public. |
| Generic publishing workflow | `custom-plugin` | ClawHub search found no generic publishing candidates. | `publish:*` excluded until a product-owned connector is approved. | Connector-specific private setup and rollback/audit design. | Critical: cross-network side effects and weak rollback semantics. |
| Approval and policy gates | `skill-only` | `discord-approval-gate` skill defines exact approval behavior; Policy plugin is present but disabled. | `approval:request`, `approval:record`; no autonomous writes. | Sanitized audit namespace mapping. | High: bypass would allow durable or public side effects. |
| Workboard/task automation | `community-plugin-spike` | Workboard plugin is present but disabled. | `workboard:read`; `workboard:write` only after approval. | Board mapping and status taxonomy. | Medium: task drift and accidental workflow mutation. |

## Recommended rollout order

1. **Read-only runtime baseline**: keep Discord routing, web readability, document extraction, and project skill-only planning behind scoped permissions.
2. **Private memory contract**: wire Engram namespace policy and approval-gated memory writes before adding broader filesystem behavior.
3. **Filesystem spike**: inspect `memory-markdown` and File Transfer boundaries; require allowlisted paths and backup notes before any write path.
4. **Browser and RSS spikes**: validate browser isolation and feed allowlists; keep actions read-only until governance is proven.
5. **Media generation spikes**: test image/audio/video providers with fake prompts and retained artifacts only; do not publish outputs.
6. **Social connector evaluation**: inspect community social plugins against per-network approval, audit, and rollback requirements.
7. **Buffer/publishing decision**: treat Buffer as external-service work and generic publishing as custom-plugin work; only proceed after a separate product decision.

## Non-goals

- Do not install, enable, or configure plugins from this inventory document.
- Do not store live provider setup, account data, Discord identifiers, screenshots, raw plugin paths, or private runtime exports in git.
- Do not claim Buffer, social posting, scheduling, publishing, browser account actions, or filesystem writes are production-ready.
- Do not replace the existing `discord-approval-gate`; runtime capabilities remain subordinate to scoped permission and approval policy.
- Do not promote disabled plugins to enabled status without a focused spike and sanitized validation evidence.

## Review checklist

- [ ] Every capability row uses exactly one allowed classification.
- [ ] Runtime inventory claims are limited to sanitized command evidence.
- [ ] Private configuration is described as a need, not committed as a value.
- [ ] Rollout order keeps public/durable side effects after read-only validation.
