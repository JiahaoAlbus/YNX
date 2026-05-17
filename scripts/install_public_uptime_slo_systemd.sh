#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/install_public_uptime_slo_systemd.sh

Install the YNX public uptime SLO probe as a systemd service.

Environment:
  YNX_REPO_DIR          default: $HOME/YNX
  USER_NAME             default: current user
  CHECK_INTERVAL_SEC    default: 60
  FETCH_TIMEOUT_SEC     default: 12
  LATENCY_WARN_MS       default: 5000
  LATENCY_CRITICAL_MS   default: 10000
  OUTPUT_BASE_DIR       default: $YNX_REPO_DIR/output/public_uptime_slo
  ALERT_WEBHOOK_URL     optional
  ALERT_COOLDOWN_SEC    default: 900
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found; this script must run on a systemd host." >&2
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
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-60}"
FETCH_TIMEOUT_SEC="${FETCH_TIMEOUT_SEC:-12}"
LATENCY_WARN_MS="${LATENCY_WARN_MS:-5000}"
LATENCY_CRITICAL_MS="${LATENCY_CRITICAL_MS:-10000}"
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-$YNX_REPO_DIR/output/public_uptime_slo}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-900}"

SCRIPT_PATH="$YNX_REPO_DIR/scripts/public_uptime_slo_probe.sh"
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "public uptime probe script not executable: $SCRIPT_PATH" >&2
  exit 1
fi

run_root install -d -m 0755 /etc/ynx-v2
run_root tee /etc/ynx-v2/public-uptime-slo.env >/dev/null <<EOF
CHECK_INTERVAL_SEC=$CHECK_INTERVAL_SEC
FETCH_TIMEOUT_SEC=$FETCH_TIMEOUT_SEC
LATENCY_WARN_MS=$LATENCY_WARN_MS
LATENCY_CRITICAL_MS=$LATENCY_CRITICAL_MS
OUTPUT_BASE_DIR=$OUTPUT_BASE_DIR
ALERT_WEBHOOK_URL=$ALERT_WEBHOOK_URL
ALERT_COOLDOWN_SEC=$ALERT_COOLDOWN_SEC
EOF

run_root tee /etc/systemd/system/ynx-public-uptime-slo.service >/dev/null <<EOF
[Unit]
Description=YNX Public Uptime SLO Probe
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$YNX_REPO_DIR
EnvironmentFile=/etc/ynx-v2/public-uptime-slo.env
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root systemctl daemon-reload
run_root systemctl enable --now ynx-public-uptime-slo.service
run_root systemctl --no-pager --full status ynx-public-uptime-slo.service | sed -n '1,20p'
