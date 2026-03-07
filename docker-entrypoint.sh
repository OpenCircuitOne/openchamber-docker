#!/usr/bin/env sh
set -eu

HOME="/home/openchamber"

OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}"
export OPENCODE_CONFIG_DIR

SSH_DIR="${HOME}/.ssh"
SSH_PRIVATE_KEY_PATH="${SSH_DIR}/id_ed25519"
SSH_PUBLIC_KEY_PATH="${SSH_PRIVATE_KEY_PATH}.pub"

mkdir -p "${SSH_DIR}"
if ! chmod 700 "${SSH_DIR}" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${SSH_DIR}, continuing with existing permissions"
fi

if [ ! -f "${SSH_PRIVATE_KEY_PATH}" ] || [ ! -f "${SSH_PUBLIC_KEY_PATH}" ]; then
  if [ ! -w "${SSH_DIR}" ]; then
    echo "[entrypoint] error: ssh key missing and ${SSH_DIR} is not writable" >&2
    exit 1
  fi

  echo "[entrypoint] generating SSH key..."
  ssh-keygen -t ed25519 -N "" -f "${SSH_PRIVATE_KEY_PATH}" >/dev/null
fi

if ! chmod 600 "${SSH_PRIVATE_KEY_PATH}" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${SSH_PRIVATE_KEY_PATH}, continuing"
fi

if ! chmod 644 "${SSH_PUBLIC_KEY_PATH}" 2>/dev/null; then
  echo "[entrypoint] warning: cannot chmod ${SSH_PUBLIC_KEY_PATH}, continuing"
fi

echo "[entrypoint] SSH public key:"
cat "${SSH_PUBLIC_KEY_PATH}"

# Always bind on port 5000
OPENCHAMBER_ARGS="--port 5000"

# Handle UI_PASSWORD environment variable
if [ -n "${UI_PASSWORD:-}" ]; then
  echo "[entrypoint] UI password set, enabling authentication"
  OPENCHAMBER_ARGS="${OPENCHAMBER_ARGS} --ui-password ${UI_PASSWORD}"
fi

# Handle Cloudflare Tunnel (CF_TUNNEL: true/qr/password/full)
if [ -n "${CF_TUNNEL:-}" ] && [ "${CF_TUNNEL:-false}" != "false" ]; then
  echo "[entrypoint] Cloudflare Tunnel enabled (${CF_TUNNEL})"
  OPENCHAMBER_ARGS="${OPENCHAMBER_ARGS} --try-cf-tunnel"

  case "${CF_TUNNEL}" in
  "qr")
    OPENCHAMBER_ARGS="${OPENCHAMBER_ARGS} --tunnel-qr"
    ;;
  "password")
    OPENCHAMBER_ARGS="${OPENCHAMBER_ARGS} --tunnel-password-url"
    ;;
  esac
fi

if [ "${OH_MY_OPENCODE:-false}" = "true" ] || [ "${OH_MY_OPENCODE:-false}" = "slim" ]; then
  if [ "${OH_MY_OPENCODE}" = "slim" ]; then
    OMO_PACKAGE="oh-my-opencode-slim"
    OMO_CMD="oh-my-opencode-slim"
  else
    OMO_PACKAGE="oh-my-opencode"
    OMO_CMD="oh-my-opencode"
  fi

  OMO_CONFIG_FILE="${OPENCODE_CONFIG_DIR}/oh-my-opencode.json"

  if [ ! -f "${OMO_CONFIG_FILE}" ]; then
    echo "[entrypoint] npm installing ${OMO_PACKAGE}..."
    npm install -g "${OMO_PACKAGE}"

    if [ "${OH_MY_OPENCODE}" = "slim" ]; then
      OMO_INSTALL_ARGS="--no-tui --kimi=no --openai=no --anthropic=no --copilot=no --zai-plan=no --antigravity=no --chutes=no --tmux=no"
    else
      OMO_INSTALL_ARGS="--no-tui --claude=no --openai=no --gemini=no --copilot=no --opencode-zen=no --zai-coding-plan=no --kimi-for-coding=no --skip-auth"
    fi

    echo "[entrypoint] ${OMO_CMD} installing..."
    "${OMO_CMD}" install ${OMO_INSTALL_ARGS}
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Auto-upgrade @openchamber/web and opencode-ai to latest from npm
# Runs at most once per day to keep startup fast on rapid restarts.
# Set AUTO_UPGRADE=false to skip entirely (e.g. in air-gapped environments).
# ──────────────────────────────────────────────────────────────────────────────
if [ "${AUTO_UPGRADE:-true}" != "false" ]; then
  UPGRADE_STAMP="${HOME}/.npm-global/.auto-upgrade-timestamp"
  UPGRADE_INTERVAL=86400  # 24 hours in seconds

  _needs_upgrade() {
    [ ! -f "${UPGRADE_STAMP}" ] && return 0
    last=$(cat "${UPGRADE_STAMP}" 2>/dev/null || echo 0)
    now=$(date +%s)
    [ $(( now - last )) -ge ${UPGRADE_INTERVAL} ]
  }

  if _needs_upgrade; then
    echo "[entrypoint] auto-upgrading @openchamber/web and opencode-ai to latest..."
    if npm install -g @openchamber/web opencode-ai; then
      date +%s > "${UPGRADE_STAMP}"
    else
      echo "[entrypoint] warning: auto-upgrade failed, continuing with installed versions"
    fi
  else
    echo "[entrypoint] auto-upgrade skipped (last upgrade less than 24 h ago)"
  fi
fi

echo "[entrypoint] starting openchamber on port 5000..."

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# Use the globally installed openchamber binary (from @openchamber/web npm package)
exec openchamber ${OPENCHAMBER_ARGS}