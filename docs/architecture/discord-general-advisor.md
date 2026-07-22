# Discord general advisor

This contract defines a fake-first, response-only advisor for Discord users who need routing and operational architecture guidance before choosing a managed Project Manager channel, OpenClaw capability path, or approval-gated workflow.

This is a contract only. It does not prove live Discord routing, live OpenClaw execution, prompt execution, durable writes, GitHub mutations, production credentials, publishing, scheduling, or Buffer activity.

## Quick path

1. Receive a general/help-channel question or unclear managed-channel request.
2. Classify the request topic and risk without hydrating durable private state.
3. Recommend a target scope, category, channel, or handoff path using existing routing contracts.
4. Explain why the route fits and whether approval is required.
5. Optionally return copyable handoff text for the recommended channel.
6. Ask a clarifying question instead of guessing when scope, project, network, or action risk is ambiguous.

## Contract dependencies

The advisor depends on:

- `skills/discord-general-advisor/SKILL.md` for the response-only advisor behavior;
- `docs/architecture/discord-managed-channel-routing.md` for persisted semantic metadata routing;
- `docs/architecture/discord-semantic-channel-guides.md` for channel purpose and starter guide semantics;
- `docs/architecture/discord-scoped-skills-registry.md` for effective skill and override guidance;
- `docs/architecture/discord-runtime-orchestrator.md` for artifact, runner, and backend classification;
- `docs/architecture/discord-memory-gateway.md` and `skills/discord-approval-gate/SKILL.md` for write-like approval boundaries;
- `docs/architecture/discord-gentle-sdd-handoff.md` for OpenClaw skill-development handoff advice.

## Advisor input schema

| Field | Purpose |
| --- | --- |
| `origin_kind` | Source surface such as `discord-general-channel` or `discord-managed-channel`. |
| `runtime_namespace` | `discord-project-manager/runtime/discord/<guild-id>/<channel-id>`. |
| `question_type` | `where_should_this_go`, `architecture_help`, `handoff_copy`, or `clarify_route`. |
| `requested_topic` | Topic family such as `project`, `category`, `channel`, `context`, `skill`, `profile`, `capability`, `strategy`, `task`, `analytics`, or `publishing`. |
| `known_scope` | `global`, `project`, `network`, or `unknown`. |
| `known_project_ref` | Sanitized project ref or `unknown`. |
| `write_like` | Whether the request appears to create, update, store, publish, schedule, commit, or deploy. |
| `user_message_language` | Review language tag for the current Discord message. Fake fixtures currently use `en`, `es`, or `und` for unknown/ambiguous language. |

## Advisor response schema

| Field | Purpose |
| --- | --- |
| `advisor_state` | `route-recommended`, `clarification-needed`, or `blocked-write-like`. |
| `recommended_route` | Target category/channel/path such as `project:<slug>:strategy`, `project:<slug>:skills`, `global:config`, `gentle-sdd`, or `publishing-connector-readiness`. |
| `reason` | Short explanation grounded in existing routing, guide, scoped-skill, or runtime contracts. |
| `required_contracts[]` | Contracts the operator should trust for the recommendation. |
| `approval_required` | Whether exact `approve write` is required before persistence or external effects. |
| `write_executed` | Always `false` in this slice. |
| `handoff_message` | Optional copyable message for the recommended channel. |
| `clarifying_question` | Required when route or risk is ambiguous. |
| `prose_reply_language` | Language tag used for natural-language, user-facing prose; must match `user_message_language`. |
| `technical_tokens_language` | Always `en` for routes, paths, schema keys, commands, and exact approval phrases. |
| `language_policy` | Canonical marker `prose-matches-current-message; technical-tokens-stay-english`. |

## Topic routing guide

| Requested topic | Recommended route |
| --- | --- |
| Project-level question without a field | Ask for the project and intended field, then recommend the matching project category/channel. |
| Category selection | Recommend the managed project category or global Project Manager category from persisted semantic metadata; do not infer from display names. |
| Channel selection | Recommend the semantic channel by `field_key` such as `context`, `skills`, `strategy`, `tasks`, `decisions`, `qa`, or `config`. |
| Project context or assumptions | Project `context` channel. |
| Project strategy, roadmap, or tradeoffs | Project `strategy` channel, e.g. `project:egdev:strategy` in fake fixtures. |
| Actionable implementation planning | Project `tasks` channel. |
| Skill creation or OpenClaw workflow skill changes | `gentle-sdd` handoff via `openclaw_skill_development`. |
| Skill preferences, enablement, or overrides | Project or global `skills` channel, then scoped-skill registry. |
| Private writing preference or profile binding | Private runtime profile path such as `private-runtime:profile-binding`, approval-gated before writes. |
| Runtime capability or connector configuration | Global/project `config` or skills governance, approval-gated before enablement. |
| Analytics or trend ingestion | Strategy/advisory route until v0.5 capability is approved. |
| Publishing or scheduling | `publishing-connector-readiness`; no publish/schedule before explicit approval. |

## Response-language rule

The advisor's user-facing prose replies must match the user's current Discord message language when the language is known. This is a per-message fake-first contract; the fixture metadata proves only the intended policy, not live language detection. Routes such as `project:egdev:strategy`, paths, schema keys, commands, skill names, and exact approval phrases such as `approve write` remain English inside otherwise localized prose.

When the language is unknown or genuinely ambiguous, use `user_message_language: und`, `prose_reply_language: und`, and ask a short language-neutral clarification instead of defaulting silently to English.

## Safety rules

- The advisor explains and proposes; it does not execute work.
- All write-like outcomes must name the approval requirement and keep `write_executed: false`.
- Unclear project, network, channel, or artifact scope must produce a clarifying question.
- Do not infer managed routing success from channel display names when persisted semantic metadata is required.
- Do not commit real Discord IDs, private transcripts, screenshots, secrets, raw runtime state, or personal context.
- Do not claim live Discord behavior, prompt execution, GitHub mutation, publishing, scheduling, or production readiness.

## Non-goals

This contract does not:

- implement a live Discord command handler;
- execute OpenClaw workflow skills;
- execute Gentle SDD phases;
- perform durable memory, repo, GitHub, publishing, or scheduling writes;
- replace managed channel routing or scoped-skill resolution;
- prove public Discord or production behavior.

## Validation checklist

- [ ] Fixture covers project, category, channel, private preference, capability, social bootstrap, publishing, and ambiguity scenarios.
- [ ] Every response includes a route or clarifying question, reason, approval state, and `write_executed: false`.
- [ ] Every scenario includes `user_message_language`, matching `prose_reply_language`, `language_policy: prose-matches-current-message; technical-tokens-stay-english`, and `technical_tokens_language: en`.
- [ ] Write-like advice stays approval-gated.
- [ ] Copyable handoff text is safe and does not include private IDs or transcripts.
- [ ] No live/prod/mutation claims or real Discord identifiers are introduced.
