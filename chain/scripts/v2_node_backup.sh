#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_node_backup.sh

Create a local backup archive for a YNX v2 node.

Environment:
  YNX_HOME             default: $HOME/.ynx-v2
  YNX_BACKUP_DIR       default: $YNX_HOME/backups
  BACKUP_MAX_KEEP      default: 14
  INCLUDE_CHAIN_DATA   default: 0 (set 1 to include $YNX_HOME/data)
  NODE_NAME            default: hostname -s
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

YNX_HOME="${YNX_HOME:-$HOME/.ynx-v2}"
YNX_BACKUP_DIR="${YNX_BACKUP_DIR:-$YNX_HOME/backups}"
BACKUP_MAX_KEEP="${BACKUP_MAX_KEEP:-14}"
INCLUDE_CHAIN_DATA="${INCLUDE_CHAIN_DATA:-0}"
NODE_NAME="${NODE_NAME:-$(hostname -s)}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ ! -d "$YNX_HOME" ]]; then
  echo "YNX_HOME not found: $YNX_HOME" >&2
  exit 1
fi
if ! [[ "$BACKUP_MAX_KEEP" =~ ^[0-9]+$ ]]; then
  echo "BACKUP_MAX_KEEP must be an integer." >&2
  exit 1
fi

mkdir -p "$YNX_BACKUP_DIR"
ARCHIVE="$YNX_BACKUP_DIR/${NODE_NAME}_ynxv2_${STAMP}.tar.gz"
META="$YNX_BACKUP_DIR/${NODE_NAME}_ynxv2_${STAMP}.meta.json"

paths=()
for p in \
  config/genesis.json \
  config/config.toml \
  config/app.toml \
  config/client.toml \
  config/priv_validator_key.json \
  config/node_key.json \
  data/priv_validator_state.json \
  ai-gateway-data \
  web4-hub-data \
  faucet-data \
  indexer-data
do
  if [[ -e "$YNX_HOME/$p" ]]; then
    paths+=("$p")
  fi
done

if [[ "$INCLUDE_CHAIN_DATA" == "1" && -d "$YNX_HOME/data" ]]; then
  if [[ " ${paths[*]} " != *" data "* ]]; then
    paths+=("data")
  fi
fi

if [[ "${#paths[@]}" -eq 0 ]]; then
  echo "Nothing to backup under $YNX_HOME" >&2
  exit 1
fi

(
  cd "$YNX_HOME"
  tar -czf "$ARCHIVE" "${paths[@]}"
)
sha256sum "$ARCHIVE" >"${ARCHIVE}.sha256"

chain_id=""
if [[ -f "$YNX_HOME/config/genesis.json" ]]; then
  chain_id="$(jq -r '.chain_id // ""' "$YNX_HOME/config/genesis.json" 2>/dev/null || true)"
fi

cat >"$META" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "node_name": "$NODE_NAME",
  "ynx_home": "$YNX_HOME",
  "chain_id": "$chain_id",
  "archive": "$(basename "$ARCHIVE")",
  "archive_sha256_file": "$(basename "${ARCHIVE}.sha256")",
  "include_chain_data": $([[ "$INCLUDE_CHAIN_DATA" == "1" ]] && echo "true" || echo "false"),
  "paths": [
$(printf '    "%s",\n' "${paths[@]}" | sed '$ s/,$//')
  ]
}
EOF

if [[ "$BACKUP_MAX_KEEP" -gt 0 ]]; then
  mapfile -t archives < <(ls -1t "$YNX_BACKUP_DIR/${NODE_NAME}_ynxv2_"*.tar.gz 2>/dev/null || true)
  if [[ "${#archives[@]}" -gt "$BACKUP_MAX_KEEP" ]]; then
    for old in "${archives[@]:$BACKUP_MAX_KEEP}"; do
      rm -f "$old" "${old}.sha256"
      old_meta="${old%.tar.gz}.meta.json"
      rm -f "$old_meta"
    done
  fi
fi

echo "backup_archive=$ARCHIVE"
echo "backup_meta=$META"
