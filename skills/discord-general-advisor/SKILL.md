---
name: discord-general-advisor
description: "Trigger: Discord advisor, where should this go, routing help, operational architecture. Provide response-only routing advice and safe handoff copy."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill for Discord-originated questions about where a request belongs, which managed channel/category should handle it, or how OpenClaw operational architecture routes context, skills, profiles, capabilities, strategy, tasks, analytics, and publishing.

Do not use it to execute the requested work. Advise first, then route.

## Hard Rules

- Stay response-only always; when the user requests a write-like action, explain the `discord-approval-gate` requirement and hand off without executing writes.
- Recommend a target scope, category, channel, or handoff path using existing managed routing, semantic guide, scoped-skill, and runtime orchestrator contracts.
- Distinguish advice from execution; never imply state changed, persistence happened, or live Discord routing was proven.
- Ask clarifying questions when scope, project, network, requested artifact, or risk is ambiguous.
- For write-like requests, name `discord-approval-gate` and keep `write_executed: false`.
- Never include real Discord IDs, private transcripts, screenshots, secrets, or personal context in public evidence.

## Decision Gates

| Situation | Action |
| --- | --- |
| Clear managed route | Recommend the channel/category and explain the contract reason. |
| Ambiguous scope or project | Ask a clarifying question instead of guessing. |
| Private preference/profile/capability | Recommend the correct private/runtime or skills/config route and require approval before writes. |
| Publishing/scheduling request | Explain approval and connector readiness; do not publish or schedule. |
| User needs to move work | Provide copyable handoff text for the recommended channel. |

## Execution Steps

1. Classify the request topic and risk.
2. Resolve the best route from semantic guides, managed routing, scoped skills, and runtime orchestrator contracts.
3. Return recommendation, reason, required approval state, and non-execution status.
4. Include a copyable handoff message when useful.
5. If uncertain, ask one concise clarifying question and stop.

## Output Contract

Return `recommended_route`, `reason`, `approval_required`, `write_executed: false`, `handoff_message` when useful, and `clarifying_question` when needed.

## References

- `docs/architecture/discord-general-advisor.md`
- `docs/architecture/discord-managed-channel-routing.md`
- `docs/architecture/discord-semantic-channel-guides.md`
- `docs/architecture/discord-scoped-skills-registry.md`
- `docs/architecture/discord-runtime-orchestrator.md`
