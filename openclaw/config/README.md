# OpenClaw config placeholder

This directory is reserved for example config fragments, runtime notes, and local setup guidance related to OpenClaw.

Expected future contents:

- validated routing examples
- environment notes for Docker deployment
- references to confirmed image tags or Dockerfiles

Current routing references:

- `openclaw/config/skill-inventory.yaml` defines the curated active OpenClaw skill inventory, including runtime-core skills, scoped workflow skills, and preserved Gentle-AI SDD protocol assets.
- `skills/openclaw-runtime-orchestrator/SKILL.md` defines the OpenClaw-facing runtime entry skill for intent classification, runner selection, and backend boundary reporting.
- `skills/scoped-skill-resolver/SKILL.md` defines the resolver contract for global/category/channel effective skills.
- `skills/discord-approval-gate/SKILL.md` defines the runtime approval gate for Discord write-like intents.
- `skills/discord-general-advisor/SKILL.md` defines the response-only advisor skill for Discord routing and operational architecture questions.
- `docs/architecture/discord-general-advisor.md` defines the fake general advisor contract and sanitized advisory scenarios.
- `docs/architecture/discord-admin-ux.md` defines the fake admin UX contract for profile, scope binding, effective resolver, capability, and backup/export admin flows.
- `examples/discord-admin-ux.fake.yaml` provides fake admin UX scenarios.
- `scripts/validate-discord-admin-ux.sh` validates the admin UX contract and fixture.
- `examples/discord-general-advisor.fake.yaml` provides fake advisor routing scenarios.
- `scripts/validate-discord-general-advisor.sh` validates the advisor contract and fixture.
- `docs/architecture/discord-channel-routing.md` defines channel naming and namespace mapping.
- `docs/architecture/channel-context-namespace-mapping.md` defines resolver inputs, outputs, and fallback status.
- `docs/operations/discord-routing.md` defines the operator runbook and fallback behavior.
- `docs/operations/discord-approval-responses.md` defines approval prompts and audit trail requirements.
- `docs/architecture/discord-topology-reconciliation.md` defines category/channel discovery and safe reconciliation states.
- `examples/discord-topology-reconciliation.fake.yaml` provides fake topology reconciliation data for validator-driven review.
- `docs/architecture/discord-context-namespace-provisioning.md` defines draft context artifact provisioning from approved topology actions.
- `examples/discord-context-provisioning.fake.yaml` provides fake provisioning plans for validator-driven review.
- `docs/architecture/discord-scoped-skills-registry.md` defines the fake scoped skills registry and control-channel contract.
- `docs/architecture/discord-memory-gateway.md` defines the fake Memory Gateway / Context Broker contract for Discord flows.
- `docs/architecture/discord-semantic-channel-guides.md` defines the canonical fake guide catalog for managed channel topics and starter/pinned prompts.
- `docs/architecture/openclaw-global-channel-guides.md` defines the canonical fake guide catalog for reserved `OpenClaw Global` control-channel topics and starter guidance.
- `docs/research/openclaw-runtime-capability-inventory.md` maps requested product capabilities to the sanitized current runtime plugin inventory, ClawHub candidates, private config needs, governance risk, rollout order, and non-goals.
- `examples/openclaw-global-channel-guides.fake.yaml` provides fake reserved control-channel guide data.
- `scripts/validate-openclaw-global-channel-guides.sh` validates the reserved control-channel guide contract and fixture.
- `docs/architecture/discord-project-manager-global-init.md` defines the fake `/project-manager init` contract for creating the global Project Manager category and channels.
- `examples/discord-project-manager-global-init.fake.yaml` provides fake global init topology, permission, persistence, and idempotency data.
- `scripts/validate-discord-project-manager-global-init.sh` validates the global init contract and fixture.
- `docs/architecture/discord-project-manager-project-create.md` defines the fake `/project create` contract for creating one category per project.
- `examples/discord-project-manager-project-create.fake.yaml` provides fake project creation topology, templates, duplicate handling, permission, persistence, and partial-failure data.
- `scripts/validate-discord-project-manager-project-create.sh` validates the project creation contract and fixture.
- `docs/architecture/discord-project-manager-project-delete.md` defines the fake `/project delete` contract for previewing and tombstoning managed project scaffolding.
- `examples/discord-project-manager-project-delete.fake.yaml` provides fake project delete preview, blocked, retry, and post-delete verification data.
- `scripts/validate-discord-project-manager-project-delete.sh` validates the project delete contract and fixture.
- `docs/architecture/discord-channel-scaffolding-status-repair.md` defines the fake shared status and repair preview contract for managed scaffolding drift.
- `examples/discord-channel-scaffolding-status-repair.fake.yaml` provides fake no-op, missing, renamed, unsafe-missing-id, partial-retry, permission-blocked, and unmanaged-extra scenarios.
- `scripts/validate-discord-channel-scaffolding-status-repair.sh` validates the shared status/repair contract and fixture.
- `docs/architecture/discord-managed-channel-routing.md` defines fake persisted-semantic-metadata routing for managed global/project channels.
- `examples/discord-managed-channel-routing.fake.yaml` provides fake managed channel routing registry and scenarios.
- `scripts/validate-discord-managed-channel-routing.sh` validates managed channel routing boundaries.
- `docker/openclaw/managed-channel-registry.sh` implements the private runtime `private-runtime-managed-channel-registry` CLI used to store managed Project Manager channel bindings outside git.
- `scripts/validate-managed-channel-registry-runtime.sh` validates the private registry CLI behavior and sanitized output.
- `docs/architecture/discord-context-skill-packs.md` defines the fake Context Pack and Skill Pack schemas for Discord prompt preparation.
- `docs/architecture/discord-runtime-orchestrator.md` defines the fake Runtime Orchestrator contract for Discord event envelopes, intent routing, and runner selection.
- `docs/architecture/discord-gentle-sdd-handoff.md` defines the fake handoff contract between OpenClaw Runtime Orchestrator and Gentle SDD.

Do not store live credentials, real guild/channel IDs, or exported runtime state here.
