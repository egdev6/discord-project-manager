# Docker runtime runbook

This runbook covers the M1 portable runtime foundation. It is suitable for local smoke testing only until Discord, Engram memory contracts, and production secrets are validated.

## Prerequisites

- Docker Desktop or Docker Engine with Docker Compose.
- Access to the public images listed in `docs/operations/runtime-version-baseline.md`:
  - OpenClaw base image pinned by digest
  - Engram image pinned by digest
  - `postgres:16-alpine`

Compose builds a small local image, `discord-project-manager-openclaw:local`, from `docker/openclaw/Dockerfile`. That image bakes the repo's tracked `skills/` and `openclaw/config/` seed files on top of the official OpenClaw image.

On this WSL machine, Docker Desktop was reachable through the Windows binary:

```bash
/mnt/c/Program\ Files/Docker/Docker/resources/bin/docker.exe version
/mnt/c/Program\ Files/Docker/Docker/resources/bin/docker.exe compose version
```

Use plain `docker` if your shell has Docker integration enabled. If Docker is installed but the socket is not accessible, use `sudo docker ...` for the pilot or fix local Docker group permissions outside the repo.

## Runtime version baseline

The default Compose/Dockerfile image values are pinned for repeatable v0.2.0 validation. See `docs/operations/runtime-version-baseline.md` for the validated OpenClaw, Engram, Gentle-AI, and Postgres versions plus the override policy.

Validate the static baseline with:

```bash
bash scripts/validate-runtime-version-baseline.sh
```

## First-time setup

```bash
test -f .env || cp .env.example .env
# edit every change-me value before storing real memory; never overwrite an existing .env blindly
# if this checkout existed before the rename, update .env to use discord-project-manager for project/image/namespace values

docker compose --profile setup run --rm openclaw-setup
```

`openclaw-setup` runs non-interactive OpenClaw onboarding with explicit risk acknowledgement and writes the baseline config/workspace into the `openclaw-home` Docker volume.

## Optional Discord plugin

The base OpenClaw image used by this repository does not include the Discord channel plugin by default. A private Discord pilot found that `channels.discord.enabled=true` and a valid bot token are not enough: OpenClaw reported `plugin not installed: discord` and the bot stayed offline until the external plugin was installed.

Install it in the runtime before validating Discord routing:

```bash
docker compose exec openclaw openclaw plugins install @openclaw/discord
docker compose restart openclaw
```

If the local WSL Docker socket is not available, use the Docker Desktop Windows binary from WSL:

```bash
/mnt/c/Program\ Files/Docker/Docker/resources/bin/docker.exe compose exec openclaw openclaw plugins install @openclaw/discord
/mnt/c/Program\ Files/Docker/Docker/resources/bin/docker.exe compose restart openclaw
```

After restart, `openclaw channels status --deep --probe` should include Discord before any route validation begins. If the plugin does not survive a container rebuild or volume reset, reinstall it before repeating Discord validation.

## Start

```bash
docker compose up -d postgres engram openclaw
```

OpenClaw is published on loopback only:

```text
http://127.0.0.1:18789
```

Engram Cloud is published on loopback only:

```text
http://127.0.0.1:18080
```

## Health checks

```bash
docker compose config
docker compose exec openclaw node -e "fetch('http://127.0.0.1:18789/health').then(async r => { console.log(r.status, await r.text()) })"
docker compose ps
```

OpenClaw should report:

```text
200 {"ok":true,"status":"live"}
```

Engram Cloud should report:

```bash
curl -sS http://127.0.0.1:18080/health
```

```json
{"service":"engram-cloud","status":"ok"}
```

The first runtime pilot validated service reachability only. The project still needs to validate client enrollment and sync behavior before storing real context.

## Managed channel registry backend

The local OpenClaw image includes a private runtime CLI for the Project Manager managed channel metadata registry:

```bash
docker compose exec openclaw discord-project-manager-managed-registry backend-status
```

The backend stores private bindings under the OpenClaw workspace volume, outside git:

```text
/home/node/.openclaw/workspace/private-runtime-managed-channel-registry/managed-channel-bindings.jsonl
```

Use `preview-repair` to show metadata that would be written without applying it, and use `put` only after the exact `approve write` gate has been satisfied:

```bash
docker compose exec openclaw discord-project-manager-managed-registry preview-repair \
  '<guild-id>' '<category-id>' '<channel-id>' global context none \
  'project-manager-global:<guild-id>' '/project-manager init'
```

Status verification must resolve from this backend and report `OK`, `MISSING_METADATA`, `NEEDS_REPAIR_PREVIEW`, `WRONG_SCOPE`, `WRONG_FIELD`, or `WRONG_PROJECT`; visible channel-name inference is not accepted as success.

For destructive or permission-sensitive status/repair edge cases, use the non-writing simulation path instead of deleting channels or changing Discord permissions during a private rehearsal:

```bash
docker compose exec openclaw discord-project-manager-managed-registry simulate-edge-case deleted-managed-channel project tasks linkedin
docker compose exec openclaw discord-project-manager-managed-registry simulate-edge-case missing-persisted-id project tasks linkedin
docker compose exec openclaw discord-project-manager-managed-registry simulate-edge-case permission-failure project tasks linkedin manage_messages_for_pin
```

Each simulation must return sanitized output with `write_executed:false`.

## Admin UX preview harness

The local OpenClaw image packages a repo-safe synthetic admin UX preview harness:

```bash
docker compose run --rm --no-deps openclaw discord-project-manager-admin-ux-preview-harness
```

This command emits sanitized read-only summaries and approval-gated previews for the fake admin UX contract. It does not read live Discord, Engram/private runtime, private profile bodies, exports, SQL dumps, screenshots, raw logs, transcripts, or credentials.

Validate the repo and container harness surfaces with:

```bash
bash scripts/validate-discord-admin-ux-preview-harness.sh
ADMIN_UX_PREVIEW_HARNESS_DOCKER_SMOKE=1 \
  bash scripts/validate-discord-admin-ux-preview-harness.sh
docker compose run --rm --no-deps openclaw discord-project-manager-admin-ux-preview-harness
```

## Runtime boundary harness

The local OpenClaw image also packages a synthetic container-side runtime boundary harness:

```bash
docker compose run --rm --no-deps openclaw discord-project-manager-runtime-boundary-harness
```

This command is repo-safe container boundary evidence only. It composes `discord-project-manager-approval-guard` and `discord-project-manager-noop-observation` for synthetic inputs, and it does **not** prove live Discord gateway delivery, private event ingestion, or `available-and-proven` readiness.

Validate the repo and container harness surfaces with:

```bash
bash scripts/validate-discord-runtime-boundary-harness.sh
docker compose run --rm --no-deps openclaw discord-project-manager-runtime-boundary-harness
```

## Stop

```bash
docker compose down
```

## Volumes

| Volume | Purpose | Safe to delete? |
|---|---|---|
| `openclaw-home` | OpenClaw config, workspace, sessions, and runtime state | Only for disposable smoke tests |
| `engram-postgres` | Engram Cloud Postgres data | No, if it contains real memory |

To reset a disposable local smoke environment:

```bash
docker compose down -v
```

Never run `down -v` against a runtime that contains real Engram memory unless you have an export/backup.

## Skill and Gentle-AI mounting

The repository's tracked `skills/` directory is copied into the local OpenClaw runtime image. Startup sync then copies only the curated active OpenClaw skills from `openclaw/config/skill-inventory.yaml` into:

```text
/home/node/.openclaw/workspace/skills
```

The active runtime-core skills are `openclaw-runtime-orchestrator`, `scoped-skill-resolver`, `discord-approval-gate`, and `discord-general-advisor`. The workflow skills `brand-context`, `content-ledger`, `strategy-planner`, `linkedin-weekly-planner`, `x-queue-planner`, and `on-demand-brief-planner` are synced as scoped workflow skills: available to the runtime, but intended to be used only after scoped skill resolution selects them. Gentle-AI SDD assets are separate protocol/backend assets under `.openclaw/skills`, not product workflow skills.

The M1 smoke test confirmed OpenClaw discovers workspace `SKILL.md` files from this shape. Runtime-generated workspace state remains in the `openclaw-home` volume, not in git.

The local OpenClaw image also installs a pinned `gentle-ai` binary into:

```text
/usr/local/bin/gentle-ai
```

On `openclaw-setup` and normal `openclaw` startup, `discord-project-manager-sync-skills` checks whether the OpenClaw workspace already has the Gentle-AI SDD/Engram protocol. If it is missing, the script runs:

```bash
gentle-ai install --agent openclaw --preset full-gentleman --scope=workspace
```

The expected runtime artifacts are:

```text
/usr/local/bin/gentle-ai
/usr/local/bin/engram
/home/node/.openclaw/workspace/AGENTS.md
/home/node/.openclaw/workspace/SOUL.md
/home/node/.openclaw/workspace/.openclaw/skills/sdd-init/SKILL.md
/home/node/.openclaw/workspace/.openclaw/skills/sdd-*/SKILL.md
/home/node/.openclaw/openclaw.json  # mcp.servers includes engram/context7
/home/node/.openclaw/engram-data    # OpenClaw-local Engram CLI data
```

OpenClaw uses the Gentle-AI SDD flow as a **solo-agent** workflow: the protocol is injected through workspace instructions instead of Pi-style SDD subagents/chains.

The Engram MCP server configured by Gentle-AI is a stdio process (`engram mcp --tools=agent`), so the OpenClaw runtime image must include the `engram` CLI locally. Its data directory is set to `/home/node/.openclaw/engram-data` by default so local MCP memory survives container recreation with the `openclaw-home` volume. This is separate from the optional `engram` cloud service used elsewhere in the compose stack.

Validate the packaging contract without Docker credentials:

```bash
bash scripts/validate-runtime-version-baseline.sh
bash scripts/validate-openclaw-gentle-ai-runtime.sh
```

Validate a running Docker runtime after services are up:

```bash
OPENCLAW_GENTLE_RUNTIME=1 bash scripts/validate-openclaw-gentle-ai-runtime.sh
```

The local no-op orchestration evidence for Gentle SDD backend selection, OpenClaw skill-surface routing, scoped skill resolution, and write-gate behavior is recorded in `docs/operations/openclaw-gentle-orchestration-validation.md`.

If the Discord bot was already in a long-running session before Gentle-AI sync, start a new session or reset the old session before expecting it to answer SDD/Engram questions. Existing sessions may keep their earlier prompt context.

## OpenAI OAuth and Discord session refresh

OpenAI OAuth is **operator/deployment state**. It does not travel in git, and it must not be pasted into docs, issues, PRs, or logs. The repository/image provides Gentle-AI, Engram MCP, and validators; each local or VPS deployment still needs its own OpenAI auth profile.

Run OAuth from a real interactive terminal because OpenClaw requires a TTY:

```bash
docker compose exec openclaw openclaw models auth login --provider openai
```

After OAuth succeeds, set OpenAI as the default model and remove temporary fallback models that may have been used during troubleshooting:

```bash
docker compose exec -T openclaw openclaw models set openai/gpt-5.5
docker compose exec -T openclaw openclaw models fallbacks clear
```

Verify model auth without printing secrets:

```bash
docker compose exec -T openclaw openclaw models status
```

Expected shape:

```text
Default       : openai/gpt-5.5
Fallbacks (0) : -
Runtime auth
- openai ... status=usable
```

Restart OpenClaw after model/auth changes:

```bash
docker compose restart openclaw
```

Reset only Discord agent sessions after changing model auth, Gentle-AI prompt state, or MCP tools. This prevents Discord from reusing stale tool/model context while preserving non-Discord sessions. The reset must back up `sessions.json` first:

```bash
backup_dir="/home/node/.openclaw/session-reset-backups/$(date -u +%Y%m%dT%H%M%SZ)-discord-reset"

docker compose exec -T -e BACKUP_DIR="$backup_dir" openclaw node <<'NODE'
const fs = require('fs');
const backupDir = process.env.BACKUP_DIR;
const p = '/home/node/.openclaw/agents/main/sessions/sessions.json';
fs.mkdirSync(backupDir, { recursive: true });
let data = {};
if (fs.existsSync(p)) {
  fs.copyFileSync(p, `${backupDir}/sessions.json`);
  data = JSON.parse(fs.readFileSync(p, 'utf8'));
}
const before = Object.keys(data).length;
let removedCount = 0;
for (const key of Object.keys(data)) {
  if (key.startsWith('agent:main:discord:')) {
    delete data[key];
    removedCount += 1;
  }
}
fs.writeFileSync(p, JSON.stringify(data, null, 2));
console.log(JSON.stringify({ before, after: Object.keys(data).length, removedCount, backupDir }));
NODE

docker compose restart openclaw
```

Validate the runtime before asking Discord to use memory:

```bash
curl -fsS http://127.0.0.1:18789/health

docker compose exec -T openclaw openclaw models status
docker compose exec -T openclaw openclaw mcp doctor
docker compose exec -T openclaw openclaw mcp probe

docker compose exec -T openclaw openclaw agent \
  --session-key agent:main:openai-oauth-smoke \
  --message "Reply exactly: OK OpenAI OAuth ready" \
  --timeout 120 \
  --json
```

Expected validation points:

```text
Gateway health: {"ok":true,"status":"live"}
Model: openai/gpt-5.5 with OpenAI auth usable
MCP doctor: engram: ok
MCP probe: engram: 15 tools
Agent smoke: OK OpenAI OAuth ready
Discord sessions after reset: 0 keys matching agent:main:discord:*
```

After those checks pass, send a fresh Discord message such as:

```text
¿Qué herramientas de memoria puedes usar ahora? ¿Puedes guardar una memoria fake y buscarla?
```

Keep the smoke content fake. Do not save private Discord IDs, tokens, screenshots, raw transcripts, or private payloads as evidence.

## Security notes

- `--auth token` is required for the OpenClaw gateway.
- Host ports are bound to `127.0.0.1` only.
- Example `change-me-*` values are not secrets; replace them before real use.
- Do not commit `.env`, Docker volume exports, Discord tokens, Buffer tokens, or real Engram memory.
