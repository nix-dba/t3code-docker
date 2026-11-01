# t3code-docker

Docker image for [t3code](https://github.com/pingdotgg/t3code) — an open-source AI coding agent UI — with the following agent CLIs pre-installed:

| CLI | Version | Command |
|-----|---------|---------|
| [OpenCode](https://opencode.ai) | 2.2.5 | `opencode` |
| [Codex](https://github.com/openai/codex) | 0.166.0 | `codex` |
| [Claude Code](https://claude.com/claude-code) | 2.1.316 | `claude` |

The image installs the official self-contained t3code release, so no source build or pnpm toolchain is required. Node.js 26 is included for MCP servers and other Node-based tooling.

## Build

```bash
docker build -t t3code:latest .

# Pin a specific t3code release
docker build --build-arg T3CODE_VERSION=0.1.6 -t t3code:0.1.6 .
```

## Run

```bash
# Headless: prints pairing details to stdout
docker run -d --name t3code -p 3773:3773 -v t3code-data:/data t3code:latest

# Override the command (for example, to inspect the CLI)
docker run --rm t3code:latest --help
```

The image binds to `0.0.0.0` by default so the port mapping works. Get the pairing token from the logs:

```bash
docker logs t3code 2>&1 | grep -iE "pairing|token|http"
```

## Included CLIs

The CLIs are available both to t3code and from an interactive shell:

```bash
docker exec -it t3code opencode --version
docker exec -it t3code codex --version
docker exec -it t3code claude --version
```

Authenticate each CLI once inside the container:

```bash
docker exec -it t3code opencode auth login
docker exec -it t3code codex login
docker exec -it t3code claude   # then run /login
```

Credentials are stored in the `/data` volume (for example `/data/.claude`, `/data/.codex`, and `/data/.local`), so they survive container recreation as long as the volume is kept.

## Configuration

All settings are runtime environment variables — no hardcoded URLs.

| Variable | Description | Default |
|----------|-------------|---------|
| `T3CODE_PORT` | Server port | `3773` |
| `T3CODE_HOST` | Bind address | `0.0.0.0` |
| `T3CODE_HOME` | Data directory | `/data` |
| `T3CODE_LOG_LEVEL` | Log verbosity | `Info` |
| `T3CODE_RELAY_URL` | T3 Connect relay URL | optional |
| `T3CODE_CLERK_PUBLISHABLE_KEY` | Clerk auth key | optional |
| `T3CODE_LAN` | Accept LAN/tailnet connections | unset |

## Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: t3code
spec:
  replicas: 1  # SQLite requires single replica
  selector:
    matchLabels:
      app: t3code
  template:
    metadata:
      labels:
        app: t3code
    spec:
      containers:
        - name: t3code
          image: t3code:latest
          args: ["serve"]
          ports:
            - containerPort: 3773
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: t3code-data
```

## Renovate

This repo includes `renovate.json` for automated dependency updates. It tracks:
- `pingdotgg/t3code` — t3code release versions
- `anomalyco/opencode` — OpenCode CLI versions
- `openai/codex` — Codex CLI versions
- `@anthropic-ai/claude-code` — Claude Code CLI versions
- Node.js base image (auto-detected by Renovate)
