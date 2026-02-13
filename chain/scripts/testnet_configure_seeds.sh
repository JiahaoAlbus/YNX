#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet}"
CONFIG_TOML="$HOME_DIR/config/config.toml"

if [[ ! -f "$CONFIG_TOML" ]]; then
  echo "Missing config.toml: $CONFIG_TOML" >&2
  exit 1
fi

SEEDS="${YNX_SEEDS:-}"
PEERS="${YNX_PERSISTENT_PEERS:-}"

if [[ -z "$SEEDS" && -z "$PEERS" ]]; then
  echo "Nothing to update. Set YNX_SEEDS and/or YNX_PERSISTENT_PEERS." >&2
  exit 1
fi

if [[ -n "$SEEDS" ]]; then
  sed -i.bak -E "s/^seeds = .*/seeds = \"${SEEDS}\"/" "$CONFIG_TOML"
fi

if [[ -n "$PEERS" ]]; then
  sed -i.bak -E "s/^persistent_peers = .*/persistent_peers = \"${PEERS}\"/" "$CONFIG_TOML"
fi

echo "Updated P2P settings in $CONFIG_TOML"
