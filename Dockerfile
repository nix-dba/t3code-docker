# syntax=docker/dockerfile:1

# Production image for t3code (https://github.com/pingdotgg/t3code).
#
# t3code is installed from the official self-contained release archive, so the
# image needs no source build, pnpm, or Node toolchain. The agent CLIs are
# installed as native binaries.

FROM node:26-bookworm-slim

# Fail a RUN step when any command in a pipe fails (for example, curl | tar).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Versions are tracked by Renovate (see renovate.json).
ARG T3CODE_VERSION=0.1.7
ARG OPENCODE_VERSION=2.2.6
ARG CODEX_VERSION=0.167.0
ARG CLAUDE_CODE_VERSION=2.1.322
ARG IMAGE_SOURCE=""

LABEL org.opencontainers.image.title="t3code" \
      org.opencontainers.image.description="t3code with OpenCode 2, Codex, and Claude Code CLIs" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.version="${T3CODE_VERSION}"

# Runtime dependencies:
#   git              - VCS operations used by t3code and the agent CLIs
#   openssh-client   - SSH-based git remotes
#   ca-certificates  - TLS for curl, git, and the CLIs
#   curl             - CLI downloads
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       openssh-client \
       ca-certificates \
       curl \
    && rm -rf /var/lib/apt/lists/*

# Install t3code from the official self-contained release. The archive contains
# the server, web client, and runtime, so it can run without Node or pnpm.
RUN arch="$(uname -m)" \
    && case "$arch" in \
         x86_64)  arch="x64" ;; \
         aarch64) arch="arm64" ;; \
         *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
       esac \
    && mkdir -p /opt/t3 \
    && curl -fsSL "https://github.com/pingdotgg/t3code/releases/download/v${T3CODE_VERSION}/t3-${T3CODE_VERSION}-linux-${arch}.tar.gz" \
       | tar -xz -C /opt/t3 --strip-components=1 \
    && ln -s /opt/t3/t3 /usr/local/bin/t3 \
    && t3 --version

# OpenCode 2 (native binary).
RUN arch="$(uname -m)" \
    && case "$arch" in \
         x86_64)  arch="x64" ;; \
         aarch64) arch="arm64" ;; \
         *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${arch}.tar.gz" \
       | tar -xz -C /usr/local/bin opencode \
    && chmod 755 /usr/local/bin/opencode \
    && opencode --version

# Codex CLI (native binary). The release asset is named after its target triple,
# so rename it to `codex` during extraction.
RUN arch="$(uname -m)" \
    && case "$arch" in \
         x86_64)  arch="x86_64" ;; \
         aarch64) arch="aarch64" ;; \
         *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/openai/codex/releases/download/rust-v${CODEX_VERSION}/codex-${arch}-unknown-linux-musl.tar.gz" \
       | tar -xz --transform='s|^codex-.*|codex|' -C /usr/local/bin \
    && chmod 755 /usr/local/bin/codex \
    && codex --version

# Claude Code (native binary).
RUN arch="$(uname -m)" \
    && case "$arch" in \
         x86_64)  arch="x64" ;; \
         aarch64) arch="arm64" ;; \
         *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSL "https://downloads.claude.ai/claude-code-releases/${CLAUDE_CODE_VERSION}/linux-${arch}/claude" \
       -o /usr/local/bin/claude \
    && chmod 755 /usr/local/bin/claude \
    && claude --version

# Run as a non-root user. The home directory is /data so CLI credentials
# (OpenCode, Codex, Claude Code) persist in the data volume, including when
# /data is a bind mount.
RUN groupadd --system t3 \
    && mkdir -p /app /data \
    && useradd --system --no-create-home --home-dir /data --gid t3 t3 \
    && chown -R t3:t3 /app /data

WORKDIR /app

ENV NODE_ENV=production \
    HOME=/data \
    T3CODE_HOME=/data \
    T3CODE_HOST=0.0.0.0 \
    T3CODE_PORT=3773

USER t3

# SQLite data, CLI credentials, and other runtime state are persisted here.
VOLUME /data

# Default port (overridable at runtime via T3CODE_PORT).
EXPOSE 3773

# `t3 serve` runs headless and prints pairing details. Users can override the
# command, for example: `docker run t3code --help`.
ENTRYPOINT ["/opt/t3/t3"]
CMD ["serve"]
