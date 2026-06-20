# Public vs private boundaries

Use this repository as the public source of truth for code, docs, and planning. Keep runtime state and sensitive data out of git.

For detailed rules on secrets, retention, exports, fixtures, incidents, and PR hygiene, see `docs/security/data-handling.md`. For Discord request classification and persistence targets, see `docs/architecture/openclaw-artifact-classification.md`.

## Public in the repository

- `README.md`
- `openspec/`
- `docs/adr/`
- `docs/architecture/`
- `docs/project/`
- `skills/`
- GitHub issue and PR templates
- GitHub issues and GitHub Project metadata
- Sample env variable names in `.env.example`
- Fake fixtures created for tests or examples
- Sanitized public contracts for artifact classification, persistence targets, and runtime capability boundaries

## Private outside the repository

- `.env` with real tokens and URLs
- Discord bot token and real guild/channel IDs unless intentionally public
- OpenClaw gateway token
- Engram Cloud token, admin token, JWT secret, and Postgres password
- Buffer access token and account identifiers unless intentionally public
- Engram access tokens and real memory content
- Private context profiles such as writing style, brand voice, audience, and publication rules
- Global/category/channel profile bindings, overrides, and disabled binding metadata
- Private filesystem paths, browser session state, connector credentials, and capability config
- Docker volumes such as `openclaw-home` and `engram-postgres`
- Host-specific logs, transcripts, screenshots, and exported memory snapshots

## Review rules

| Data type | Allowed in PRs? | Notes |
|---|---|---|
| Docs and schemas | Yes | Preferred for design and planning |
| Skill prompts without secrets | Yes | Keep them generic and reviewable |
| Fake/demo fixtures | Yes | Use fake IDs, fake names, fake metrics, and safe URLs only |
| Real memory content | No | Store in Engram only until sanitized/promoted |
| Private profiles and scope bindings | No | Keep profile content and real bindings in private runtime state; use fake placeholders in docs/tests |
| Capability credentials/config | No | Public docs may describe the capability contract, but real config belongs in private runtime state or secrets |
| API tokens or URLs with secrets | No | Use `.env` or a secret manager |
| Generated operational state | No | Keep in volumes or ignored directories |
| Raw exports/backups | No | Never commit Engram exports, SQL dumps, or volume snapshots |

## Practical checklist

- Do not commit `.env`.
- Do not commit runtime dumps from OpenClaw or Engram.
- Do not commit raw Engram exports, SQL dumps, or volume snapshots.
- Do not use runtime volumes as if they were public fixtures.
- Do not put private brand strategy in public markdown unless intentionally shareable.
- Do not commit real private context profiles or scope bindings; commit only sanitized contract examples.
- Separate public capability contracts from private capability enablement/configuration.
- Prefer sanitized examples when documenting workflows.
- Keep private operational learnings in Engram until they are summarized and promoted.
- Follow `docs/security/data-handling.md` before onboarding real memory.
