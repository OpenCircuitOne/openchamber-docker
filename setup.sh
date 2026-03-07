#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

# Read a value from /dev/tty so the script works when piped via curl | bash.
# Usage: ask_tty <prompt> <default>
ask_tty() {
  local prompt="$1"
  local default="$2"
  local value
  if [ -n "$default" ]; then
    printf "%s [%s]: " "$prompt" "$default" >/dev/tty
  else
    printf "%s: " "$prompt" >/dev/tty
  fi
  read -r value </dev/tty
  echo "${value:-$default}"
}

# Read a yes/no answer; returns "true" for yes, "false" for no.
# Usage: ask_bool <prompt> <default: true|false>
ask_bool() {
  local prompt="$1"
  local default="$2"
  local hint
  if [ "$default" = "true" ]; then hint="Y/n"; else hint="y/N"; fi
  local raw
  printf "%s [%s]: " "$prompt" "$hint" >/dev/tty
  read -r raw </dev/tty
  raw="${raw:-$default}"
  case "$raw" in
    [Yy]*|true)  echo "true" ;;
    *)           echo "false" ;;
  esac
}

# ──────────────────────────────────────────────────────────────────────────────
# Welcome banner
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           OpenChamber Interactive Setup              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "Press Enter to accept defaults shown in [brackets]."
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 1. Installation directory
# ──────────────────────────────────────────────────────────────────────────────
DIR=$(ask_tty "Install directory" "openchamber")

# ──────────────────────────────────────────────────────────────────────────────
# 2. Host port
# ──────────────────────────────────────────────────────────────────────────────
PORT=$(ask_tty "Host port to expose OpenChamber on" "5000")
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Error: port must be a number." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# 3. UI password
# ──────────────────────────────────────────────────────────────────────────────
echo "" >/dev/tty
echo "── Security ─────────────────────────────────────────────" >/dev/tty
UI_PASSWORD=$(ask_tty "UI password (leave blank to disable)" "")

# ──────────────────────────────────────────────────────────────────────────────
# 4. Cloudflare Tunnel
# ──────────────────────────────────────────────────────────────────────────────
echo "" >/dev/tty
echo "── Cloudflare Tunnel ────────────────────────────────────" >/dev/tty
echo "  Options: false (disabled) | true | qr | password" >/dev/tty
CF_TUNNEL=$(ask_tty "CF_TUNNEL" "false")

# ──────────────────────────────────────────────────────────────────────────────
# 5. oh-my-opencode
# ──────────────────────────────────────────────────────────────────────────────
echo "" >/dev/tty
echo "── OpenCode settings ────────────────────────────────────" >/dev/tty
echo "  Options: false (disabled) | true (full) | slim" >/dev/tty
OH_MY_OPENCODE=$(ask_tty "OH_MY_OPENCODE variant" "true")
case "$OH_MY_OPENCODE" in
  true|false|slim) ;;
  *)
    echo "Error: OH_MY_OPENCODE must be 'true', 'false', or 'slim'." >&2
    exit 1
    ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# 6. External OpenCode host
# ──────────────────────────────────────────────────────────────────────────────
OPENCODE_HOST=$(ask_tty "External OpenCode server URL (leave blank to use built-in)" "")

# ──────────────────────────────────────────────────────────────────────────────
# 7. Skip starting OpenCode
# ──────────────────────────────────────────────────────────────────────────────
OPENCODE_SKIP_START=$(ask_bool "Skip auto-starting OpenCode" "false")

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "── Configuration summary ────────────────────────────────"
echo "  Install directory : ${DIR}"
echo "  Host port         : ${PORT}"
echo "  UI password       : ${UI_PASSWORD:-(not set)}"
echo "  CF_TUNNEL         : ${CF_TUNNEL}"
echo "  OH_MY_OPENCODE    : ${OH_MY_OPENCODE}"
echo "  OPENCODE_HOST     : ${OPENCODE_HOST:-(built-in)}"
echo "  OPENCODE_SKIP_START: ${OPENCODE_SKIP_START}"
echo ""

CONFIRM=$(ask_bool "Proceed with this configuration?" "true")
if [ "$CONFIRM" != "true" ]; then
  echo "Aborted."
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Create directory structure
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "[setup] creating directory '${DIR}'..."
mkdir -p "${DIR}"
cd "${DIR}"

echo "[setup] creating data directories..."
mkdir -p \
  data/openchamber \
  data/opencode/share \
  data/opencode/state \
  data/opencode/config \
  data/ssh \
  workspaces

echo "[setup] fixing ownership (uid/gid 1000)..."
chown -R 1000:1000 data/ workspaces/

# ──────────────────────────────────────────────────────────────────────────────
# Generate docker-compose.yml from collected settings
# ──────────────────────────────────────────────────────────────────────────────
echo "[setup] writing docker-compose.yml..."

# Build the environment block dynamically
ENV_BLOCK=""

if [ -n "$UI_PASSWORD" ]; then
  ENV_BLOCK="${ENV_BLOCK}      UI_PASSWORD: \"${UI_PASSWORD}\"\n"
fi

if [ "$CF_TUNNEL" != "false" ] && [ -n "$CF_TUNNEL" ]; then
  ENV_BLOCK="${ENV_BLOCK}      CF_TUNNEL: \"${CF_TUNNEL}\"\n"
fi

if [ "$OH_MY_OPENCODE" = "true" ] || [ "$OH_MY_OPENCODE" = "slim" ]; then
  ENV_BLOCK="${ENV_BLOCK}      OH_MY_OPENCODE: \"${OH_MY_OPENCODE}\"\n"
fi

if [ -n "$OPENCODE_HOST" ]; then
  ENV_BLOCK="${ENV_BLOCK}      OPENCODE_HOST: \"${OPENCODE_HOST}\"\n"
fi

if [ "$OPENCODE_SKIP_START" = "true" ]; then
  ENV_BLOCK="${ENV_BLOCK}      OPENCODE_SKIP_START: \"true\"\n"
fi

cat > docker-compose.yml <<COMPOSE_EOF
services:
  openchamber:
    image: ghcr.io/opencircuitone/openchamber-docker:latest
    container_name: openchamber
    ports:
      - "${PORT}:5000"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - ./data/openchamber:/home/openchamber/.config/openchamber
      - ./data/opencode/share:/home/openchamber/.local/share/opencode
      - ./data/opencode/state:/home/openchamber/.local/state/opencode
      - ./data/opencode/config:/home/openchamber/.config/opencode
      - ./data/ssh:/home/openchamber/.ssh
      - ./workspaces:/home/openchamber/workspaces
COMPOSE_EOF

if [ -n "$ENV_BLOCK" ]; then
  printf "    environment:\n" >> docker-compose.yml
  printf "%b" "${ENV_BLOCK}" >> docker-compose.yml
fi

printf "    restart: unless-stopped\n" >> docker-compose.yml

# ──────────────────────────────────────────────────────────────────────────────
# Start
# ──────────────────────────────────────────────────────────────────────────────
echo "[setup] starting openchamber..."
docker compose up -d

echo ""
echo "✅ Done! OpenChamber is running at http://localhost:${PORT}"
echo "   To view logs: docker compose -f ${DIR}/docker-compose.yml logs -f"
echo "   To stop:      docker compose -f ${DIR}/docker-compose.yml down"