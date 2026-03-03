# openchamber-docker

Docker image for [OpenChamber](https://github.com/btriapitsyn/openchamber) — installs `@openchamber/web` directly from npm. No local source clone required.

## Image

```
ghcr.io/mcmelontv/openchamber-docker:latest
```

## Quick Start

```bash
# Pull and run with docker compose
curl -O https://raw.githubusercontent.com/McMelonTV/openchamber-docker/main/docker-compose.yml
docker compose up -d
```

Then open http://localhost:5000.

## Environment Variables

| Variable | Description |
|---|---|
| `UI_PASSWORD` | Set a password for the UI |
| `CF_TUNNEL` | Enable Cloudflare Tunnel (`true` / `qr` / `password`) |
| `OH_MY_OPENCODE` | Enable oh-my-opencode integration (`true`) |
| `OPENCODE_HOST` | Connect to an external OpenCode server (e.g. `http://172.17.0.1:4096`) |
| `OPENCODE_SKIP_START` | Skip auto-starting OpenCode (`true`) |

## Volumes

| Path | Description |
|---|---|
| `/home/openchamber/.config/openchamber` | OpenChamber config |
| `/home/openchamber/.local/share/opencode` | OpenCode data |
| `/home/openchamber/.local/state/opencode` | OpenCode state |
| `/home/openchamber/.config/opencode` | OpenCode config |
| `/home/openchamber/.ssh` | SSH keys |
| `/home/openchamber/workspaces` | Your project workspaces |

## Building Locally

```bash
docker build -t openchamber .
docker run -p 5000:5000 openchamber
```