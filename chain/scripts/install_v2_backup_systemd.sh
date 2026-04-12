#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_v2_backup_systemd.sh

Install YNX v2 backup service + timer on a systemd host.

Environment:
  YNX_REPO_DIR           default: $HOME/YNX
  YNX_HOME               default: $HOME/.ynx-v2
  YNX_BACKUP_DIR         default: $YNX_HOME/backups
  USER_NAME              default: current user
  BACKUP_MAX_KEEP        default: 14
  INCLUDE_CHAIN_DATA     default: 0
  BACKUP_ON_CALENDAR     default: *-*-* 03:30:00
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
YNX_HOME="${YNX_HOME:-$HOME/.ynx-v2}"
YNX_BACKUP_DIR="${YNX_BACKUP_DIR:-$YNX_HOME/backups}"
USER_NAME="${USER_NAME:-$(id -un)}"
BACKUP_MAX_KEEP="${BACKUP_MAX_KEEP:-14}"
INCLUDE_CHAIN_DATA="${INCLUDE_CHAIN_DATA:-0}"
BACKUP_ON_CALENDAR="${BACKUP_ON_CALENDAR:-*-*-* 03:30:00}"

SCRIPT_PATH="$YNX_REPO_DIR/chain/scripts/v2_node_backup.sh"
if [[ ! -x "$SCRIPT_PATH" ]]; then
  chmod +x "$SCRIPT_PATH" >/dev/null 2>&1 || true
fi
if [[ ! -x "$SCRIPT_PATH" ]]; then
  echo "Backup script not executable: $SCRIPT_PATH" >&2
  exit 1
fi

run_root install -d -m 0755 /etc/ynx-v2
run_root tee /etc/ynx-v2/backup.env >/dev/null <<EOF
YNX_HOME=$YNX_HOME
YNX_BACKUP_DIR=$YNX_BACKUP_DIR
BACKUP_MAX_KEEP=$BACKUP_MAX_KEEP
INCLUDE_CHAIN_DATA=$INCLUDE_CHAIN_DATA
EOF

run_root tee /etc/systemd/system/ynx-v2-backup.service >/dev/null <<EOF
[Unit]
Description=YNX v2 backup job
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=$USER_NAME
WorkingDirectory=$YNX_REPO_DIR/chain
EnvironmentFile=/etc/ynx-v2/backup.env
ExecStart=$SCRIPT_PATH
EOF

run_root tee /etc/systemd/system/ynx-v2-backup.timer >/dev/null <<EOF
[Unit]
Description=Run YNX v2 backup daily

[Timer]
OnCalendar=$BACKUP_ON_CALENDAR
Persistent=true
Unit=ynx-v2-backup.service

[Install]
WantedBy=timers.target
EOF

run_root systemctl daemon-reload
run_root systemctl enable --now ynx-v2-backup.timer
run_root systemctl --no-pager --full status ynx-v2-backup.timer | sed -n '1,20p'
