---
name: openclaw-runtime-orchestrator
description: "Trigger: Discord runtime request, route, intent, runner, backend, SDD handoff. Select the safe runtime path before workflow skills."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill as the OpenClaw-facing entry point for Discord-originated runtime requests before invoking product workflow skills.

This skill does not execute writes, publish content, schedule content, mutate GitHub, or run Gentle SDD directly. It classifies the turn, selects the runner boundary, and returns reviewable execution metadata.

## Runtime Pipeline

Follow the contract in `docs/architecture/discord-runtime-orchestrator.md`:

```text
Discord event envelope
-> origin resolution
-> managed channel route
-> channel guide ref
-> context pack ref
-> skill pack ref
-> artifact classification
-> intent classification
-> runner selection
-> permission/confirmation gate
-> response-language policy
-> execution metadata
-> writeback policy
```

## Runner Boundaries

| Intent family | Runner/backend | Boundary |
| --- | --- | --- |
| `planning_content` | `openclaw-skill-surface` | Use scoped workflow skills selected by `scoped-skill-resolver`. |
| `sdd_dev_work` | `gentle-sdd` | Handoff to Gentle SDD protocol assets only; do not treat product workflow skills as SDD executors. |
| `clarification_needed` | `response-only` | Ask for route or intent clarification; do not hydrate durable context. |

## Hard Rules

- Resolve scope and effective skills before using any workflow skill.
- Always emit artifact classification before runner selection.
- Always include `discord-approval-gate` for write-like flows.
- Match user-facing prose to the user's current Discord message language, using `user_message_language` and `prose_reply_language`; keep commands, snippets, schema keys, routes, paths, skill/backend names, and exact approval phrases in English.
- Private context profile operations such as `create`, `update`, `reference`, `bind`, `clone`, and channel override proposals are write-like when they target durable private runtime state.
- Do not expose raw Discord IDs, secrets, transcripts, screenshots, or private payloads in repo artifacts.
- Do not claim live Discord, production, publishing, scheduling, Buffer, or durable write success from no-op/model-mediated checks.
- Treat Gentle-AI SDD assets as preserved protocol/backend assets under `.openclaw/skills`, not legacy product skills.

## Output Contract

Return a compact metadata block:

```text
artifact_classification:
  artifact_type: <workflow_skill|private_context|runtime_capability|publication_flow|sdd_dev_work|ephemeral_draft>
  subtype: <profile|scope_binding|skill_contract|capability_config|connector_flow|none>
  operation: <read|draft|create|update|bind|reference|unbind|clone|execute|handoff>
  persistence_target: <repo|private-runtime|external-service|ephemeral>
  approval_required: <true|false>
  backup_required: <true|false>
  deployment_required: <true|false>
  runner_backend: <openclaw-skill-surface|gentle-sdd|response-only>
  writeback_policy: <auto-save|confirmation-required|draft|reject>
intent_family: <planning_content|sdd_dev_work|clarification_needed>
selected_backend_or_runner: <openclaw-skill-surface|gentle-sdd|response-only>
skill_pack_ref: <resolved-pack-or-none>
effective_skills: [<skill-name>]
mandatory_skills: [discord-approval-gate] # for write-like flows
approval_required: <true|false>
writes_attempted: false
user_message_language: <en|es|...>
prose_reply_language: <same-as-user_message_language>
technical_tokens_language: en
language_policy: prose-matches-current-message; technical-tokens-stay-english
boundary_notes: <one sentence>
```

Keep existing runner behavior small: classification may become richer than the current intent families, but `planning_content`, `sdd_dev_work`, and `clarification_needed` remain the only runner-selection families in this slice.

## References

- `docs/architecture/discord-runtime-orchestrator.md`
- `docs/architecture/discord-context-skill-packs.md`
- `docs/architecture/discord-scoped-skills-registry.md`
- `docs/architecture/discord-gentle-sdd-handoff.md`
- `skills/scoped-skill-resolver/SKILL.md`
- `skills/discord-approval-gate/SKILL.md`
