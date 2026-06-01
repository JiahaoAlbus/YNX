#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/install_public_bridge_full_loop_systemd.sh

Install the YNX public bridge full-loop probe as a systemd timer.

Environment:
  YNX_REPO_DIR          default: $HOME/YNX
  USER_NAME             default: current user
  TIMER_INTERVAL_SEC    default: 300
  FETCH_TIMEOUT_SEC     default: 15
  FETCH_RETRIES         default: 3
  OUTPUT_BASE_DIR       default: $YNX_REPO_DIR/output/public_bridge_full_loop
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
TIMER_INTERVAL_SEC="${TIMER_INTERVAL_SEC:-300}"
FETCH_TIMEOUT_SEC="${FETCH_TIMEOUT_SEC:-15}"
FETCH_RETRIES="${FETCH_RETRIES:-3}"
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-$YNX_REPO_DIR/output/public_bridge_full_loop}"

SCRIPT_PATH="$YNX_REPO_DIR/scripts/public_bridge_full_loop_probe.sh"
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "public bridge full-loop probe script not executable: $SCRIPT_PATH" >&2
  exit 1
fi

run_root install -d -m 0755 /etc/ynx-v2
run_root tee /etc/ynx-v2/public-bridge-full-loop.env >/dev/null <<EOF
YNX_FETCH_TIMEOUT_SEC=$FETCH_TIMEOUT_SEC
YNX_FETCH_RETRIES=$FETCH_RETRIES
OUTPUT_BASE_DIR=$OUTPUT_BASE_DIR
EOF

run_root tee /etc/systemd/system/ynx-public-bridge-full-loop.service >/dev/null <<EOF
[Unit]
Description=YNX Public Bridge Full Loop Probe
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$USER_NAME
WorkingDirectory=$YNX_REPO_DIR
EnvironmentFile=/etc/ynx-v2/public-bridge-full-loop.env
ExecStart=/bin/bash -lc 'stamp=\$(date +%%Y%%m%%d_%%H%%M%%S); "$SCRIPT_PATH" --output-dir "$OUTPUT_BASE_DIR/run_\$stamp"'
StandardOutput=journal
StandardError=journal
EOF

run_root tee /etc/systemd/system/ynx-public-bridge-full-loop.timer >/dev/null <<EOF
[Unit]
Description=Run YNX Public Bridge Full Loop Probe

[Timer]
OnBootSec=2min
OnUnitActiveSec=${TIMER_INTERVAL_SEC}s
AccuracySec=30s
Persistent=true
Unit=ynx-public-bridge-full-loop.service

[Install]
WantedBy=timers.target
EOF

run_root systemctl daemon-reload
run_root systemctl enable --now ynx-public-bridge-full-loop.timer
run_root systemctl start ynx-public-bridge-full-loop.service
run_root systemctl --no-pager --full status ynx-public-bridge-full-loop.timer | sed -n '1,20p'
