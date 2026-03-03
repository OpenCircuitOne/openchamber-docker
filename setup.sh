#!/usr/bin/env bash
set -euo pipefail

REPO="opencircuitone/openchamber-docker"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
DIR="openchamber"

echo "[setup] creating directory '${DIR}'..."
mkdir -p "${DIR}"
cd "${DIR}"

echo "[setup] downloading docker-compose.yml..."
curl -fsSL "${RAW_BASE}/docker-compose.yml" -o docker-compose.yml

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

echo "[setup] starting openchamber..."
docker compose up -d

echo ""
echo "✅ Done! OpenChamber is running at http://localhost:5000"
echo "   To view logs: docker compose -f ${DIR}/docker-compose.yml logs -f"
echo "   To stop:      docker compose -f ${DIR}/docker-compose.yml down"