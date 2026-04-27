#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_node_restore.sh <backup_archive.tar.gz> [--force]

Restore a YNX v2 node backup created by v2_node_backup.sh into YNX_HOME.

Environment:
  YNX_HOME       default: $HOME/.ynx-v2

Notes:
  - Validates <archive>.sha256 when present (recommended).
  - Refuses to overwrite existing files unless --force is set.
EOF
}

ARCHIVE="${1:-}"
FORCE=0

if [[ -z "$ARCHIVE" || "$ARCHIVE" == "-h" || "$ARCHIVE" == "--help" ]]; then
  usage
  exit 1
fi

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

YNX_HOME="${YNX_HOME:-$HOME/.ynx-v2}"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Archive not found: $ARCHIVE" >&2
  exit 1
fi

SHA_FILE="${ARCHIVE}.sha256"
if [[ -f "$SHA_FILE" ]]; then
  sha256sum -c "$SHA_FILE" >/dev/null
else
  echo "WARN: sha256 file not found: $SHA_FILE (skipping integrity check)" >&2
fi

mkdir -p "$YNX_HOME"

if [[ "$FORCE" -ne 1 ]]; then
  existing="$(tar -tzf "$ARCHIVE" | while read -r p; do
    [[ -z "$p" ]] && continue
    if [[ -e "$YNX_HOME/$p" ]]; then
      echo "$p"
      break
    fi
  done)"
  if [[ -n "$existing" ]]; then
    echo "Refusing to overwrite existing path under YNX_HOME: $existing" >&2
    echo "Re-run with --force to overwrite, or move your current $YNX_HOME aside." >&2
    exit 1
  fi
fi

tar -xzf "$ARCHIVE" -C "$YNX_HOME"

echo "Restored backup into: $YNX_HOME"

