<img width="1536" height="1024" alt="project manager" src="https://github.com/user-attachments/assets/ba59f190-c8e0-4be0-bd6e-aa69f4f7f415" />

# discord-project-manager

<div align="center">

[![Version][version-shield]][releases-url]
[![Issues][issues-shield]][issues-url]
[![Stars][stars-shield]][stars-url]

</div>

Portable Discord-first project operations cockpit for turning ideas into issues, specs, context, and AI-assisted workflows. `discord-project-manager` combines OpenClaw runtime experiments, Gentle-AI SDD practices, and Engram-backed memory in one repo so planning, coordination, and future automation share the same baseline.

## What this project is

`discord-project-manager` is a **planning-first and runtime-baseline repository** for a future Discord-driven workflow where:

- **Discord** is the human-facing entry point for requests, approvals, and coordination.
- **OpenClaw** is the operational runtime being shaped and validated.
- **Gentle-AI / el Gentleman** provides the repo-side SDD workflow for specs, tasks, and implementation discipline.
- **Engram** is the persistent memory layer for durable operational context.

Today, the repo is best understood as a strong foundation for the system, not as a finished SaaS product. It documents the architecture, keeps the planning artifacts in version control, and makes the local runtime easier to validate and evolve.

## What it helps with

Instead of scattering context across chat, docs, and ad-hoc scripts, this project aims to centralize the operational model for:

- planning issues and OpenSpec changes from a shared source of truth;
- organizing project and network context before automation grows;
- validating how Discord, OpenClaw, and persistent memory should interact;
- preparing a future dashboard or read-model layer without inventing it blindly.

## Technology stack

<div align="center">

![Discord](https://img.shields.io/badge/Discord-entry%20point-5865F2?style=for-the-badge&logo=discord&logoColor=white)
![OpenClaw](https://img.shields.io/badge/OpenClaw-runtime-111827?style=for-the-badge&logo=docker&logoColor=white)
![Gentle-AI](https://img.shields.io/badge/Gentle--AI-SDD%20workflow-7C3AED?style=for-the-badge)
![Engram](https://img.shields.io/badge/Engram-persistent%20memory-0EA5E9?style=for-the-badge)
![Docker](https://img.shields.io/badge/Docker-portable%20services-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Postgres](https://img.shields.io/badge/Postgres-storage-336791?style=for-the-badge&logo=postgresql&logoColor=white)
![OpenSpec](https://img.shields.io/badge/OpenSpec-planning%20artifacts-16A34A?style=for-the-badge)

</div>

## Architecture at a glance

```text
Discord
  -> OpenClaw gateway and workspace
  -> Gentle-AI-oriented skills, chains, and planning flows
  -> Engram memory for durable operational context
  -> Future read models, dashboards, and reporting surfaces
```

The repo keeps the planning artifacts, runtime notes, skill contracts, and validation fixtures together so the architecture can evolve intentionally instead of through one-off experiments.

## Quick start

```bash
git clone https://github.com/egdev6/discord-project-manager.git
cd discord-project-manager
test -f .env || cp .env.example .env
# replace every change-me value before storing real memory
# existing pre-rename .env files should use discord-project-manager for project/image/namespace values
```

Create the Discord application and invite the bot before filling the Discord values in `.env`:

1. Open the [Discord Developer Portal](https://discord.com/developers/applications) and create a new application.
2. Add a bot user under **Bot**, then copy the bot token into `DISCORD_BOT_TOKEN`.
3. Copy the application ID into `DISCORD_APPLICATION_ID`.
4. In **OAuth2 → URL Generator**, select the `bot` scope, choose the minimum permissions needed for your private test guild, open the generated URL, and add the bot to that guild.
5. Copy the target guild and operator user IDs into `DISCORD_GUILD_ID` and `DISCORD_USER_ID`. Keep the bot limited to a private non-production guild until the manual verification gate passes.

```bash
docker compose --profile setup run --rm openclaw-setup
docker compose up -d postgres engram openclaw
```

After the services are up, validate health and skill sync:

```bash
docker compose exec openclaw node -e "fetch('http://127.0.0.1:18789/healthz').then(async r => { console.log(r.status, await r.text()) })"
curl -sS http://127.0.0.1:18080/health
docker compose exec openclaw sh -lc 'find /home/node/.openclaw/workspace/skills -maxdepth 3 -type f | sort'
```

If you want the bot to appear online in a private Discord guild, there is one extra setup step: the base OpenClaw image does **not** include the Discord channel plugin by default.

Install the plugin, configure `channels.discord`, and restart OpenClaw:

```bash
docker compose exec openclaw openclaw plugins install @openclaw/discord

docker compose exec openclaw sh -lc 'cat > /tmp/discord.patch.json5 <<EOF
{
  channels: {
    discord: {
      enabled: true,
      token: { source: "env", provider: "default", id: "DISCORD_BOT_TOKEN" },
      applicationId: "$DISCORD_APPLICATION_ID",
      groupPolicy: "allowlist",
      guilds: {
        "$DISCORD_GUILD_ID": {
          requireMention: true,
          users: ["$DISCORD_USER_ID"]
        }
      }
    }
  }
}
EOF
openclaw config patch --file /tmp/discord.patch.json5'

docker compose restart openclaw
docker compose exec openclaw openclaw channels status --deep --probe
```

Expected result:

```text
Discord default: enabled, configured, running, connected
```

If the bot shows **typing** in Discord but never posts a visible reply, the usual next problem is **missing model-provider auth**, not Discord transport.

For the default `openai/gpt-5.5` route, verify auth state, repair legacy config if needed, complete OpenAI OAuth, and restart:

```bash
docker compose exec openclaw openclaw models status
docker compose exec openclaw openclaw models auth list --provider openai

docker compose exec openclaw openclaw doctor --fix
docker compose exec openclaw openclaw config validate

docker compose exec openclaw openclaw models auth login --provider openai --device-code

docker compose restart openclaw
```

After OAuth/device-code login completes, verify again:

```bash
docker compose exec openclaw openclaw models auth list --provider openai
docker compose exec openclaw openclaw models status
docker compose logs --tail=100 openclaw
```

If you prefer a different provider or API-key route, update the model/provider auth before using Discord for real requests.

Keep this limited to a **private non-production guild** and follow the gated Discord guidance before sending live test messages:

- [`docs/operations/docker-runtime.md`](./docs/operations/docker-runtime.md)
- [`docs/operations/discord-routing.md`](./docs/operations/discord-routing.md)
- [`docs/operations/private-discord-manual-verification-guide.md`](./docs/operations/private-discord-manual-verification-guide.md)

## Discord control configuration

After the bot is connected and model auth is working, create the reserved governance surface **before** testing richer managed Project Manager behavior.

Start with the global control category:

- category: `OpenClaw Global`
- channels:
  - `identity`
  - `writing-style`
  - `operating-principles`
  - `boundaries`
  - `inheritance`
  - `skills`

Use a **proposal-first** prompt so the bot previews the write before creating anything:

```text
Propose, but do not execute yet, the creation of the category `OpenClaw Global` in this private guild with the channels `identity`, `writing-style`, `operating-principles`, `boundaries`, `inheritance`, and `skills`. Show me the exact preview and do not touch any other category or channel.
```

If the preview is correct, approve only that exact change:

```text
approve write
Create only the category `OpenClaw Global` and those six channels. Do not modify anything else.
```

After the structure exists, apply the reserved control-channel copy from:

- [`docs/architecture/openclaw-global-channel-guides.md`](./docs/architecture/openclaw-global-channel-guides.md)
- [`examples/openclaw-global-channel-guides.fake.yaml`](./examples/openclaw-global-channel-guides.fake.yaml)

`OpenClaw Global` needs both the structure and the descriptive copy. Keep the topics and starter guidance proposal-first too:

```text
Propose, but do not execute yet, the topic and starter guidance for the OpenClaw Global channels `identity`, `writing-style`, `operating-principles`, `boundaries`, `inheritance`, and `skills`. Show the exact topic and first-message preview for each channel. Do not modify Project Manager channels such as `global-context` or `global-skills`.
```

Approve only the exact copy you want written:

```text
approve write
Apply only the approved OpenClaw Global channel topics and starter guidance. Do not create, rename, or modify any Project Manager managed channels.
```

Why this step matters:

- `OpenClaw Global` is the reserved governance/control surface.
- It is **not** the same as the separate Project Manager global surface (`global-context`, `global-skills`, `global-strategy`, `global-decisions`, `global-config`).
- Creating the control category first gives you a safe place to define identity, style, boundaries, inheritance, and skill policy before testing managed Project Manager behavior.
- The reserved control copy remains approval-gated; topics and starter messages should not be written silently.

Current topology, at a glance:

- `OpenClaw Global` for reserved governance/control channels
- `Project Manager` global managed channels: `global-context`, `global-skills`, `global-strategy`, `global-decisions`, `global-config`
- one managed project category per project with `context`, `skills`, `strategy`, `tasks`, `decisions`, `qa`
- managed routing resolved from persisted semantic metadata/IDs, not from display-name inference

After this step succeeds, continue with the manual verification flow in issue `#132` and the private Discord guide.

## Current status and scope

This repository is currently a **baseline for planning, validation, and runtime shaping**.

Included now:

- Docker Compose foundation for OpenClaw, Engram Cloud, and Postgres
- OpenSpec configuration and repo-level planning structure
- architecture notes, ADRs, process docs, and validation scripts
- issue-first GitHub workflow foundations
- project skill contracts for content and planning operations
- fake fixtures and static validation for future read models

Not finished yet:

- a mature production dashboard or API service;
- fully validated live Discord routing on every target environment;
- confirmed end-to-end Engram behavior for all planned workflows;
- complete productization of the AI-agent operating model inside OpenClaw.

## Project docs

Start with the shortest path that matches your goal:

- **Roadmap baseline:** [`docs/project/roadmap-completion.md`](./docs/project/roadmap-completion.md)
- **Backlog and issue framing:** [`docs/project/backlog.md`](./docs/project/backlog.md)
- **Runtime model:** [`docs/architecture/portable-openclaw-runtime.md`](./docs/architecture/portable-openclaw-runtime.md)
- **Artifact classification:** [`docs/architecture/openclaw-artifact-classification.md`](./docs/architecture/openclaw-artifact-classification.md)
- **Discord runtime orchestrator:** [`docs/architecture/discord-runtime-orchestrator.md`](./docs/architecture/discord-runtime-orchestrator.md)
- **Effective runtime resolver:** [`docs/architecture/discord-effective-runtime-resolver.md`](./docs/architecture/discord-effective-runtime-resolver.md)
- **Durable change audit:** [`docs/architecture/discord-durable-change-audit.md`](./docs/architecture/discord-durable-change-audit.md)
- **Security and data handling:** [`docs/security/data-handling.md`](./docs/security/data-handling.md)
- **Operational Docker guidance:** [`docs/operations/docker-runtime.md`](./docs/operations/docker-runtime.md)
- **Release workflow:** [`docs/process/release-workflow.md`](./docs/process/release-workflow.md)
- **Shared artifact rules:** [`docs/process/shared-artifact-serialization.md`](./docs/process/shared-artifact-serialization.md)

## Working model

The intended split is simple:

| Surface | Role |
| --- | --- |
| GitHub + OpenSpec | Canonical planning, specs, backlog, and reviewable changes |
| OpenClaw | Discord-facing operational runtime |
| Gentle-AI / el Gentleman | Structured development and documentation workflow |
| Engram | Persistent operational memory until promoted into repo artifacts |

That separation keeps the repository useful even before the live operational loop is fully validated.

## Next step

Use the backlog and roadmap artifacts to decide the next approved slice, then validate the corresponding runtime or memory contract before expanding into bigger dashboard or automation work.

---

<div align="center">

**If this direction resonates, star the repo and use it as the planning baseline for the next Discord-driven workflow iteration.**

</div>

<!-- MARKDOWN LINKS & IMAGES -->
[version-shield]: https://img.shields.io/badge/version-pre--release-7C3AED?style=for-the-badge
[issues-shield]: https://img.shields.io/github/issues/egdev6/discord-project-manager?style=for-the-badge
[stars-shield]: https://img.shields.io/github/stars/egdev6/discord-project-manager?style=for-the-badge
[releases-url]: ./docs/project/roadmap-completion.md
[issues-url]: https://github.com/egdev6/discord-project-manager/issues
[stars-url]: https://github.com/egdev6/discord-project-manager/stargazers
