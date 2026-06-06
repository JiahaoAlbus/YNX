#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/install_public_ai_onchain_systemd.sh

Install the YNX public AI on-chain settlement probe as a systemd timer.

Environment:
  YNX_REPO_DIR          default: $HOME/YNX
  USER_NAME             default: current user
  TIMER_INTERVAL_SEC    default: 300
  FETCH_TIMEOUT_SEC     default: 15
  FETCH_RETRIES         default: 3
  OUTPUT_BASE_DIR       default: $YNX_REPO_DIR/output/public_ai_onchain_probe
  YNX_AI_PROBE_JOB_ID   default: job_public_onchain_20260606T053758Z
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
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-$YNX_REPO_DIR/output/public_ai_onchain_probe}"
YNX_AI_PROBE_JOB_ID="${YNX_AI_PROBE_JOB_ID:-job_public_onchain_20260606T053758Z}"

SCRIPT_PATH="$YNX_REPO_DIR/scripts/public_ai_onchain_settlement_probe.sh"
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "public AI on-chain settlement probe script not executable: $SCRIPT_PATH" >&2
  exit 1
fi

run_root install -d -m 0755 /etc/ynx-v2
run_root tee /etc/ynx-v2/public-ai-onchain.env >/dev/null <<EOF
YNX_FETCH_TIMEOUT_SEC=$FETCH_TIMEOUT_SEC
YNX_FETCH_RETRIES=$FETCH_RETRIES
YNX_AI_PROBE_JOB_ID=$YNX_AI_PROBE_JOB_ID
OUTPUT_BASE_DIR=$OUTPUT_BASE_DIR
EOF

run_root tee /etc/systemd/system/ynx-public-ai-onchain.service >/dev/null <<EOF
[Unit]
Description=YNX Public AI On-chain Settlement Probe
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$USER_NAME
WorkingDirectory=$YNX_REPO_DIR
EnvironmentFile=/etc/ynx-v2/public-ai-onchain.env
ExecStart=/bin/bash -lc 'stamp=\$(date +%%Y%%m%%d_%%H%%M%%S); "$SCRIPT_PATH" --output-dir "$OUTPUT_BASE_DIR/run_\$stamp"'
StandardOutput=journal
StandardError=journal
EOF

run_root tee /etc/systemd/system/ynx-public-ai-onchain.timer >/dev/null <<EOF
[Unit]
Description=Run YNX Public AI On-chain Settlement Probe

[Timer]
OnBootSec=2min
OnUnitActiveSec=${TIMER_INTERVAL_SEC}s
AccuracySec=30s
Persistent=true
Unit=ynx-public-ai-onchain.service

[Install]
WantedBy=timers.target
EOF

run_root systemctl daemon-reload
run_root systemctl enable --now ynx-public-ai-onchain.timer
run_root systemctl start ynx-public-ai-onchain.service
run_root systemctl --no-pager --full status ynx-public-ai-onchain.timer | sed -n '1,20p'
