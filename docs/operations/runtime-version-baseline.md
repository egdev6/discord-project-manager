# Runtime version baseline

This document records the validated runtime component baseline for the v0.2.0 runtime governance work.

The default Docker Compose values pin image digests for repeatable validation. Operators may still override them through `.env`, but an override is an intentional runtime change and should be recorded in release or validation notes.

## Validated defaults

| Component | Default image/version | Notes |
| --- | --- | --- |
| OpenClaw base image | `ghcr.io/openclaw/openclaw@sha256:9f55f0cb32b2925a983f40726440189b8f422ec61ae2a0fb0cf90403cf6d63d7` | Multi-arch index digest inspected from the prior `latest` baseline. |
| Engram image / CLI source | `ghcr.io/gentleman-programming/engram@sha256:f9b0d7c24f48076a4c836a1099b8351215bf902dcba7ae02222f2c431f2def38` | Used both as the Engram Cloud service image and as the `engram` CLI source copied into the OpenClaw image. |
| Gentle-AI binary | `1.37.0` | Installed by `docker/openclaw/Dockerfile` with upstream checksum verification. |
| Postgres | `postgres@sha256:e013e867e712fec275706a6c51c966f0bb0c93cfa8f51000f85a15f9865a28cb` | Multi-arch index digest for the `16-alpine` baseline used by Engram Cloud. |

## Override policy

Operators may override these values in `.env`:

```bash
OPENCLAW_BASE_IMAGE=<intentional image tag or digest>
ENGRAM_IMAGE=<intentional image tag or digest>
POSTGRES_IMAGE=<intentional image tag or digest>
OPENCLAW_RUNTIME_IMAGE=<local image name>
```

Override rules:

- `OPENCLAW_RUNTIME_IMAGE` is the local image name built by this repo; it is not an upstream runtime version.
- Prefer immutable digests for release validation.
- Document any tag/digest override in the related PR, release notes, or private runtime validation report.
- Re-run `docker compose config` and the relevant smoke checks after overriding images.
- Do not claim v0.2.0 baseline validation for unrecorded image overrides.

## Validation commands

```bash
docker compose config
bash scripts/validate-runtime-version-baseline.sh
bash scripts/validate-openclaw-gentle-ai-runtime.sh
```

Runtime smoke checks remain documented in `docs/operations/docker-runtime.md`.
