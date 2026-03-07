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
| `AUTO_UPGRADE` | Auto-upgrade `@openchamber/web` and `opencode-ai` to latest on every container start (default: `true`; set to `false` to disable, e.g. in air-gapped environments) |

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

# Restart (automatically upgrades openchamber and opencode to latest on startup)
docker compose restart

# Update to latest image (also pulls any new base image changes)
docker compose pull && docker compose up -d
```

> **Auto-upgrade**: By default, every time the container starts (`docker compose up`,
> `docker compose restart`, etc.) it checks whether `@openchamber/web` and `opencode-ai`
> were last upgraded more than 24 hours ago and, if so, runs
> `npm install -g @openchamber/web opencode-ai` to fetch the latest versions from npm.
> This means a simple `docker compose restart` is all you need to get the newest release.
> Set `AUTO_UPGRADE=false` in your `docker-compose.yml` environment to opt out.

## Updating an Existing Installation

Run this one-liner from inside your existing openchamber directory to update everything
(Docker image, `docker-compose.yml` format, data directories) to the latest:

```bash
curl -fsSL https://raw.githubusercontent.com/OpenCircuitOne/openchamber-docker/main/update.sh | bash
```

The script will:
1. Detect your current configuration (port, password, feature flags) and use it as defaults
2. Optionally let you reconfigure any settings interactively
3. Pull the latest Docker image
4. Regenerate `docker-compose.yml` with the current format (picks up any new options added to the repo)
5. Ensure data directories exist with correct ownership
6. Restart the container

## Building Locally

```bash
docker build -t openchamber .
docker run -p 5000:5000 openchamber
```