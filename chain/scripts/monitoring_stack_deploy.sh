#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  monitoring_stack_deploy.sh

Deploy Prometheus + Grafana monitoring stack on a remote YNX node.

Environment:
  MONITOR_HOST       default: 43.134.23.58
  MONITOR_USER       default: ubuntu
  MONITOR_SSH_KEY    default: $HOME/Downloads/Huang.pem
  REMOTE_REPO        default: ~/YNX
  OPEN_TUNNEL        default: 1 (1=start local SSH tunnel for 3000/9090)

Example:
  ./scripts/monitoring_stack_deploy.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

MONITOR_HOST="${MONITOR_HOST:-43.134.23.58}"
MONITOR_USER="${MONITOR_USER:-ubuntu}"
MONITOR_SSH_KEY="${MONITOR_SSH_KEY:-$HOME/Downloads/Huang.pem}"
REMOTE_REPO="${REMOTE_REPO:-~/YNX}"
OPEN_TUNNEL="${OPEN_TUNNEL:-1}"

echo "[1/3] Deploy monitoring stack on ${MONITOR_USER}@${MONITOR_HOST}"
ssh -o ConnectTimeout=12 -o StrictHostKeyChecking=no -i "$MONITOR_SSH_KEY" "${MONITOR_USER}@${MONITOR_HOST}" \
  "set -e; cd $REMOTE_REPO; git pull --ff-only; cd infra/monitoring; \
   if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then \
     COMPOSE='docker compose'; \
   elif command -v docker-compose >/dev/null 2>&1; then \
     COMPOSE='docker-compose'; \
   else \
     echo 'docker compose not available on remote host' >&2; exit 1; \
   fi; \
   \$COMPOSE up -d; \
   \$COMPOSE ps"

echo "[2/3] Verify Prometheus and Grafana health on remote host"
ssh -o ConnectTimeout=12 -o StrictHostKeyChecking=no -i "$MONITOR_SSH_KEY" "${MONITOR_USER}@${MONITOR_HOST}" \
  "curl -fsSL --max-time 8 http://127.0.0.1:19090/-/healthy >/dev/null && echo prometheus=healthy; \
   curl -fsSL --max-time 8 http://127.0.0.1:13000/api/health | jq -r '.database'"

if [[ "$OPEN_TUNNEL" == "1" ]]; then
  echo "[3/3] Open local tunnel (23000/29090)"
  pkill -f '23000:127.0.0.1:13000' >/dev/null 2>&1 || true
  pkill -f '29090:127.0.0.1:19090' >/dev/null 2>&1 || true
  ssh -fN -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -i "$MONITOR_SSH_KEY" \
    -L 23000:127.0.0.1:13000 -L 29090:127.0.0.1:19090 "${MONITOR_USER}@${MONITOR_HOST}"
  echo "Grafana:   http://127.0.0.1:23000"
  echo "Prometheus:http://127.0.0.1:29090"
fi

echo "DONE"
