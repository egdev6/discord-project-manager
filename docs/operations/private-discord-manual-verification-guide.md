# Private Discord manual verification guide

Use this guide to organize **manual** operator verification for the planned Discord workflow in a **private non-production environment**.

This is a repo-safe preparation and test-organization guide only. It does **not** prove production readiness, public Discord readiness, live routing safety, durable write safety, or approval enforcement. The current repository baseline remains **internal fake-first/local only**.

## Quick path

1. Confirm the private/local runtime baseline is already green.
2. Prepare a private Discord topology with fake/demo names and no public surfaces.
3. Review global governance and managed Project Manager scaffolding separately.
4. Run only no-op/manual checks until managed status/repair and approval boundaries are proven.
5. Capture sanitized evidence only and stop on any boundary breach.

## Safety boundary

| Topic | Rule |
|---|---|
| Repository baseline | Internal fake-first/local only |
| Live Discord execution | Gated; not proven by current repo evidence |
| Plugin behavior | Prerequisite only; not validated by this guide |
| Production/public usage | Out of scope |
| Durable writes | Never before explicit `approve write` and proven enforcement |
| Approval enforcement | Treat as a contract to verify, **not** as already safe runtime behavior |
| Evidence | Sanitized only; no real IDs, credentials, transcripts, or private payloads |

## Manual prerequisites and approvals

Complete these before any private Discord rehearsal:

| Requirement | Why it matters | Repo-safe rule |
|---|---|---|
| Private non-production guild | Prevents public/live spillover | Do not commit the real guild ID |
| Private non-production channels | Needed for managed Project Manager topology checks | Do not commit real channel IDs |
| Non-production credentials | Required for any future live-adjacent runtime hookup | Keep outside git and PR text |
| Private/local Docker runtime already validated | Discord checks must start from a known local runtime baseline | Reuse `docs/operations/runtime-pilot-checklist.md` and `docs/operations/qa-private-docker-runtime-smoke-walkthrough.md` |
| Explicit human approval | QA-07 remains gated | Record only the decision, not secrets |
| Proven no-op observation path | Managed status/repair and approval behavior must be verifiable without prompt execution or durable writes | Accept only status preview, repair preview, dry-run mode, or re-tested enforcement |

Manual user steps required before future execution: **yes**.

Required future manual prerequisites:

- provide a private non-production Discord guild;
- provide private non-production channels;
- provide non-production credentials outside the repo;
- explicitly approve the private Discord rehearsal;
- confirm a no-op resolver diagnostic, plugin/runtime dry-run mode, or re-tested enforcement path exists before any private message is sent.

## What is in scope vs out of scope

| Layer | In scope for this guide | Out of scope |
|---|---|---|
| Docs/planning | topology, naming, manual test organization, pass/fail expectations | claiming the Discord runtime already passed |
| Local/private runtime | startup, health, skill sync, safe shutdown | public hosting, production services |
| Private Discord-live-adjacent rehearsal | preparation, gating, manual checklists, sanitized evidence shape | unapproved plugin execution, prompt execution, durable writes, public Discord behavior |

## Start and stop the local environment

Use the runtime checklist as the source of truth. Start from a private/local shell only.

### Startup

```bash
docker compose config --quiet
docker compose --profile setup run --rm openclaw-setup
docker compose up -d postgres engram openclaw
docker compose ps
docker compose exec openclaw node -e "fetch('http://127.0.0.1:18789/healthz').then(async r => { console.log(r.status, await r.text()) })"
curl -sS http://127.0.0.1:18080/health
```

### Shutdown

```bash
docker compose down
docker compose ps
```

### Environment checklist

- [ ] `.env` is private and untracked.
- [ ] OpenClaw is healthy on loopback only.
- [ ] Engram is healthy on loopback only.
- [ ] Current tracked skills are present in the OpenClaw workspace.
- [ ] No `docker compose down -v` was used.
- [ ] No Discord plugin action is taken in this issue.

Use these docs together:

- `docs/operations/runtime-pilot-checklist.md`
- `docs/operations/private-docker-runtime-validation.md`
- `docs/operations/qa-private-docker-runtime-smoke-walkthrough.md`

## Discord topology to create manually

Use fake/demo names in docs and notes. Keep real guild/channel IDs outside the repo.

### A. Global governance/control category

`OpenClaw Global` is a reserved control category for governance, not a standard routed content channel set.

Use `docs/architecture/openclaw-global-channel-guides.md` and `examples/openclaw-global-channel-guides.fake.yaml` as the canonical repo-safe source for each control channel's topic and pin-ready starter guidance. Creating the category/channels is not enough: the private setup also needs the approved descriptive copy, previewed first and written only after `approve write`.

Suggested control channels:

| Channel | Purpose | Route-matched? | Guide copy source |
|---|---|---|---|
| `identity` | stable project identity and positioning | no | OpenClaw Global guide catalog |
| `writing-style` | voice and reusable style guidance | no | OpenClaw Global guide catalog |
| `operating-principles` | review, quality, and collaboration rules | no | OpenClaw Global guide catalog |
| `boundaries` | privacy, safety, and no-go constraints | no | OpenClaw Global guide catalog |
| `inheritance` | explicit opt-in inheritance review | no | OpenClaw Global guide catalog |
| `skills` | scoped skill review and override discussion | no | OpenClaw Global guide catalog |

These channels remain separate from Project Manager managed global channels such as `global-context` and `global-skills`.

### B. Project Manager managed scaffolding

The current Project Manager topology is no longer based on ad hoc review/control channels. Instead, it uses one managed global category plus one managed category per project.

#### Project Manager global category

Managed global channels:

| Channel | Purpose | Managed scope |
|---|---|---|
| `global-context` | workspace-wide context, conventions, and constraints | global |
| `global-skills` | reusable skills, defaults, and inheritance decisions | global |
| `global-strategy` | cross-project priorities and strategy | global |
| `global-decisions` | shared decisions and rationale | global |
| `global-config` | operator-visible workspace/runtime config | global |

#### Project category channels

Per-project managed channels:

| Channel | Purpose | Managed scope |
|---|---|---|
| `context` | project-local context, assumptions, and boundaries | project |
| `skills` | project-local skills and approved overrides | project |
| `strategy` | project roadmap, slices, and tradeoffs | project |
| `tasks` | actionable implementation work | project |
| `decisions` | project-local decisions and rationale | project |
| `qa` | validation plans, manual checks, and release gates | project |

These managed categories/channels are distinct from the reserved `OpenClaw Global` governance/control category. Managed channel routing should resolve scope, field, and project from persisted semantic metadata/IDs instead of display-name inference.

## How to create categories and channels

Use the Discord UI manually. Keep notes sanitized.

### Create a global/control category

1. Propose a private category named `OpenClaw Global` and preview the six reserved channels.
2. Add only governance/control channels such as `identity`, `writing-style`, `operating-principles`, `boundaries`, `inheritance`, and `skills` after approval.
3. Propose the topic and starter guidance from `docs/architecture/openclaw-global-channel-guides.md` before writing Discord-visible copy.
4. Require `approve write` before creating channels, updating topics, or posting starter guidance.
5. Do **not** treat these channels as Project Manager project categories or Project Manager `global-*` channels.
6. Record only fake/demo channel names in repo-safe evidence.

### Create Project Manager managed scaffolding

1. Create or verify the separate `Project Manager` global category.
2. Create or verify the managed global channels `global-context`, `global-skills`, `global-strategy`, `global-decisions`, and `global-config`.
3. Create or verify one project-specific category using the current per-project scaffolding contract.
4. Create or verify the project channels `context`, `skills`, `strategy`, `tasks`, `decisions`, and `qa`.
5. Use the semantic channel guide catalog for expected topics/descriptions and starter guidance.
6. Do **not** treat optional human review channels as required topology for the current Project Manager contract.

## Global context management guide

Use `docs/operations/openclaw-global-brand-context-refresh.md` as the source contract.

### Global control areas to manage

| Control area | What to verify |
|---|---|
| `identity` | stable positioning and project identity stay explicit |
| `writing-style` | voice/tone guidance stays reviewable and bounded |
| `operating-principles` | review/quality rules are readable and reusable |
| `boundaries` | safety/privacy/publishing limits stay explicit |
| `inheritance` | opt-in inheritance rules are explicit and never automatic |

### Global context review checklist

- [ ] Control input uses fake/demo notes only.
- [ ] Inheritance is explicit opt-in only.
- [ ] Global updates remain draft/proposal until `approve write`.
- [ ] Rejected or revised drafts remain runtime-local/audit-only.
- [ ] No raw transcripts, real IDs, or private names appear in evidence.

### Global context operator flow

1. Review one control area at a time.
2. Draft a reviewable summary before any persistence.
3. Propose inheritance to specific managed categories/projects only.
4. Preview the derived Context Pack / Skill Pack effect.
5. Require exact `approve write` before any durable write.
6. If rollback is needed, revert to the prior approved global draft and record a sanitized note only.

## Base channel guide by purpose

Use this table to explain what each channel type is for and what “working correctly” means.

| Channel type | Example | What to verify | Expected safe outcome |
|---|---|---|---|
| Global governance | `identity` | control area is reviewable, explicit, and bounded | no automatic inheritance or hidden writes |
| Skills control | `skills` | effective skills and overrides are discussed explicitly | `discord-approval-gate` stays mandatory for write-like flows |
| Global strategy | `global-strategy` | shared strategy stays explicit and reviewable | remains proposal-first until approval |
| Global decisions | `global-decisions` | decisions and tradeoffs are recorded clearly | no implicit runtime writeback |
| Global skills | `global-skills` | effective skills and inheritance remain visible | `discord-approval-gate` stays mandatory for write-like flows |
| Project QA | `qa` | validation and release-gate work stays scoped to one project | no silent cross-project spillover |
| Managed project strategy | `strategy` | project strategy stays scoped to one managed project | planning only; no publishing or analytics claims |
| Managed project tasks | `tasks` | actionable work stays reviewable and bounded | no hidden execution or durable write |
| Approval response | managed channel write-like request | response state stays `proposal` or `approval-requested` | exact `approve write` phrase required |

## Managed routing and namespace expectations

### Managed channel expectation

For a Project Manager channel such as `Project - Linkedin` / `strategy`:

- runtime namespace must still be:

  ```text
  discord-project-manager/runtime/discord/<guild-id>/<channel-id>
  ```

- managed scope, field, and project should resolve from persisted semantic metadata/IDs, not from the display name alone;
- durable read candidates must stay scoped to the managed project and field being reviewed;
- durable writes remain approval-gated and proposal-first.

### Unmanaged channel expectation

For an extra unmanaged channel inside a managed category:

- report it as unmanaged/fallback-only;
- do not infer a project or field by name;
- do not read or write durable project namespaces;
- use status/repair preview flows before any create, update, or cleanup action.

### Skill/context layering expectation

When reviewing packs, expect these scopes when applicable:

- `runtime`
- `global`
- `category`
- `channel`
- `thread-session`
- `scoped-skill-context`

`discord-approval-gate` remains mandatory for write-like flows.

## Manual test matrix

Run only the tests that fit the currently approved boundary. If a test would require prompt execution, workspace writes, or durable writes before approval, stop and mark it blocked.

| Test ID | Area | Manual action | Expected result | Evidence |
|---|---|---|---|---|
| `DV-01` | Local runtime startup | Start the local/private runtime from the checklist | OpenClaw and Engram are healthy on loopback only | sanitized command output |
| `DV-02` | Global category setup | Create `OpenClaw Global` and control channels | governance/control surfaces are separate from Project Manager scaffolding | fake/demo topology note |
| `DV-03` | Project Manager global setup | Create or verify `Project Manager` and global channels | managed global channels exist with semantic guide topics/starter guidance | fake/demo topology note |
| `DV-04` | Project category setup | Create or verify one managed project category and channels | project channels exist with semantic guide topics/starter guidance | fake/demo topology note |
| `DV-05` | Global context review | Review one control area plus inheritance rule | inheritance is explicit opt-in only | sanitized checklist note |
| `DV-06` | Managed routing expectation | Using only status/dry-run preview, inspect one managed project channel | scope, field, and project resolve from semantic metadata/IDs | sanitized status outcome |
| `DV-07` | Unmanaged channel expectation | Using only status/dry-run preview, inspect an unmanaged channel inside a managed category if present | reported as unmanaged/fallback-only without durable reads/writes | sanitized status outcome |
| `DV-08` | Approval preview | Use a synthetic event or proven no-op preview for a write-like request | response state is `proposal` or `approval-requested`, never `approved-for-write` | sanitized approval excerpt |
| `DV-09` | Project/category context | Review one project-local context source | project/category context is explicit, scoped, and does not override global context silently | sanitized project-context checklist |
| `DV-10` | Skills and packs | Review effective skills for one managed project channel | `discord-approval-gate` is present and skill choices follow global -> project -> channel layering | sanitized skill-pack checklist |
| `DV-11` | Memory/context separation | Review runtime namespace and durable namespace targets for one planned action | runtime audit namespace stays separate from brand/strategy/ledger/network durable namespaces | sanitized namespace checklist |
| `DV-12` | Strategy contract | Review strategy output requirements in a strategy-oriented surface | confirmed facts, assumptions, and missing context stay separate | sanitized proposal checklist |
| `DV-13` | Ledger contract | Review ledger candidate shape and allowed states | only `draft`, `queued`, `published`, `archived` appear | sanitized ledger checklist |
| `DV-14` | LinkedIn planning contract | Review a LinkedIn weekly plan candidate | `planning_basis.missing_context` exists and planning stays review-only | sanitized candidate excerpt |
| `DV-15` | X/brief contract | Review brief or X planning candidate structure | network-separated planning stays bounded and approval-gated | sanitized candidate excerpt |
| `DV-16` | Evidence hygiene | Inspect captured sanitized notes only | no real IDs, secrets, screenshots, transcripts, or raw logs are retained | sanitized evidence checklist |
| `DV-17` | Safe shutdown | Stop the local runtime | shutdown is clean and non-destructive | sanitized command output |

## Pass / fail matrix

| Area | Pass when | Fail when |
|---|---|---|
| Environment | local runtime starts, is healthy, and shuts down safely | runtime needs destructive cleanup or public surfaces |
| Topology | global/control and managed Project Manager channels are clearly separated | governance and project-management surfaces are blurred or guessed |
| Global context | inheritance is explicit and reviewable | inheritance is assumed or automatic |
| Category context | category-local context is explicit, scoped, and subordinate to approved inheritance | category context silently overrides global rules or leaks across routes |
| Skills and packs | effective skills are visible and `discord-approval-gate` stays mandatory | write-like flows omit the approval gate or hide skill overrides |
| Memory/context | runtime audit namespaces and durable target namespaces stay separate | runtime notes become durable memory or workspace files without approval |
| Managed routing | scope, field, and project resolution are reviewable through status/dry-run preview | routing proof requires prompt execution, display-name guessing, or writes |
| Approval | `approve write` stays explicit and no-op boundaries are visible | approval is bypassed or silent writes appear |
| Workflow contracts | strategy, ledger, LinkedIn, X, and briefs stay bounded and fake-first | live execution, publishing, or durable writes are implied |
| Evidence | only sanitized notes are kept | real IDs, secrets, transcripts, or private payloads appear |

## Private Discord-to-Engram vertical slice evidence pack

Issue #211 is the release-defining private Discord-to-Engram gate, but the current repo-safe slice is **template/validator only**. It does not close #211, does not prove live Discord behavior, and does not prove durable Engram write/readback. Use this evidence pack before any private rehearsal so reviewers can inspect the intended boundaries without seeing private data.

Repo-safe artifacts:

- `examples/private-discord-engram-vertical-slice.fake.yaml` defines the sanitized evidence shape.
- `scripts/validate-private-discord-engram-vertical-slice.sh` validates that the fixture stays fake-first, approval-gated, and aligned with the orchestrator/resolver/audit/backup contracts.

The evidence pack must keep these defaults until a separate private rehearsal is explicitly approved and summarized safely:

- `live_discord_connection: false`
- `live_engram_calls: false`
- `live_openclaw_prompt_execution: false`
- `runtime_enforcement_proven: false`
- `writes_attempted: false`
- `repo_evidence_status: template-only`

Run the repo-safe validator with:

```bash
bash scripts/validate-private-discord-engram-vertical-slice.sh
bash scripts/validate-repo-safe-evidence.sh
```

## Private Discord-to-Engram rehearsal readiness gate

Before any private Discord message is sent for #211, check the readiness fixture in `examples/private-discord-engram-rehearsal-readiness.fake.yaml` with `scripts/validate-private-discord-engram-rehearsal-readiness.sh`.

This gate is intentionally blocked today: `execution_allowed: false`. It does not close #211 and does not claim live Discord-to-Engram validation. It records the exact prerequisites that must become true outside repo artifacts before a live/private rehearsal can be considered.

The current repo-safe status after #252, #254, and #256 is:

- private write/readback preflight gate exists and remains blocked;
- runtime approval enforcement has repo-safe synthetic guard proof only;
- no-op observation has repo-safe synthetic no-op proof only;
- neither proof upgrades #211 readiness to live/private `available-and-proven`.

Still required before any private write/readback execution:

- private topology and credentials prepared outside git;
- explicit operator approval granted for execution;
- local runtime baseline checked privately;
- approval-gate lifecycle contract remains green;
- runtime approval enforcement proven in the live/private runtime path, including server-side proposal binding;
- private backup/restore contract remains green;
- private redacted no-op event ingestion proven before write-like Discord traffic.

Run the readiness validator with:

```bash
bash scripts/validate-private-discord-engram-rehearsal-readiness.sh
```

## Private topology readiness packet

Use `examples/private-topology-readiness-packet.fake.yaml` and `scripts/validate-private-topology-readiness-packet.sh` to review the repo-safe placeholder topology packet for #262.

This is **repo-safe placeholder readiness**. It records the placeholder shape of the private guild, channel, actor, message, runtime namespace, durable target namespace, and readback namespace without printing private values. It does not prove private topology is prepared for live execution, does not execute private Discord traffic, does not execute Engram write/readback, does not update #211 readiness to available-and-proven, and does not close #211.

Run the topology packet validator with:

```bash
bash scripts/validate-private-topology-readiness-packet.sh
```

## Private redacted no-op ingestion packet

Use `examples/private-redacted-noop-ingestion-packet.fake.yaml` and `scripts/validate-private-redacted-noop-ingestion-packet.sh` to review the repo-safe schema packet for #264.

This is a **repo-safe schema packet**. It defines the placeholder event envelope, no-op boundary expectations, private-run evidence schema, and fail-closed checklist for a future private redacted no-op ingestion run. It does not prove private redacted event ingestion, does not include raw Discord payloads, does not execute private Discord traffic, does not execute Engram write/readback, does not update #211 readiness to available-and-proven, and does not close #211.

Run the ingestion packet validator with:

```bash
bash scripts/validate-private-redacted-noop-ingestion-packet.sh
```

## Private write/readback preflight gate

Use `examples/private-write-readback-preflight-gate.fake.yaml` and `scripts/validate-private-write-readback-preflight-gate.sh` for the first repo-safe #252 slice before any private write/readback execution is even proposed.

This gate is intentionally blocked by default: `execution_allowed: false`. It does not execute a private Discord message, does not execute an Engram write or readback, and does not close #211. #211 remains open until actual private execution and readback are separately approved, executed outside repo-safe artifacts, and reviewed with sanitized evidence.

The gate fails closed unless all four review surfaces are explicitly present in sanitized placeholder form:

- exact write approval state;
- target scope preview;
- runtime and durable namespace preview;
- sanitized evidence schema for future execution/readback review.

Only placeholder summaries are allowed in repo artifacts. Real Discord IDs, credentials, screenshots, raw logs, transcripts, private payloads, raw Engram exports, and SQL dumps remain forbidden.

Run the preflight gate validator with:

```bash
bash scripts/validate-private-write-readback-preflight-gate.sh
```

## Private Discord-to-Engram no-op observation design

Use `examples/private-discord-engram-noop-observation.fake.yaml` and `scripts/validate-private-discord-engram-noop-observation.sh` to review the shape of a future read-only no-op observation path.

This remains **design-only-not-proven** for live/private Discord readiness. It does not update the readiness gate, does not close #211, and does not prove live Discord gateway delivery. The design describes a synthetic or separately approved redacted event preview that must stop at `approval-requested` without prompt execution, workspace writes, Engram writes, filesystem writes, publishing, scheduling, or network calls.

The Docker runtime also includes `discord-project-manager-noop-observation`, a repo-safe synthetic CLI that calls `discord-project-manager-approval-guard` and proves the local no-op preview behavior for sanitized synthetic envelopes. The canonical status is `repo_safe_synthetic_observation_status: synthetic-noop-cli-proven`; the proof level is `repo-safe-synthetic-runtime-cli`. It does not prove live Discord gateway delivery or private redacted event ingestion.

Run the no-op observation validators with:

```bash
bash scripts/validate-private-discord-engram-noop-observation.sh
bash scripts/validate-discord-noop-observation-cli.sh
```

## Private Discord-to-Engram no-op observation proof gate

Use `examples/private-discord-engram-noop-observation-proof.fake.yaml` and `scripts/validate-private-discord-engram-noop-observation-proof.sh` to verify the repo-safe synthetic no-op proof for #256.

This is a **repo-safe synthetic no-op proof**. It validates `discord-project-manager-noop-observation` for matched-route and unmapped-channel synthetic envelopes. It does not prove live private no-op observation, does not prove live Discord gateway delivery, does not execute private Discord traffic, does not execute Engram write/readback, does not update #211 readiness to available-and-proven, and does not close #211.

Run the proof gate validator with:

```bash
bash scripts/validate-private-discord-engram-noop-observation-proof.sh
```

## Runtime approval enforcement repair contract

Use `examples/runtime-approval-enforcement-repair.fake.yaml` and `scripts/validate-runtime-approval-enforcement-repair.sh` to review the required runtime repair before live Discord traffic.

This is **design-only-not-implemented**. It does not update the readiness gate, does not close #211, and does not prove runtime enforcement. The contract requires a guard before workflow skills, model prompt execution, file tools, memory tools, and workspace persistence. Write-like Discord-originated turns must stop at `approval-requested` until the exact `approve write` phrase is received for the displayed target only.

Run the repair contract validator with:

```bash
bash scripts/validate-runtime-approval-enforcement-repair.sh
```

## Runtime approval enforcement proof gate

Use `examples/runtime-approval-enforcement-proof.fake.yaml` and `scripts/validate-runtime-approval-enforcement-proof.sh` to verify the repo-safe synthetic guard proof for #254.

This is a **repo-safe synthetic guard proof**. It validates the deterministic `discord-project-manager-approval-guard` states for write-like input, invalid approval text, exact `approve write`, and unmapped routes. It does not prove live private Discord approval enforcement, does not execute private Discord traffic, does not execute Engram write/readback, does not update #211 readiness to available-and-proven, and does not close #211.

Run the proof gate validator with:

```bash
bash scripts/validate-runtime-approval-enforcement-proof.sh
```

## Proposal binding proof gate

Use `examples/proposal-binding-boundary.fake.yaml` and `scripts/validate-proposal-binding-boundary.sh` to verify the repo-safe synthetic proposal binding proof for #260.

This is a **repo-safe synthetic proposal binding proof**. It validates that exact `approve write` remains scoped to the displayed proposal, route, actor, runtime namespace, target namespace, and operation fingerprint. Missing, stale, mismatched, cross-target, or invalid approvals stay blocked. It does not prove live private proposal binding, does not execute private Discord traffic, does not execute Engram write/readback, does not update #211 readiness to available-and-proven, and does not close #211.

Run the proof gate validator with:

```bash
bash scripts/validate-proposal-binding-boundary.sh
```

## Deterministic approval guard CLI

The Docker runtime includes `discord-project-manager-approval-guard`, a deterministic no-op guard for synthetic/private validation before any workflow runner, prompt, or persistence surface. It does not prove live Discord runtime integration by itself, and it does not authorize writes from caller-supplied arguments. Exact `approve write` moves the result only to `approval-verification-required`; a future server-side binding check must verify the displayed proposal, route, actor, and target before any write-capable runner may persist.

Expected response states:

- `summary-only` for read-only requests;
- `needs-route` for unmapped write-like requests;
- `approval-requested` for write-like requests without exact approval or with invalid approval text;
- `approval-verification-required` after exact `approve write`, still with `persistent_writes_allowed: false` until server-side proposal binding is proven.

Key fields to inspect: `response_state`, `persistent_writes_allowed`, `writes_attempted`, `prompt_execution`, `guard_event_type`, `runtime_namespace`, and `target_namespace`.

Validate it with:

```bash
bash scripts/validate-discord-approval-guard-cli.sh
```

## Runtime boundary harness

The Docker runtime also includes `discord-project-manager-runtime-boundary-harness`, a repo-safe synthetic container probe that composes `discord-project-manager-approval-guard` and `discord-project-manager-noop-observation` inside the packaged OpenClaw image.

This is **container boundary evidence only**. It does not prove live Discord gateway delivery, private redacted event ingestion, or `available-and-proven` readiness for #211. It keeps #211 blocked while verifying these synthetic boundary expectations:

- matched write-like input without approval stops at `approval-requested`;
- matched exact `approve write` stops at `approval-verification-required` with `persistent_writes_allowed: false`;
- unmapped write-like input stops at `needs-route` with `durable_reads_allowed: false`;
- no-op helper output keeps network/filesystem/workspace/Engram writes blocked.

Validate it with:

```bash
bash scripts/validate-discord-runtime-boundary-harness.sh
docker compose run --rm --no-deps openclaw discord-project-manager-runtime-boundary-harness
```

## Private Discord no-op rehearsal plan

Use `docs/operations/private-discord-noop-rehearsal-plan.md`, `examples/private-discord-noop-rehearsal-evidence.fake.yaml`, and `scripts/validate-private-discord-noop-rehearsal-plan.sh` to review the private/redacted no-op observation rehearsal summary.

A no-op-only execution approval was granted and the result is recorded as `pass-summary`. This did not authorize a write-like live Discord message, Engram write/readback, prompt execution, workspace/filesystem writes, publishing, scheduling, GitHub mutations, readiness `available-and-proven`, or closure of #211. It records the gates, stop rules, and summary-minimum evidence shape for the approved no-op observation only.

Validate it with:

```bash
bash scripts/validate-private-discord-noop-rehearsal-plan.sh
```

## Sanitized evidence checklist

- [ ] Use placeholders such as `<guild-id>` and `<channel-id>`.
- [ ] Keep real guild/channel IDs outside the repo.
- [ ] Do not commit credentials, tokens, or `.env` values.
- [ ] Do not commit Discord exports, screenshots, raw logs, or transcripts.
- [ ] Keep route outcomes, approval states, and namespace notes short and review-safe.
- [ ] Record whether a test was `pass`, `blocked`, or `not run`.

## Stop rules / abort conditions

Stop immediately if any of these appear:

- production credentials are required;
- the environment points at a public guild/channel;
- a managed status/routing check requires prompt execution or workspace writes;
- a write-like request causes durable writes before explicit approval;
- plugin setup is not reversible or is unclear;
- evidence would require raw transcripts, raw logs, secrets, or private payloads;
- the flow implies publishing, scheduling, Buffer activity, live analytics, or GitHub mutations.

## Known gaps / not yet proven

These remain **not yet proven** even after following this guide:

- live Discord plugin/runtime behavior;
- approval enforcement safety under real Discord traffic;
- durable write safety from Discord-originated requests;
- public Discord readiness;
- production credentials or production hosting readiness;
- live analytics, publishing, scheduling, or Buffer behavior.

Treat this guide as operator preparation for a **future gated rehearsal**, not as proof that the Discord runtime is already ready.

## Related references

- `docs/operations/runtime-pilot-checklist.md`
- `docs/operations/discord-approval-responses.md`
- `docs/operations/openclaw-global-brand-context-refresh.md`
- `docs/architecture/discord-semantic-channel-guides.md`
- `docs/architecture/discord-project-manager-global-init.md`
- `docs/architecture/discord-project-manager-project-create.md`
- `docs/architecture/discord-managed-channel-routing.md`
- `docs/architecture/discord-channel-scaffolding-status-repair.md`
- `docs/architecture/discord-context-skill-packs.md`
- `docs/architecture/discord-scoped-skills-registry.md`

## Next step

Continue #211 by implementing and proving the no-op observation path and runtime approval enforcement before any live Discord traffic. Keep live execution blocked until the private environment, explicit approval, status/repair preview path, and approval-gate behavior are all available and separately approved.