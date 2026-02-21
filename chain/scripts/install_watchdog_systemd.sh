#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_watchdog_systemd.sh

Install and start systemd service for YNX watchdog.

Environment:
  YNX_CHAIN_DIR         default: $HOME/YNX/chain
  YNX_SERVICE_NAME      default: ynx-watchdog
  RPC_URL               default: http://127.0.0.1:26657
  INDEXER_URL           default: http://127.0.0.1:8081
  CHECK_INTERVAL_SEC    default: 15
  HEIGHT_STALL_THRESHOLD_SEC default: 45
  REQUIRE_BONDED        default: 1
  MIN_SIGNED_RATIO      default: 0.66
  ALERT_WEBHOOK_URL     default: empty
  ALERT_COOLDOWN_SEC    default: 120
  USER_NAME             default: current user
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found, this script must run on a systemd host." >&2
  exit 1
fi

YNX_CHAIN_DIR="${YNX_CHAIN_DIR:-$HOME/YNX/chain}"
YNX_SERVICE_NAME="${YNX_SERVICE_NAME:-ynx-watchdog}"
RPC_URL="${RPC_URL:-http://127.0.0.1:26657}"
INDEXER_URL="${INDEXER_URL:-http://127.0.0.1:8081}"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-15}"
HEIGHT_STALL_THRESHOLD_SEC="${HEIGHT_STALL_THRESHOLD_SEC:-45}"
REQUIRE_BONDED="${REQUIRE_BONDED:-1}"
MIN_SIGNED_RATIO="${MIN_SIGNED_RATIO:-0.66}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-120}"
USER_NAME="${USER_NAME:-$(id -un)}"

if [[ ! -x "$YNX_CHAIN_DIR/scripts/testnet_watchdog.sh" ]]; then
  echo "watchdog script not found: $YNX_CHAIN_DIR/scripts/testnet_watchdog.sh" >&2
  exit 1
fi

sudo install -d -m 0755 /etc/ynx
sudo tee /etc/ynx/watchdog.env >/dev/null <<EOF
RPC_URL=$RPC_URL
INDEXER_URL=$INDEXER_URL
CHECK_INTERVAL_SEC=$CHECK_INTERVAL_SEC
HEIGHT_STALL_THRESHOLD_SEC=$HEIGHT_STALL_THRESHOLD_SEC
REQUIRE_BONDED=$REQUIRE_BONDED
MIN_SIGNED_RATIO=$MIN_SIGNED_RATIO
ALERT_WEBHOOK_URL=$ALERT_WEBHOOK_URL
ALERT_COOLDOWN_SEC=$ALERT_COOLDOWN_SEC
YNXD_BIN=$YNX_CHAIN_DIR/ynxd
EOF

sudo tee "/etc/systemd/system/${YNX_SERVICE_NAME}.service" >/dev/null <<EOF
[Unit]
Description=YNX Testnet Watchdog
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$YNX_CHAIN_DIR
EnvironmentFile=/etc/ynx/watchdog.env
ExecStart=$YNX_CHAIN_DIR/scripts/testnet_watchdog.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "${YNX_SERVICE_NAME}.service"
sudo systemctl --no-pager --full status "${YNX_SERVICE_NAME}.service" | sed -n '1,30p'

echo "Installed service: ${YNX_SERVICE_NAME}.service"
echo "Logs: journalctl -u ${YNX_SERVICE_NAME} -f --no-pager"
