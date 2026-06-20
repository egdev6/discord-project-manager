# Data handling rules

Use this runbook before onboarding any real Discord server, brand, Buffer account, or Engram memory.

## Quick path

1. Keep real secrets in `.env` or a host secret store, never in git.
2. Treat Docker volumes, Engram exports, and runtime logs as private by default.
3. Use fake/demo fixtures only in public docs, tests, and screenshots.
4. If data is exposed, stop sharing, rotate secrets, and document the incident privately first.

## Secret handling

| Secret or identifier | Public in repo? | Where it belongs | Notes |
|---|---|---|---|
| `DISCORD_BOT_TOKEN` | No | `.env` or secret manager | Rotate immediately if exposed. |
| Discord guild IDs | Usually no | `.env`, runtime config, or private notes | Treat real guild/channel mappings as private unless intentionally public. |
| Discord channel IDs | No | Runtime memory/config only | Do not publish screenshots or logs with private channel IDs unless sanitized. |
| `OPENCLAW_GATEWAY_TOKEN` | No | `.env` or secret manager | Required for token-auth Gateway access. |
| `ENGRAM_CLOUD_TOKEN` | No | `.env` or secret manager | Client bearer token for Engram Cloud. |
| `ENGRAM_CLOUD_ADMIN` | No | `.env` or secret manager | Admin-only secret; never share with clients. |
| `ENGRAM_JWT_SECRET` | No | `.env` or secret manager | Must be strong and private. |
| `POSTGRES_PASSWORD` | No | `.env` or secret manager | Treat DB credentials as production secrets once real memory exists. |
| `BUFFER_ACCESS_TOKEN` / `BUFFER_API_KEY` | No | `.env` or secret manager | Grants Buffer API access; current public API should not be assumed to expose LinkedIn/X analytics metrics. |
| `BUFFER_ACCOUNT_ID` | Usually no | `.env` or private config | Keep private unless intentionally documented for a public demo. |
| `.env.example` placeholders | Yes | git | Names and fake `change-me-*` values only. |

## Public vs private storage

| Storage location | Default classification | Rule |
|---|---|---|
| `README.md`, `docs/`, `openspec/`, `skills/` | Public | Keep reusable docs, ADRs, contracts, and fake examples only. |
| `.env` | Private | Never commit. Real tokens and URLs only. |
| Docker volumes (`openclaw-home`, `engram-postgres`) | Private | Runtime state and real memory live here. |
| Engram memory | Private by default | Operational memory until promoted into a repo artifact. |
| Private context profiles and scope bindings | Private | Store profile definitions, bindings, overrides, and audit metadata outside git. |
| Capability config and connector credentials | Private | Keep filesystem paths, browser/session state, and connector tokens in private runtime config or a secret store. |
| Engram exports/backups | Private | Never commit raw exports or database dumps. |
| Logs, transcripts, screenshots | Private by default | Sanitize before sharing or attaching to issues/PRs. |

## Private runtime state

Private runtime state is any durable operational state that OpenClaw needs but the public repo must not contain.

| State | Public in repo? | Storage expectation |
|---|---|---|
| Writing style, brand voice, audience, and publication-rule profiles | No | Private runtime state such as Engram/Postgres or an explicitly private OpenClaw workspace location. |
| Global/category/channel profile bindings | No | Private runtime state with provenance and backup coverage. |
| Capability permissions and private config | Usually no | Private runtime config; public docs may describe the contract with fake examples only. |
| External connector credentials and OAuth/session state | No | `.env`, secret manager, or provider-specific private session store. |
| Sanitized fixture placeholders | Yes | Repo fixtures/docs when marked fake/demo/sanitized. |

Private profiles are reusable context, not repo-backed skills. Public docs may describe profile shapes and fake examples, but real profile content and real scope bindings stay private.

## Retention and export rules

- Treat all raw Engram exports, sync archives, SQL dumps, private profile backups, and volume snapshots as private.
- Never commit raw Engram exports, Postgres dumps, Discord transcripts, or Buffer response payloads.
- Promote only sanitized, durable knowledge into repo artifacts:
  - architecture decisions;
  - approved namespace conventions;
  - reusable skill behavior;
  - review-facing summaries;
  - public runbooks.
- Keep transient runtime memory in Engram unless it becomes durable project knowledge.
- Disposable smoke-test volumes may be deleted with `docker compose down -v` **only** when they do not contain real memory.
- If a volume contains real memory, require backup plus explicit human approval before reset or deletion.
- When exporting for backup, keep files outside the repo and name them as private operational assets.
- Backup/export must preserve private profile definitions, scope bindings, overrides, disabled bindings, and audit metadata when those features are enabled.
- Restore validation must prove shared profile references remain shared after restore instead of silently cloning profile content.

## Current recovery path

The dedicated contract is `docs/operations/private-runtime-backup-restore.md`. Until full live restore validation lands, the operator-owned recovery path is conservative:

1. Stop runtime writes before backup or restore.
2. Export private runtime storage outside the repo.
3. Restore only into a private runtime environment.
4. Re-run sanitized readback checks before resuming writes.

For the current Docker Compose baseline, private runtime state is stored in named volumes such as `engram-postgres` and `openclaw-home`. A sanitized operator backup rehearsal can use commands shaped like:

```bash
# Postgres/Engram private backup; write output outside the repo.
docker compose exec -T postgres pg_dump \
  -U "${POSTGRES_USER:-engram}" \
  "${POSTGRES_DB:-engram_cloud}" \
  > ../private-backups/engram-demo.sql

# OpenClaw workspace volume backup; write output outside the repo.
docker run --rm \
  -v discord-project-manager_openclaw-home:/source:ro \
  -v "$PWD/../private-backups:/backup" \
  alpine tar czf /backup/openclaw-home-demo.tgz -C /source .
```

A sanitized restore rehearsal must happen only in an isolated private rehearsal environment, never directly into the active Compose project or active named volumes. Use commands shaped like:

```bash
# Start or target an isolated rehearsal project, not the active runtime project.
REHEARSAL_PROJECT=discord-project-manager-restore-rehearsal

# Restore Postgres/Engram into the rehearsal database/container only.
cat ../private-backups/engram-demo.sql | docker compose -p "$REHEARSAL_PROJECT" exec -T postgres psql \
  -U "${POSTGRES_USER:-engram}" \
  "${POSTGRES_DB:-engram_cloud}"

# Restore OpenClaw workspace into the rehearsal volume only.
docker volume create "${REHEARSAL_PROJECT}_openclaw-home"
docker run --rm \
  -v "${REHEARSAL_PROJECT}_openclaw-home:/target" \
  -v "$PWD/../private-backups:/backup:ro" \
  alpine sh -lc 'cd /target && tar xzf /backup/openclaw-home-demo.tgz'
```

After restore, run a sanitized readback check before enabling writes again: resolve the same fake profile binding before and after restore, compare only profile refs/bindings/audit metadata, and confirm shared profile references were not duplicated.

These commands are examples of the expected private recovery path, not public evidence. Do not commit generated backups. Formal production RPO/RTO ownership remains future production-readiness work; sanitized restore invariants are validated by `scripts/validate-private-runtime-backup-restore.sh`.

## Fake fixture rules

Use fake/demo data for all public examples unless the content is intentionally public and approved.

Required rules:

- Use `example.invalid` or obviously fake URLs.
- Use fake IDs for guilds, channels, posts, and assets.
- Use fake analytics values or `unknown` when demonstrating metrics.
- Do not use real customer, employee, creator, or community member names.
- Do not include screenshots containing private Discord channels, DMs, brand plans, or analytics dashboards.
- Do not paste real Engram memory entries into docs or PRs.
- Do not paste real writing profiles, brand voice notes, audience profiles, scope bindings, or private connector configuration into docs or PRs.
- Clearly label examples as `fake`, `demo`, or `sanitized`.

## Incident guidance

If private data or secrets are exposed:

1. Stop sharing immediately.
   - Pause pushes, PR updates, screenshots, and exports.
2. Contain the leak.
   - Revoke public links if possible.
   - Remove exposed files from the working tree and future commits.
3. Rotate affected secrets.
   - Discord bot token
   - OpenClaw gateway token
   - Engram Cloud token/admin/JWT secret
   - Postgres password
   - Buffer token
4. Clean git history if the secret reached the repo.
   - Remove the secret from current files.
   - Rewrite history if required.
   - Force-push only with explicit maintainer approval.
5. Assess runtime data.
   - Decide whether Docker volumes, Engram exports, or logs also need purge/rotation.
6. Document privately.
   - Record what leaked, where, when, what was rotated, and remaining risk.
7. Promote sanitized lessons.
   - If the incident teaches a reusable rule, add that rule to repo docs without reproducing the secret or private data.

## PR author checklist

Before opening a PR, confirm:

- [ ] No `.env`, tokens, or real URLs with embedded secrets are included.
- [ ] No Docker volume exports, SQL dumps, or raw Engram exports are included.
- [ ] Examples use fake IDs, fake names, fake metrics, and safe URLs.
- [ ] Screenshots/logs are sanitized or omitted.
- [ ] Durable decisions were promoted to docs/ADRs instead of copied as raw memory.
- [ ] Any cleanup/reset command is clearly labeled as safe only for disposable smoke environments.

## Related docs

- `docs/operations/private-runtime-backup-restore.md`
- `docs/architecture/openclaw-artifact-classification.md`
- `docs/architecture/public-private-boundaries.md`
- `docs/adr/0002-engram-namespace-contract.md`
- `docs/operations/docker-runtime.md`
