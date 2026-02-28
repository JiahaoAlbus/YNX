#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_v2_watchdog_systemd.sh

Install YNX v2 watchdog as systemd service.

Environment:
  YNX_REPO_DIR            default: $HOME/YNX
  USER_NAME               default: current user
  RPC_URL                 default: http://127.0.0.1:36657
  INDEXER_URL             default: http://127.0.0.1:38081
  CHECK_INTERVAL_SEC      default: 10
  HEIGHT_STALL_THRESHOLD_SEC default: 30
  MIN_SIGNED_RATIO        default: 0.66
  ALERT_WEBHOOK_URL       optional
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found; this script must run on systemd host." >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "Need root or sudo privileges." >&2
  exit 1
fi

run_root() {
  if [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

YNX_REPO_DIR="${YNX_REPO_DIR:-$HOME/YNX}"
USER_NAME="${USER_NAME:-$(id -un)}"
RPC_URL="${RPC_URL:-http://127.0.0.1:36657}"
INDEXER_URL="${INDEXER_URL:-http://127.0.0.1:38081}"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-10}"
HEIGHT_STALL_THRESHOLD_SEC="${HEIGHT_STALL_THRESHOLD_SEC:-30}"
MIN_SIGNED_RATIO="${MIN_SIGNED_RATIO:-0.66}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"

SCRIPT_PATH="$YNX_REPO_DIR/chain/scripts/v2_testnet_watchdog.sh"
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "watchdog script not executable: $SCRIPT_PATH" >&2
  exit 1
fi

run_root install -d -m 0755 /etc/ynx-v2
run_root tee /etc/ynx-v2/watchdog.env >/dev/null <<EOF
RPC_URL=$RPC_URL
INDEXER_URL=$INDEXER_URL
CHECK_INTERVAL_SEC=$CHECK_INTERVAL_SEC
HEIGHT_STALL_THRESHOLD_SEC=$HEIGHT_STALL_THRESHOLD_SEC
MIN_SIGNED_RATIO=$MIN_SIGNED_RATIO
ALERT_WEBHOOK_URL=$ALERT_WEBHOOK_URL
EOF

run_root tee /etc/systemd/system/ynx-v2-watchdog.service >/dev/null <<EOF
[Unit]
Description=YNX v2 Testnet Watchdog
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$YNX_REPO_DIR/chain
EnvironmentFile=/etc/ynx-v2/watchdog.env
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root systemctl daemon-reload
run_root systemctl enable --now ynx-v2-watchdog.service
run_root systemctl --no-pager --full status ynx-v2-watchdog.service | sed -n '1,20p'
