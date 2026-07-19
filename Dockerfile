# Production Dockerfile for t3code (https://github.com/pingdotgg/t3code)
# Includes: Node.js 24, pnpm, git, openssh-client, and the OpenCode CLI.

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Builder
# ─────────────────────────────────────────────────────────────────────────────
FROM node:24-bookworm AS builder

# Build dependencies for native npm modules (node-pty, esbuild, etc.)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 \
       make \
       g++ \
       git \
       ca-certificates \
       curl \
    && rm -rf /var/lib/apt/lists/*

# Enable pnpm 11.10.0 (matches the repo's packageManager field)
RUN corepack enable && corepack prepare pnpm@11.10.0 --activate

# Which repository ref to build
ARG T3CODE_REPO=https://github.com/pingdotgg/t3code.git
ARG T3CODE_VERSION=main

WORKDIR /app

# Clone the source. Using a shallow clone keeps the image context small.
RUN git clone --depth 1 --branch "${T3CODE_VERSION}" "${T3CODE_REPO}" .

# Install dependencies. The lockfile is present in the repo.
RUN pnpm install --frozen-lockfile

# Build the full workspace: contracts → packages → web → server.
RUN pnpm run build

# Create a clean, production-only deployment bundle for the server package.
# The server package is named "t3" in apps/server/package.json.
# --legacy is used because the workspace may not set inject-workspace-packages=true.
RUN pnpm --filter=t3 --prod deploy --legacy /app/deploy

# The server serves the built web app from a path relative to its own dist
# directory. The deploy target is /app/deploy, so the server expects web dist
# at /app/deploy/web/dist (../../web/dist relative to dist/bin.mjs).
RUN mkdir -p /app/deploy/web && \
    cp -r /app/apps/web/dist /app/deploy/web/dist

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Runtime
# ─────────────────────────────────────────────────────────────────────────────
FROM node:24-bookworm-slim AS runtime

# Runtime system dependencies:
#   git              - required by t3code for VCS operations
#   openssh-client   - required for SSH-based git remotes
#   ca-certificates  - required by curl and the application
#   curl             - required to install OpenCode
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       openssh-client \
       ca-certificates \
       curl \
    && rm -rf /var/lib/apt/lists/*

# OpenCode version — tracked by Renovate
ARG OPENCODE_VERSION=1.18.3

# Install OpenCode directly. Detect architecture and download the correct build.
# Using direct download avoids the install script's $HOME/.opencode directory,
# which causes permission issues for the non-root t3 user.
RUN arch=$(uname -m) && \
    case "$arch" in \
      x86_64)  arch="x64" ;; \
      aarch64) arch="arm64" ;; \
    esac && \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${arch}.tar.gz" \
      | tar -xz -C /usr/local/bin opencode && \
    chmod 755 /usr/local/bin/opencode && \
    opencode --version

# Create a non-root user for running the server.
RUN groupadd --system t3 && \
    useradd --system --create-home --gid t3 t3

WORKDIR /app

# Copy the production bundle from the builder stage.
COPY --from=builder --chown=t3:t3 /app/deploy ./

# Set the runtime environment.
ENV NODE_ENV=production
ENV T3CODE_HOME=/data

# Create the data directory and give the t3 user ownership.
RUN mkdir -p /data && chown t3:t3 /data

# Drop to the non-root user before starting the server.
USER t3

# SQLite data and other runtime state are persisted here.
VOLUME /data

# Default port (overridable at runtime via T3CODE_PORT).
EXPOSE 3773

# The server binary is a Node.js script. Using ENTRYPOINT + CMD keeps the
# image flexible: `docker run t3code` starts production mode, and users can
# override the subcommand (e.g. `docker run t3code serve`).
ENTRYPOINT ["node", "dist/bin.mjs"]
CMD ["start"]

# ─────────────────────────────────────────────────────────────────────────────
# Fallback note (kept here for reference):
# If `pnpm deploy --filter=t3` does not work with the monorepo layout, replace
# the deploy step with a direct copy of the built workspace and change the
# ENTRYPOINT to `apps/server/dist/bin.mjs`:
#
#   COPY --from=builder --chown=t3:t3 /app/node_modules ./node_modules
#   COPY --from=builder --chown=t3:t3 /app/apps ./apps
#   COPY --from=builder --chown=t3:t3 /app/packages ./packages
#   COPY --from=builder --chown=t3:t3 /app/pnpm-workspace.yaml ./pnpm-workspace.yaml
#   COPY --from=builder --chown=t3:t3 /app/package.json ./package.json
#
#   ENTRYPOINT ["node", "apps/server/dist/bin.mjs"]
# ─────────────────────────────────────────────────────────────────────────────
