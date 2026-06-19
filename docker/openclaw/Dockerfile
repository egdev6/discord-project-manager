ARG OPENCLAW_BASE_IMAGE=ghcr.io/openclaw/openclaw@sha256:9f55f0cb32b2925a983f40726440189b8f422ec61ae2a0fb0cf90403cf6d63d7
ARG ENGRAM_IMAGE=ghcr.io/gentleman-programming/engram@sha256:f9b0d7c24f48076a4c836a1099b8351215bf902dcba7ae02222f2c431f2def38

FROM ${ENGRAM_IMAGE} AS engram-bin
FROM ${OPENCLAW_BASE_IMAGE}

ARG TARGETARCH
ARG GENTLE_AI_VERSION=1.37.0

USER root
RUN set -eu; \
  case "${TARGETARCH:-amd64}" in \
    amd64|x86_64) gentle_arch="amd64" ;; \
    arm64|aarch64) gentle_arch="arm64" ;; \
    *) echo "unsupported TARGETARCH for gentle-ai: ${TARGETARCH}" >&2; exit 1 ;; \
  esac; \
  tmpdir="$(mktemp -d)"; \
  archive="$tmpdir/gentle-ai_${GENTLE_AI_VERSION}_linux_${gentle_arch}.tar.gz"; \
  checksums="$tmpdir/checksums.txt"; \
  selected_checksum="$tmpdir/selected-checksum.txt"; \
  curl -fsSL "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${GENTLE_AI_VERSION}/gentle-ai_${GENTLE_AI_VERSION}_linux_${gentle_arch}.tar.gz" -o "$archive"; \
  curl -fsSL "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v${GENTLE_AI_VERSION}/checksums.txt" -o "$checksums"; \
  grep " gentle-ai_${GENTLE_AI_VERSION}_linux_${gentle_arch}.tar.gz$" "$checksums" >"$selected_checksum"; \
  sed -i "s# gentle-ai_# $tmpdir/gentle-ai_#" "$selected_checksum"; \
  sha256sum -c "$selected_checksum"; \
  tar -xzf "$archive" -C "$tmpdir"; \
  install -m 0755 "$tmpdir/gentle-ai" /usr/local/bin/gentle-ai; \
  rm -rf "$tmpdir"; \
  gentle-ai --version; \
  mkdir -p /opt/discord-project-manager/skills /opt/discord-project-manager/openclaw-config /usr/local/bin; \
  chown -R node:node /opt/discord-project-manager

COPY --from=engram-bin --chown=root:root /usr/local/bin/engram /usr/local/bin/engram
COPY --chown=node:node skills/ /opt/discord-project-manager/skills/
COPY --chown=node:node openclaw/config/ /opt/discord-project-manager/openclaw-config/
COPY --chown=root:root docker/openclaw/sync-skills.sh /usr/local/bin/discord-project-manager-sync-skills
COPY --chown=root:root docker/openclaw/managed-channel-registry.sh /usr/local/bin/discord-project-manager-managed-registry
COPY --chown=root:root docker/openclaw/discord-approval-guard.sh /usr/local/bin/discord-project-manager-approval-guard
COPY --chown=root:root docker/openclaw/discord-noop-observation.sh /usr/local/bin/discord-project-manager-noop-observation
COPY --chown=root:root docker/openclaw/discord-runtime-boundary-harness.sh /usr/local/bin/discord-project-manager-runtime-boundary-harness
RUN chmod 0755 /usr/local/bin/discord-project-manager-sync-skills /usr/local/bin/discord-project-manager-managed-registry /usr/local/bin/discord-project-manager-approval-guard /usr/local/bin/discord-project-manager-noop-observation /usr/local/bin/discord-project-manager-runtime-boundary-harness /usr/local/bin/engram \
  && engram version

USER node
