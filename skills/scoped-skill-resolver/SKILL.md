---
name: scoped-skill-resolver
description: "Trigger: effective skills, skill pack, global/category/channel scope, disabled skill, skill override. Resolve skills before workflow execution."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill when a Discord-originated request needs effective context, effective skill selection, effective capability resolution, skill-pack explanation, or global/category/channel inheritance resolution.

This skill is a resolver contract. It does not perform the workflow itself and does not persist registry or private runtime changes.

## Resolution Order

Use the deterministic contract from `docs/architecture/discord-scoped-skills-registry.md`:

```text
effective_skills =
  selected global skills
  + category enabled skills
  + channel preferred skills
  - disabled skills
  + reviewed overrides
```

For write-like flows, add `discord-approval-gate` as mandatory even if a scoped registry draft omits it.

Resolve runtime output as one envelope:

```text
effective_runtime = effective_context + effective_skills + effective_capabilities
```

Do not let workflow skills independently decide private profile bindings or capability permissions.

## Skill Classification

| Class | Skills | Rule |
| --- | --- | --- |
| Runtime core | `openclaw-runtime-orchestrator`, `scoped-skill-resolver`, `discord-approval-gate` | Always available to the runtime surface. |
| Scoped workflow | `brand-context`, `content-ledger`, `strategy-planner`, `linkedin-weekly-planner`, `x-queue-planner`, `on-demand-brief-planner` | Use only when selected by global/category/channel scope. |
| Preserved protocol | Gentle-AI SDD assets under `.openclaw/skills` | Use only through the `gentle-sdd` backend boundary. |

## Hard Rules

- Explain included and excluded context, skills, and capabilities.
- Keep disabled skills excluded unless a reviewed override explicitly re-enables them.
- Never let category/channel workflow skills become global defaults by being merely synced into the workspace.
- Keep `discord-approval-gate` mandatory for write-like outcomes.
- Distinguish capability availability from scoped permission/configuration.
- Include provenance and reason for every included or excluded item.
- Registry updates are write-like and require `approve write` through `discord-approval-gate`.

## Output Contract

```text
scope_layers:
  global: [<skill-or-context-ref>]
  category: [<skill-or-context-ref>]
  channel: [<skill-or-context-ref>]
  disabled: [<skill-or-context-ref>]
effective_context:
  included:
    - ref: <profile-or-context-ref>
      scope: <global|category|channel|thread-session>
      provenance: <source>
      reason: <why-included>
      content_policy: <reference-only-no-private-content|sanitized-summary>
  excluded:
    - ref: <profile-or-context-ref>
      provenance: <source>
      reason: <why-excluded>
effective_skills:
  included:
    - skill_name: <skill>
      class: <runtime-core|scoped-workflow|preserved-protocol>
      provenance: <source>
      reason: <why-included>
  excluded:
    - skill_name: <skill>
      provenance: <source>
      reason: <why-excluded>
effective_capabilities:
  included:
    - capability: <filesystem|browser|buffer|engram|github|image_generation|gentle_sdd>
      available: <true|false>
      permitted: <true|false>
      config_state: <not-required|private-config-required|configured-private|missing-private-config>
      provenance: <source>
      reason: <why-included>
  excluded:
    - capability: <capability>
      available: <true|false>
      permitted: false
      reason: <why-excluded-or-blocked>
mandatory_skills: [discord-approval-gate] # for write-like flows
approval_required: <true|false>
writes_attempted: false
resolution_notes: <one sentence>
```

## References

- `docs/architecture/discord-scoped-skills-registry.md`
- `docs/architecture/discord-effective-runtime-resolver.md`
- `docs/architecture/discord-context-skill-packs.md`
- `openclaw/config/skill-inventory.yaml`
- `skills/discord-approval-gate/SKILL.md`
