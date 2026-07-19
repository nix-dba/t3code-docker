# t3code-docker

Docker image for [t3code](https://github.com/pingdotgg/t3code) — an open-source AI coding agent UI — with [OpenCode](https://opencode.ai) CLI pre-installed.

## Build

```bash
docker build -t t3code:latest .

# Pin a specific t3code release
docker build --build-arg T3CODE_VERSION=v0.0.28 -t t3code:0.0.28 .
```

## Run

```bash
# Headless (prints pairing token to stdout)
docker run -d -p 3773:3773 -e T3CODE_HOST=0.0.0.0 -v t3code-data:/data t3code:latest serve

# Production mode (opens browser — not useful in Docker)
docker run -d -p 3773:3773 -e T3CODE_HOST=0.0.0.0 -v t3code-data:/data t3code:latest
```

Get the pairing token:

```bash
docker logs <container> | grep -i "token\|pairing"
```

## Configuration

All settings are runtime environment variables — no hardcoded URLs.

| Variable | Description | Default |
|----------|-------------|---------|
| `T3CODE_PORT` | Server port | `3773` |
| `T3CODE_HOST` | Bind address | `0.0.0.0` (serve) |
| `T3CODE_HOME` | Data directory | `/data` |
| `T3CODE_LOG_LEVEL` | Log verbosity | `Info` |
| `T3CODE_RELAY_URL` | T3 Connect relay URL | optional |
| `T3CODE_CLERK_PUBLISHABLE_KEY` | Clerk auth key | optional |

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
          env:
            - name: T3CODE_HOST
              value: "0.0.0.0"
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
- `pingdotgg/t3code` — when `T3CODE_VERSION` is set to a semver tag like `v0.0.28`
- `anomalyco/opencode` — opencode CLI versions
- `pnpm` — package manager version
- Node.js base image (auto-detected by Renovate)
