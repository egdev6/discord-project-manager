# Discord approval-oriented responses

Use this runbook for Discord responses that may change durable project memory, content-ledger state, or public-facing content plans.

This is a response contract only. It does not prove live Discord bot behavior, OpenClaw routing, Engram writes, Buffer actions, publishing, or scheduling.

## Private pilot finding

A private Discord pilot confirmed that Discord connectivity can work after installing the external `@openclaw/discord` plugin, but the approval boundary is not yet enforced by runtime behavior. In `#x-egdev`, a write-like request created runtime workspace files before the operator explicitly approved the write.

Until the runtime skill/instruction layer is fixed and re-tested, treat this runbook as the required contract, not as proven behavior. Do not use Discord for durable memory, queue, strategy, ledger, publishing, scheduling, or Buffer-affecting writes.

## Runtime enforcement skill

Load `skills/discord-approval-gate/SKILL.md` for Discord-originated requests that include `save`, `write`, `update`, `remember`, `store`, `queue`, `ledger`, `publish`, or `schedule` intent.

Before approval, the safe default is response-only: show the proposal and approval prompt, but do not create project memory, ledger entries, queue state, publishing actions, scheduling actions, or workspace files. Persist only after the operator replies with the exact phrase `approve write`, and only to the displayed target namespace or displayed runtime audit namespace.

## Quick path

1. Summarize the request and resolved route.
2. Show the proposed change before writing anything durable.
3. Ask for an explicit approval phrase.
4. Keep audit trail fields in the response until the operator decides.
5. After approval, write durable project memory, ledger state, and runtime audit notes only to displayed namespaces.

## Lifecycle validation fixture

The repo-safe lifecycle fixture is `examples/discord-approval-gate.fake.yaml`, validated by `scripts/validate-discord-approval-gate.sh`. It is fake-only and does not prove live Discord/OpenClaw/Engram enforcement.

The fixture must cover:

- matched write-like request stops at `approval-requested`;
- exact `approve write` applies only the displayed target scope;
- `revise: <instruction>` produces a revised proposal without persistence;
- `reject` stops without persistence;
- unmapped write-like routes perform no durable reads or writes;
- workspace, memory, ledger, queue, publishing, and scheduling writes stay blocked before approval.

## Response states

| State | Purpose | Durable writes allowed? |
|---|---|---|
| `summary-only` | Answer or summarize context without changing state. | No |
| `proposal` | Show a planned memory, strategy, network, or ledger update. | No |
| `approval-requested` | Ask the operator to approve, reject, or revise the proposal. | No |
| `approved-for-write` | Operator explicitly approves the proposed write. | Yes, within the approved scope |
| `rejected` | Operator rejects the proposal. | No |
| `needs-route` | Channel cannot be mapped to project/network. | No |

## Approval prompts

Memory-changing actions must ask for an explicit approval phrase. Do not treat silence, emoji reactions, or unrelated replies as approval.

### Response-language policy

Approval proposal prose must match the language of the current Discord message. Keep stable technical tokens in English: route names, namespaces, schema keys, and the exact approval phrase `approve write`. The option literals stay exactly:

- `approve write`
- `revise: <instruction>`
- `reject`

For Spanish operator messages, headings and explanatory labels should be Spanish, for example `Propuesta de actualización durable`, `Resumen del cambio`, `Límite de riesgo`, and `Respondé con exactamente una opción`.

Recommended prompt shape:

```text
Proposed durable update
Route: <project>/<network>
Runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Target namespace: <namespace-key>
Runtime audit namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Change summary: <one-sentence summary>
Risk boundary: <what this does not do>

Reply with exactly one option:
- approve write
- revise: <instruction>
- reject
```

Spanish prompt shape:

```text
user_message_language: es
prose_reply_language: es
technical_tokens_language: en
language_policy: prose-matches-current-message; technical-tokens-stay-english

Propuesta de actualización durable
Route: <project>/<network>
Runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Target namespace: <namespace-key>
Runtime audit namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Resumen del cambio: <resumen en español de una oración>
Límite de riesgo: <qué no hace esta acción>
Registro de auditoría: <resumen sanitizado o referencia audit_record>

Respondé con exactamente una opción:
- approve write
- revise: <instruction>
- reject
```

For content-ledger entries, include the ledger status:

```text
Ledger candidate
Target: discord-project-manager/project/<project-slug>/content-ledger
Runtime audit namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Content id: <content-id>
Network: <network-slug>
Status: draft|queued|published|archived
Approval needed: confirm identity and status before write
```

## Audit trail requirements

Every approval-oriented response must leave enough channel-local context for later review.

Before approval, keep these fields in the response when channel-local runtime memory would create persistent workspace files. Record them persistently only after an explicit operator decision, or when the runtime provides explicitly non-durable scratch state:

| Field | Requirement |
|---|---|
| `runtime_namespace` | `discord-project-manager/runtime/discord/<guild-id>/<channel-id>` |
| `routing_status` | `matched-route`, `unmapped-channel`, or other resolver status |
| `resolved_route` | Project/network slugs or `none` |
| `proposal_summary` | Short description of the proposed change |
| `target_namespaces` | Durable namespaces that would be affected |
| `approval_status` | `pending`, `approved`, `rejected`, or `revised` |
| `operator_decision` | Exact approval/rejection/revision phrase when available |
| `no-op_boundaries` | Publishing, scheduling, Buffer, Discord routing, or memory writes that did not happen |

Do not store secrets, real exports, raw private transcripts, or private customer data in the audit trail.

## Planning update example

Fake operator request:

```text
In #x-egdev, save this queue variation rule: alternate single posts and threads this week.
```

Safe response:

```text
Proposed durable update
Route: egdev/x
Runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Target namespace: discord-project-manager/project/egdev/network/x
Runtime audit namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Change summary: add an X queue variation rule for alternating single-post and thread entries this week.
Risk boundary: this will not publish, schedule, or update Buffer.

Reply with exactly one option:
- approve write
- revise: <instruction>
- reject
```

If approved, the durable write target is limited to the approved network namespace. The runtime audit note remains under the displayed runtime Discord namespace.

## Content-ledger update example

Fake operator request:

```text
In #x-egdev, save x-post-002-demo as a draft ledger candidate with asset://demo/x-thread-outline-004.
```

Safe response:

```text
Ledger candidate
Route: egdev/x
Runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Target: discord-project-manager/project/egdev/content-ledger
Runtime audit namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Content id: x-post-002-demo
Network: x
Status: draft
Assets: asset://demo/x-thread-outline-004
Approval needed: confirm identity and draft status before write.

Reply with exactly one option:
- approve write
- revise: <instruction>
- reject
```

The ledger status must stay inside the content-ledger contract: `draft`, `queued`, `published`, or `archived`. Use `queued` only after separate scheduling approval exists.

## Unknown channel response

When routing status is `unmapped-channel`, do not read or write durable project memory.

```text
I cannot map this channel to a project/network yet.
Runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Durable reads: none
Durable writes: none

Choose an approved route before I read or write project memory.
```

## Non-goals

Approval-oriented responses do not authorize:

- publishing;
- scheduling;
- Buffer analytics or sync;
- Engram Cloud enrollment or sync;
- live Discord routing changes;
- durable writes outside the displayed target namespaces.
