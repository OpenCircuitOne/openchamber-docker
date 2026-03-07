# openchamber-docker

Docker image for [OpenChamber](https://github.com/btriapitsyn/openchamber) — installs `@openchamber/web` directly from npm. No local source clone required.

## Image

```
ghcr.io/opencircuitone/openchamber-docker:latest
```

## Quick Start

Run this one-liner — it walks you through an interactive setup, generates `docker-compose.yml` from your answers, and starts the container:

```bash
curl -fsSL https://raw.githubusercontent.com/OpenCircuitOne/openchamber-docker/main/setup.sh | bash
```

The script will ask for:
- **Install directory** (default: `openchamber`)
- **Host port** (default: `5000`)
- **UI password** (`UI_PASSWORD`)
- **Cloudflare Tunnel** mode (`CF_TUNNEL`: `false` / `true` / `qr` / `password`)
- **oh-my-opencode** toggle (`OH_MY_OPENCODE`, default enabled)
- **External OpenCode host** (`OPENCODE_HOST`, optional)
- **Skip auto-starting OpenCode** (`OPENCODE_SKIP_START`)

Then open http://localhost:5000 (or the port you chose).

## Manual Setup

If you prefer to do it step by step:

```bash
mkdir openchamber && cd openchamber
curl -fsSL https://raw.githubusercontent.com/OpenCircuitOne/openchamber-docker/main/docker-compose.yml -o docker-compose.yml
mkdir -p data/openchamber data/opencode/share data/opencode/state data/opencode/config data/ssh workspaces
chown -R 1000:1000 data/ workspaces/
docker compose up -d
```

## Environment Variables

| Variable | Description |
|---|---|
| `UI_PASSWORD` | Set a password for the UI |
| `CF_TUNNEL` | Enable Cloudflare Tunnel (`true` / `qr` / `password`) |
| `OH_MY_OPENCODE` | Enable oh-my-opencode integration (`true` for full, `slim` for oh-my-opencode-slim) |
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

## Managing the Container

```bash
cd openchamber

# View logs
docker compose logs -f

# Stop
docker compose down

# Update to latest image
docker compose pull && docker compose up -d
```

## Building Locally

```bash
docker build -t openchamber .
docker run -p 5000:5000 openchamber
```