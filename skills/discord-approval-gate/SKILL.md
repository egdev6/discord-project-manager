---
name: discord-approval-gate
description: "Trigger: Discord save, write, update, remember, store, queue, ledger, publish, schedule. Gate persistent writes."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill for any Discord-originated request that includes `save`, `write`, `update`, `remember`, `store`, `queue`, `ledger`, `publish`, or `schedule` intent, or otherwise may persist state.

Also use it when a route-resolved skill proposes writes to project, network, strategy, brand, content-ledger, or runtime workspace state.

## Hard Rules

- Treat `save`, `write`, `update`, `remember`, `store`, `queue`, `ledger`, `publish`, and `schedule` as write-like until proven safe.
- Before explicit approval, do not call file, memory, ledger, queue, publishing, scheduling, or workspace persistence tools.
- The first response must be `proposal` or `approval-requested`; show the exact target namespace, runtime audit namespace, and change summary.
- User-facing proposal prose must match the current Discord message language. Keep technical tokens, namespaces, schema keys, and the exact approval phrase `approve write` in English.
- Accept only the exact phrase `approve write` as approval. Treat silence, emoji, and unrelated replies as no approval.
- If the operator replies `revise: <instruction>`, produce a revised proposal and ask again.
- If the operator replies `reject`, stop without persistence and summarize what did not happen.
- After approval, write only the displayed target namespaces and keep publishing, scheduling, Buffer, and unrelated memory out of scope unless separately approved.
- Do not store secrets, raw private transcripts, real exports, private payload dumps, or unredacted Discord IDs in durable project memory.
- For durable write proposals and decisions, emit a sanitized `audit_record` with actor role/ref, target, decision state, validation result, and rollback/restore hint.

## Decision Gates

| Situation | Response |
| --- | --- |
| Matched route + write-like request | Ask for `approve write` before any persistence. |
| Unmapped route | Do not read or write durable project memory; ask for an approved route. |
| Read-only question | Answer from allowed context without proposing writes. |
| Approval phrase received | Persist only the previously displayed change and displayed namespaces. |
| Revision or rejection | No persistence; revise proposal or stop. |

## Execution Steps

1. Resolve runtime context as `discord-project-manager/runtime/discord/<guild-id>/<channel-id>` without exposing raw IDs in repo artifacts.
2. Resolve durable read candidates only when the route is matched.
3. Classify the request as read-only or write-like.
4. For write-like requests, return the approval prompt from `docs/operations/discord-approval-responses.md`.
5. Keep the pre-approval audit trail in the response unless the runtime provides explicitly non-durable channel-local scratch state.
6. After `approve write`, perform the approved write and record the final sanitized audit trail.
7. For `revise: <instruction>` or `reject`, record only the sanitized decision metadata; do not persist the proposed private payload.

## Output Contract

For write-like requests, return localized user-facing prose plus stable technical tokens:

```text
user_message_language: <language-code>
prose_reply_language: <same-language-code>
technical_tokens_language: en
language_policy: prose-matches-current-message; technical-tokens-stay-english

<Localized heading, e.g. Proposed durable update / Propuesta de actualización durable>
Route: <project>/<network>
Runtime context: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
Target namespace: <namespace-key>
Runtime audit namespace: discord-project-manager/runtime/discord/<guild-id>/<channel-id>
<Localized Change summary label>: <one-sentence summary>
<Localized Risk boundary label>: <what this does not do>
<Localized Audit record label>: <sanitized audit_record ref or inline sanitized audit summary>

<Localized approval instruction>:
- approve write
- revise: <instruction>
- reject
```

For Spanish Discord messages, the proposal prose must be Spanish while the option literals remain exactly `approve write`, `revise: <instruction>`, and `reject`.

## References

- `docs/operations/discord-approval-responses.md`
- `docs/operations/discord-routing.md`
- `docs/architecture/discord-durable-change-audit.md`
- `docs/architecture/channel-context-namespace-mapping.md`
