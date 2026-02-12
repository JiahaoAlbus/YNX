#!/usr/bin/env bash

set -euo pipefail

RESET=0
SNAPSHOT=0
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
      ;;
    --snapshot)
      SNAPSHOT=1
      shift
      ;;
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--reset] [--snapshot] [--out DIR]

Creates a release bundle for a public YNX testnet.

Options:
  --reset      Clear the output directory before writing
  --snapshot   Create a data snapshot tarball (requires YNX_RPC)
  --out DIR    Output directory (default: chain/.release/<chain-id>-<date>)

Environment:
  YNX_HOME           Node home (default: chain/.testnet)
  YNX_CHAIN_ID       Override chain id (optional)
  YNX_DENOM          Gas denom (default: anyxt)
  YNX_RPC            CometBFT RPC for snapshot height (e.g., http://127.0.0.1:26657)
  YNX_SEEDS          Comma-separated seed list (nodeid@ip:port)
  YNX_PERSISTENT_PEERS Comma-separated peer list (nodeid@ip:port)
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet}"
DENOM="${YNX_DENOM:-anyxt}"
BIN="$ROOT_DIR/ynxd"

if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (
    cd "$ROOT_DIR"
    CGO_ENABLED="${YNX_CGO_ENABLED:-0}" go build -o "$BIN" ./cmd/ynxd
  )
fi

GENESIS="$HOME_DIR/config/genesis.json"
CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

if [[ ! -f "$GENESIS" ]]; then
  echo "Missing genesis: $GENESIS" >&2
  exit 1
fi

chain_id="${YNX_CHAIN_ID:-}"
if [[ -z "$chain_id" && -f "$HOME_DIR/config/client.toml" ]]; then
  chain_id="$(grep -E '^chain-id = ' "$HOME_DIR/config/client.toml" | head -n 1 | sed -E 's/chain-id = \"(.*)\"/\\1/')"
fi
if [[ -z "$chain_id" ]]; then
  chain_id="$(grep -E '\"chain_id\"' "$GENESIS" | head -n 1 | sed -E 's/.*\"chain_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\\1/')"
fi
if [[ -z "$chain_id" ]]; then
  echo "Unable to determine chain id. Set YNX_CHAIN_ID." >&2
  exit 1
fi

evm_chain_id="$(grep -E '^evm-chain-id = ' "$APP_TOML" | head -n 1 | sed -E 's/evm-chain-id = ([0-9]+)/\\1/')"

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$ROOT_DIR/.release/${chain_id}-$(date +%Y%m%d)"
fi

if [[ "$RESET" -eq 1 && -d "$OUT_DIR" ]]; then
  rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

echo "Writing release bundle to: $OUT_DIR"
cp "$GENESIS" "$OUT_DIR/genesis.json"
cp "$CONFIG_TOML" "$OUT_DIR/config.toml"
cp "$APP_TOML" "$OUT_DIR/app.toml"

if [[ -n "${YNX_SEEDS:-}" ]]; then
  echo "$YNX_SEEDS" > "$OUT_DIR/seeds.txt"
fi
if [[ -n "${YNX_PERSISTENT_PEERS:-}" ]]; then
  echo "$YNX_PERSISTENT_PEERS" > "$OUT_DIR/persistent_peers.txt"
fi

if command -v shasum >/dev/null 2>&1; then
  (
    cd "$OUT_DIR"
    shasum -a 256 genesis.json config.toml app.toml > checksums.txt
  )
fi

cat > "$OUT_DIR/network.json" <<EOF
{
  "chain_id": "${chain_id}",
  "evm_chain_id": "${evm_chain_id}",
  "denom": "${DENOM}",
  "genesis_sha256": "$(shasum -a 256 "$OUT_DIR/genesis.json" | awk '{print $1}')"
}
EOF

if [[ "$SNAPSHOT" -eq 1 ]]; then
  if [[ -z "${YNX_RPC:-}" ]]; then
    echo "YNX_RPC is required to create a snapshot." >&2
    exit 1
  fi
  height="$(curl -s "$YNX_RPC/status" | node -e "const fs=require('fs');const data=fs.readFileSync(0,'utf8');const json=JSON.parse(data);console.log(json.result.sync_info.latest_block_height)")"
  if [[ -z "$height" ]]; then
    echo "Unable to determine height from $YNX_RPC/status" >&2
    exit 1
  fi
  snapshot_name="snapshot_${chain_id}_${height}_$(date +%Y%m%d).tar.gz"
  tar -czf "$OUT_DIR/$snapshot_name" -C "$HOME_DIR" data
  echo "$snapshot_name" > "$OUT_DIR/snapshot.txt"
fi

echo "Release bundle complete."
