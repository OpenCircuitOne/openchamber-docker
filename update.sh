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

# Extract the value of a YAML key from docker-compose.yml.
# Handles both quoted and unquoted values, strips inline comments,
# and ignores commented-out lines (returns "").
# Usage: compose_get <key>
compose_get() {
  local key="$1"
  # Match un-commented lines only; strip inline comments, then surrounding quotes
  grep -E "^[[:space:]]+${key}:" docker-compose.yml 2>/dev/null \
    | sed -E "s/^[[:space:]]+${key}:[[:space:]]*//" \
    | sed -E 's/[[:space:]]+#.*$//' \
    | sed -E 's/^"(.*)"$/\1/' \
    | sed -E "s/^'(.*)'$/\1/" \
    | head -1 \
    || true
}

# ──────────────────────────────────────────────────────────────────────────────
# Welcome banner
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          OpenChamber In-Place Update                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Verify we are inside a valid openchamber installation directory
# ──────────────────────────────────────────────────────────────────────────────
if [ ! -f "docker-compose.yml" ]; then
  echo "Error: docker-compose.yml not found in the current directory." >&2
  echo "Run this script from inside your openchamber installation directory." >&2
  exit 1
fi

if ! grep -q "openchamber-docker" docker-compose.yml 2>/dev/null; then
  echo "Error: docker-compose.yml does not appear to be an openchamber installation." >&2
  exit 1
fi

echo "Found openchamber installation in: $(pwd)"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Read current settings from docker-compose.yml
# ──────────────────────────────────────────────────────────────────────────────
# Port: extract from "- "PORT:5000"" mapping
CURRENT_PORT=$(grep -E '^\s+-\s+"[0-9]+:5000"' docker-compose.yml 2>/dev/null \
  | sed -E 's/.*"([0-9]+):5000".*/\1/' | head -1 || true)
CURRENT_PORT="${CURRENT_PORT:-5000}"

CURRENT_UI_PASSWORD=$(compose_get "UI_PASSWORD")
CURRENT_CF_TUNNEL=$(compose_get "CF_TUNNEL")
CURRENT_CF_TUNNEL="${CURRENT_CF_TUNNEL:-false}"
CURRENT_OH_MY_OPENCODE=$(compose_get "OH_MY_OPENCODE")
CURRENT_OH_MY_OPENCODE="${CURRENT_OH_MY_OPENCODE:-false}"
CURRENT_OPENCODE_HOST=$(compose_get "OPENCODE_HOST")
CURRENT_OPENCODE_SKIP_START=$(compose_get "OPENCODE_SKIP_START")
CURRENT_OPENCODE_SKIP_START="${CURRENT_OPENCODE_SKIP_START:-false}"
CURRENT_AUTO_UPGRADE=$(compose_get "AUTO_UPGRADE")
CURRENT_AUTO_UPGRADE="${CURRENT_AUTO_UPGRADE:-true}"

echo "── Current configuration ────────────────────────────────"
echo "  Host port          : ${CURRENT_PORT}"
echo "  UI password        : ${CURRENT_UI_PASSWORD:-(not set)}"
echo "  CF_TUNNEL          : ${CURRENT_CF_TUNNEL}"
echo "  OH_MY_OPENCODE     : ${CURRENT_OH_MY_OPENCODE}"
echo "  OPENCODE_HOST      : ${CURRENT_OPENCODE_HOST:-(built-in)}"
echo "  OPENCODE_SKIP_START: ${CURRENT_OPENCODE_SKIP_START}"
echo "  AUTO_UPGRADE       : ${CURRENT_AUTO_UPGRADE}"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Ask whether to reconfigure
# ──────────────────────────────────────────────────────────────────────────────
RECONFIGURE=$(ask_bool "Reconfigure settings? (No = keep current config)" "false")

if [ "$RECONFIGURE" = "true" ]; then
  echo "" >/dev/tty
  echo "Press Enter to keep the current value shown in [brackets]." >/dev/tty
  echo "" >/dev/tty

  PORT=$(ask_tty "Host port" "${CURRENT_PORT}")
  if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: port must be a number." >&2
    exit 1
  fi

  echo "" >/dev/tty
  echo "── Security ─────────────────────────────────────────────" >/dev/tty
  UI_PASSWORD=$(ask_tty "UI password (leave blank to disable)" "${CURRENT_UI_PASSWORD}")

  echo "" >/dev/tty
  echo "── Cloudflare Tunnel ────────────────────────────────────" >/dev/tty
  echo "  Options: false (disabled) | true | qr | password" >/dev/tty
  CF_TUNNEL=$(ask_tty "CF_TUNNEL" "${CURRENT_CF_TUNNEL}")

  echo "" >/dev/tty
  echo "── OpenCode settings ────────────────────────────────────" >/dev/tty
  echo "  Options: false (disabled) | true (full) | slim" >/dev/tty
  OH_MY_OPENCODE=$(ask_tty "OH_MY_OPENCODE variant" "${CURRENT_OH_MY_OPENCODE}")
  case "$OH_MY_OPENCODE" in
    true|false|slim) ;;
    *)
      echo "Error: OH_MY_OPENCODE must be 'true', 'false', or 'slim'." >&2
      exit 1
      ;;
  esac

  OPENCODE_HOST=$(ask_tty "External OpenCode server URL (leave blank to use built-in)" "${CURRENT_OPENCODE_HOST}")
  OPENCODE_SKIP_START=$(ask_bool "Skip auto-starting OpenCode" "${CURRENT_OPENCODE_SKIP_START}")

  echo "" >/dev/tty
  echo "── Auto-upgrade ─────────────────────────────────────────" >/dev/tty
  AUTO_UPGRADE=$(ask_bool "Auto-upgrade openchamber+opencode on container start" "${CURRENT_AUTO_UPGRADE}")

  echo ""
  echo "── New configuration ────────────────────────────────────"
  echo "  Host port          : ${PORT}"
  echo "  UI password        : ${UI_PASSWORD:-(not set)}"
  echo "  CF_TUNNEL          : ${CF_TUNNEL}"
  echo "  OH_MY_OPENCODE     : ${OH_MY_OPENCODE}"
  echo "  OPENCODE_HOST      : ${OPENCODE_HOST:-(built-in)}"
  echo "  OPENCODE_SKIP_START: ${OPENCODE_SKIP_START}"
  echo "  AUTO_UPGRADE       : ${AUTO_UPGRADE}"
  echo ""

  CONFIRM=$(ask_bool "Apply this configuration?" "true")
  if [ "$CONFIRM" != "true" ]; then
    echo "Aborted."
    exit 1
  fi
else
  PORT="${CURRENT_PORT}"
  UI_PASSWORD="${CURRENT_UI_PASSWORD}"
  CF_TUNNEL="${CURRENT_CF_TUNNEL}"
  OH_MY_OPENCODE="${CURRENT_OH_MY_OPENCODE}"
  OPENCODE_HOST="${CURRENT_OPENCODE_HOST}"
  OPENCODE_SKIP_START="${CURRENT_OPENCODE_SKIP_START}"
  AUTO_UPGRADE="${CURRENT_AUTO_UPGRADE}"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Ensure data directories exist with correct ownership
# ──────────────────────────────────────────────────────────────────────────────
echo "[update] ensuring data directories exist..."
mkdir -p \
  data/openchamber \
  data/opencode/share \
  data/opencode/state \
  data/opencode/config \
  data/ssh \
  workspaces

echo "[update] fixing ownership (uid/gid 1000)..."
if ! chown -R 1000:1000 data/ workspaces/ 2>/dev/null; then
  echo "[update] warning: could not chown data/workspaces — try re-running with sudo if you encounter permission errors"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Pull the latest Docker image
# ──────────────────────────────────────────────────────────────────────────────
echo "[update] pulling latest Docker image..."
if ! docker compose pull; then
  echo "Error: failed to pull the latest Docker image." >&2
  echo "Ensure Docker is running and you have permission to access the Docker daemon." >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Regenerate docker-compose.yml
# ──────────────────────────────────────────────────────────────────────────────
echo "[update] writing docker-compose.yml..."

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

if [ "$AUTO_UPGRADE" = "false" ]; then
  ENV_BLOCK="${ENV_BLOCK}      AUTO_UPGRADE: \"false\"\n"
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
# Restart the container
# ──────────────────────────────────────────────────────────────────────────────
echo "[update] restarting openchamber..."
if ! docker compose up -d; then
  echo "Error: failed to start the container." >&2
  echo "Check for port conflicts or Docker daemon issues with: docker compose logs" >&2
  exit 1
fi

echo ""
echo "✅ Done! OpenChamber is up-to-date and running at http://localhost:${PORT}"
echo "   To view logs: docker compose logs -f"
echo "   To stop:      docker compose down"
