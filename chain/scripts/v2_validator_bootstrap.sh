#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_validator_bootstrap.sh --rpc <rpc_url> [options]

Bootstrap a new validator/full-node home for YNX v2 public testnet.

Required:
  --rpc <url>                 Example: http://43.134.23.58:36657

Options:
  --home <path>               Default: $HOME/.ynx-v2-validator
  --chain-id <id>             Default: from RPC status
  --moniker <name>            Default: ynx-v2-validator
  --seeds <seed_list>         Default: empty
  --persistent-peers <list>   Default: empty
  --trust-offset <n>          Default: 2000
  --minimum-gas-prices <val>  Default: 0.000000007anyxt
  --no-statesync              Disable state sync setup
  --reset                     Delete existing home before bootstrap
  --start                     Start node at the end

Environment:
  YNX_BIN                     Optional path to ynxd binary
EOF
}

RPC_URL=""
HOME_DIR="${HOME}/.ynx-v2-validator"
CHAIN_ID=""
MONIKER="ynx-v2-validator"
SEEDS=""
PERSISTENT_PEERS=""
TRUST_OFFSET=2000
MIN_GAS_PRICES="0.000000007anyxt"
ENABLE_STATESYNC=1
RESET=0
START=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rpc)
      RPC_URL="${2:-}"
      shift 2
      ;;
    --home)
      HOME_DIR="${2:-}"
      shift 2
      ;;
    --chain-id)
      CHAIN_ID="${2:-}"
      shift 2
      ;;
    --moniker)
      MONIKER="${2:-}"
      shift 2
      ;;
    --seeds)
      SEEDS="${2:-}"
      shift 2
      ;;
    --persistent-peers)
      PERSISTENT_PEERS="${2:-}"
      shift 2
      ;;
    --trust-offset)
      TRUST_OFFSET="${2:-2000}"
      shift 2
      ;;
    --minimum-gas-prices)
      MIN_GAS_PRICES="${2:-}"
      shift 2
      ;;
    --no-statesync)
      ENABLE_STATESYNC=0
      shift
      ;;
    --reset)
      RESET=1
      shift
      ;;
    --start)
      START=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$RPC_URL" ]]; then
  echo "--rpc is required" >&2
  usage
  exit 1
fi

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${YNX_BIN:-$ROOT_DIR/ynxd}"
if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (cd "$ROOT_DIR" && CGO_ENABLED=0 go build -o "$BIN" ./cmd/ynxd)
fi

rpc_get() {
  local path="$1"
  curl -fsS --max-time 15 "${RPC_URL}${path}"
}

set_top_level_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  awk -v key="$key" -v value="$value" '
    BEGIN { done=0 }
    $0 ~ "^[[:space:]]*"key"[[:space:]]*=" && done==0 {
      print key" = "value
      done=1
      next
    }
    { print }
    END {
      if (done==0) print key" = "value
    }
  ' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

set_section_key() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN { in_section=0; done=0 }
    /^\[/ {
      if ($0 == "["section"]") {
        in_section=1
      } else {
        if (in_section && done==0) {
          print key" = "value
          done=1
        }
        in_section=0
      }
      print
      next
    }
    {
      if (in_section && $0 ~ "^[[:space:]]*"key"[[:space:]]*=" && done==0) {
        print key" = "value
        done=1
      } else {
        print
      }
    }
    END {
      if (in_section && done==0) {
        print key" = "value
      }
    }
  ' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

status_json="$(rpc_get "/status")"
rpc_chain_id="$(echo "$status_json" | jq -r '.result.node_info.network')"
latest_height="$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height')"

if [[ -z "$rpc_chain_id" || "$rpc_chain_id" == "null" ]]; then
  echo "Failed to read chain-id from $RPC_URL/status" >&2
  exit 1
fi
if [[ -z "$CHAIN_ID" ]]; then
  CHAIN_ID="$rpc_chain_id"
fi
if [[ "$CHAIN_ID" != "$rpc_chain_id" ]]; then
  echo "Chain-id mismatch: expected $CHAIN_ID but RPC is $rpc_chain_id" >&2
  exit 1
fi

if [[ "$RESET" -eq 1 ]]; then
  rm -rf "$HOME_DIR"
fi

mkdir -p "$HOME_DIR"
if [[ ! -f "$HOME_DIR/config/config.toml" ]]; then
  "$BIN" init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null
fi

rpc_get "/genesis" | jq -r '.result.genesis' >"$HOME_DIR/config/genesis.json"

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

set_top_level_key "$CONFIG_TOML" "seeds" "\"$SEEDS\""
set_top_level_key "$CONFIG_TOML" "persistent_peers" "\"$PERSISTENT_PEERS\""
set_top_level_key "$CONFIG_TOML" "addr_book_strict" "false"

if [[ "$ENABLE_STATESYNC" -eq 1 ]]; then
  if ! [[ "$latest_height" =~ ^[0-9]+$ ]]; then
    echo "Invalid latest height from RPC: $latest_height" >&2
    exit 1
  fi
  trust_height=$((latest_height - TRUST_OFFSET))
  if (( trust_height < 2 )); then
    trust_height=2
  fi
  trust_hash="$(rpc_get "/block?height=${trust_height}" | jq -r '.result.block_id.hash')"
  if [[ -z "$trust_hash" || "$trust_hash" == "null" ]]; then
    echo "Failed to fetch trust hash at height $trust_height" >&2
    exit 1
  fi

  set_section_key "$CONFIG_TOML" "statesync" "enable" "true"
  set_section_key "$CONFIG_TOML" "statesync" "rpc_servers" "\"${RPC_URL},${RPC_URL}\""
  set_section_key "$CONFIG_TOML" "statesync" "trust_height" "$trust_height"
  set_section_key "$CONFIG_TOML" "statesync" "trust_hash" "\"$trust_hash\""
else
  set_section_key "$CONFIG_TOML" "statesync" "enable" "false"
fi

set_section_key "$APP_TOML" "api" "enable" "true"
set_section_key "$APP_TOML" "json-rpc" "enable" "true"

echo
echo "Bootstrap complete"
echo "home=$HOME_DIR"
echo "chain_id=$CHAIN_ID"
echo "rpc=$RPC_URL"
if [[ "$ENABLE_STATESYNC" -eq 1 ]]; then
  echo "statesync=enabled"
else
  echo "statesync=disabled"
fi
echo
echo "Create validator key:"
echo "$BIN keys add validator --home \"$HOME_DIR\" --keyring-backend os --key-type eth_secp256k1"
echo
echo "Start node:"
echo "$BIN start --home \"$HOME_DIR\" --chain-id \"$CHAIN_ID\" --minimum-gas-prices \"$MIN_GAS_PRICES\""
echo
echo "After funding validator account, create validator tx:"
echo "$BIN tx staking create-validator --amount 100000000000000000000anyxt --pubkey \"\$($BIN comet show-validator --home \"$HOME_DIR\")\" --moniker \"$MONIKER\" --chain-id \"$CHAIN_ID\" --commission-rate 0.10 --commission-max-rate 0.20 --commission-max-change-rate 0.01 --min-self-delegation 1 --from validator --home \"$HOME_DIR\" --keyring-backend os --node \"$RPC_URL\" --gas auto --gas-adjustment 1.2 --gas-prices \"$MIN_GAS_PRICES\""

if [[ "$START" -eq 1 ]]; then
  exec "$BIN" start --home "$HOME_DIR" --chain-id "$CHAIN_ID" --minimum-gas-prices "$MIN_GAS_PRICES"
fi
