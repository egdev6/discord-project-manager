#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found on PATH: $1"
}

require_cmd grep
require_cmd docker

COMPOSE_PATH="docker-compose.yml"
DOCKERFILE_PATH="docker/openclaw/Dockerfile"
ENV_EXAMPLE_PATH=".env.example"
DOC_PATH="docs/operations/runtime-version-baseline.md"
RUNTIME_DOC_PATH="docs/operations/docker-runtime.md"
RELEASE_NOTES_PATH="docs/releases/v0.2.0.md"

OPENCLAW_DIGEST="ghcr.io/openclaw/openclaw@sha256:9f55f0cb32b2925a983f40726440189b8f422ec61ae2a0fb0cf90403cf6d63d7"
ENGRAM_DIGEST="ghcr.io/gentleman-programming/engram@sha256:f9b0d7c24f48076a4c836a1099b8351215bf902dcba7ae02222f2c431f2def38"
GENTLE_VERSION="1.37.0"
POSTGRES_IMAGE="postgres@sha256:e013e867e712fec275706a6c51c966f0bb0c93cfa8f51000f85a15f9865a28cb"

for path in "$COMPOSE_PATH" "$DOCKERFILE_PATH" "$ENV_EXAMPLE_PATH" "$DOC_PATH" "$RUNTIME_DOC_PATH" "$RELEASE_NOTES_PATH"; do
  [[ -f "$path" ]] || fail "required path not found: $path"
done

for path in "$COMPOSE_PATH" "$DOCKERFILE_PATH" "$ENV_EXAMPLE_PATH" "$DOC_PATH" "$RELEASE_NOTES_PATH"; do
  grep -F "$OPENCLAW_DIGEST" "$path" >/dev/null || fail "$path missing OpenClaw digest baseline"
  grep -F "$ENGRAM_DIGEST" "$path" >/dev/null || fail "$path missing Engram digest baseline"
done

grep -F "ARG GENTLE_AI_VERSION=$GENTLE_VERSION" "$DOCKERFILE_PATH" >/dev/null || fail "Dockerfile missing Gentle-AI pinned version"
grep -F "Gentle-AI binary" "$DOC_PATH" >/dev/null || fail "baseline doc missing Gentle-AI entry"
grep -F "$GENTLE_VERSION" "$DOC_PATH" >/dev/null || fail "baseline doc missing Gentle-AI version"
grep -F "$POSTGRES_IMAGE" "$COMPOSE_PATH" >/dev/null || fail "Compose missing Postgres baseline"
grep -F "POSTGRES_IMAGE=$POSTGRES_IMAGE" "$ENV_EXAMPLE_PATH" >/dev/null || fail ".env.example missing Postgres digest baseline"
grep -F "$POSTGRES_IMAGE" "$DOC_PATH" >/dev/null || fail "baseline doc missing Postgres image"
grep -F "Runtime component baseline" "$RELEASE_NOTES_PATH" >/dev/null || fail "release notes missing runtime baseline section"
grep -F "$GENTLE_VERSION" "$RELEASE_NOTES_PATH" >/dev/null || fail "release notes missing Gentle-AI version"
grep -F "$POSTGRES_IMAGE" "$RELEASE_NOTES_PATH" >/dev/null || fail "release notes missing Postgres image"

grep -F "OPENCLAW_BASE_IMAGE=<intentional image tag or digest>" "$DOC_PATH" >/dev/null || fail "baseline doc missing override policy"
grep -F "Operators may override these pinned defaults intentionally" "$RELEASE_NOTES_PATH" >/dev/null || fail "release notes missing override caveat"
grep -F "validate-runtime-version-baseline.sh" "$RUNTIME_DOC_PATH" >/dev/null || fail "runtime docs missing baseline validator reference"

if grep -E 'openclaw/openclaw:latest|gentleman-programming/engram:latest|postgres:16-alpine' "$COMPOSE_PATH" "$DOCKERFILE_PATH" "$ENV_EXAMPLE_PATH" >/dev/null; then
  fail "runtime defaults must not use moving latest tags"
fi

rendered_config="$(docker compose config)"
for required in "$OPENCLAW_DIGEST" "$ENGRAM_DIGEST" "$POSTGRES_IMAGE"; do
  grep -F "$required" <<<"$rendered_config" >/dev/null || fail "rendered docker compose config missing pinned baseline: $required"
done
if grep -E 'openclaw/openclaw:latest|gentleman-programming/engram:latest|postgres:16-alpine' <<<"$rendered_config" >/dev/null; then
  fail "rendered docker compose config uses moving latest tags; update .env overrides to pinned digests"
fi

echo "Validated runtime version baseline."
echo "OpenClaw: $OPENCLAW_DIGEST"
echo "Engram: $ENGRAM_DIGEST"
echo "Gentle-AI: $GENTLE_VERSION"
echo "Postgres: $POSTGRES_IMAGE"
