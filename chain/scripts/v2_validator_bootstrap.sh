#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_validator_bootstrap.sh [--rpc <rpc_url> | --bundle <bundle_path_or_url> | --descriptor <descriptor_path_or_url>] [options]

Bootstrap a new validator, full-node, or public-RPC home for YNX v2.

Input sources:
  --rpc <url>                 Live RPC endpoint (example: http://43.134.23.58:36657)
  --bundle <path|url>         Release bundle directory or .tar.gz
  --descriptor <path|url>     Network descriptor JSON

Options:
  --home <path>               Default: $HOME/.ynx-v2-validator
  --chain-id <id>             Default: from descriptor/bundle/RPC
  --genesis-file <path>       Optional local genesis.json path
  --moniker <name>            Default: ynx-v2-validator
  --role <name>               validator | full-node | public-rpc (default: validator)
  --seeds <seed_list>         Default: from descriptor/bundle
  --persistent-peers <list>   Default: from descriptor/bundle
  --trust-offset <n>          Default: 2000
  --minimum-gas-prices <val>  Default: from descriptor or 0.000000007anyxt
  --no-statesync              Disable state sync setup
  --force-blocksync           Alias for --no-statesync
  --reset                     Delete existing home before bootstrap
  --start                     Start node at the end

Environment:
  YNX_BIN                     Optional path to ynxd binary
EOF
}

RPC_URL=""
BUNDLE_SOURCE=""
DESCRIPTOR_SOURCE=""
HOME_DIR="${HOME}/.ynx-v2-validator"
CHAIN_ID=""
GENESIS_FILE=""
MONIKER="ynx-v2-validator"
ROLE="validator"
SEEDS=""
PERSISTENT_PEERS=""
TRUST_OFFSET=2000
MIN_GAS_PRICES=""
ENABLE_STATESYNC=1
RESET=0
START=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rpc)
      RPC_URL="${2:-}"
      shift 2
      ;;
    --bundle)
      BUNDLE_SOURCE="${2:-}"
      shift 2
      ;;
    --descriptor)
      DESCRIPTOR_SOURCE="${2:-}"
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
    --genesis-file)
      GENESIS_FILE="${2:-}"
      shift 2
      ;;
    --moniker)
      MONIKER="${2:-}"
      shift 2
      ;;
    --role)
      ROLE="${2:-}"
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
    --no-statesync|--force-blocksync)
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

for bin in curl jq tar mktemp; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${YNX_BIN:-$ROOT_DIR/ynxd}"
if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (cd "$ROOT_DIR" && CGO_ENABLED=0 go build -buildvcs=false -o "$BIN" ./cmd/ynxd)
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

download_to() {
  local src="$1"
  local dst="$2"
  if [[ "$src" =~ ^https?:// ]]; then
    curl -fsSL "$src" -o "$dst"
  else
    cp "$src" "$dst"
  fi
}

resolve_json_source() {
  local src="$1"
  local dst="$2"
  if [[ "$src" =~ ^https?:// ]]; then
    curl -fsSL "$src" -o "$dst"
  else
    cp "$src" "$dst"
  fi
}

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

BUNDLE_DIR=""
if [[ -n "$BUNDLE_SOURCE" ]]; then
  if [[ -d "$BUNDLE_SOURCE" ]]; then
    BUNDLE_DIR="$BUNDLE_SOURCE"
  else
    bundle_file="$TMP_DIR/bundle.tar.gz"
    download_to "$BUNDLE_SOURCE" "$bundle_file"
    BUNDLE_DIR="$TMP_DIR/bundle"
    mkdir -p "$BUNDLE_DIR"
    tar -xzf "$bundle_file" -C "$BUNDLE_DIR"
  fi
fi

DESCRIPTOR_FILE=""
if [[ -n "$DESCRIPTOR_SOURCE" ]]; then
  DESCRIPTOR_FILE="$TMP_DIR/descriptor.json"
  resolve_json_source "$DESCRIPTOR_SOURCE" "$DESCRIPTOR_FILE"
elif [[ -n "$BUNDLE_DIR" && -f "$BUNDLE_DIR/descriptor.json" ]]; then
  DESCRIPTOR_FILE="$BUNDLE_DIR/descriptor.json"
fi

if [[ -n "$BUNDLE_DIR" && -z "$GENESIS_FILE" && -f "$BUNDLE_DIR/genesis.json" ]]; then
  GENESIS_FILE="$BUNDLE_DIR/genesis.json"
fi

descriptor_get() {
  local query="$1"
  if [[ -z "$DESCRIPTOR_FILE" ]]; then
    return 1
  fi
  jq -r "$query // empty" "$DESCRIPTOR_FILE"
}

if [[ -z "$RPC_URL" ]]; then
  RPC_URL="$(descriptor_get '.network.rpc')"
fi
if [[ -z "$RPC_URL" ]]; then
  RPC_URL="$(descriptor_get '.endpoints.rpc')"
fi
if [[ -z "$CHAIN_ID" ]]; then
  CHAIN_ID="$(descriptor_get '.chain_id')"
fi
if [[ -z "$SEEDS" ]]; then
  SEEDS="$(descriptor_get '.network.seeds')"
fi
if [[ -z "$PERSISTENT_PEERS" ]]; then
  PERSISTENT_PEERS="$(descriptor_get '.network.persistent_peers')"
fi
if [[ -z "$MIN_GAS_PRICES" ]]; then
  MIN_GAS_PRICES="$(descriptor_get '.minimum_gas_prices')"
fi
if [[ -z "$MIN_GAS_PRICES" ]]; then
  MIN_GAS_PRICES="0.000000007anyxt"
fi

if [[ -z "$RPC_URL" ]]; then
  echo "Need one of --rpc, --bundle, or --descriptor with a usable RPC endpoint" >&2
  usage
  exit 1
fi

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

if [[ -n "$GENESIS_FILE" ]]; then
  if [[ ! -f "$GENESIS_FILE" ]]; then
    echo "Genesis file not found: $GENESIS_FILE" >&2
    exit 1
  fi
  cp "$GENESIS_FILE" "$HOME_DIR/config/genesis.json"
else
  genesis_ok=0
  if genesis_json="$(rpc_get "/genesis" 2>/dev/null || true)"; then
    if echo "$genesis_json" | jq -e '.result.genesis != null' >/dev/null 2>&1; then
      echo "$genesis_json" | jq -r '.result.genesis' >"$HOME_DIR/config/genesis.json"
      genesis_ok=1
    fi
  fi

  if [[ "$genesis_ok" -eq 0 ]]; then
    chunk_meta="$(rpc_get "/genesis_chunked?chunk=0" 2>/dev/null || true)"
    if [[ -n "$chunk_meta" ]] && echo "$chunk_meta" | jq -e '.result.total != null and .result.data != null' >/dev/null 2>&1; then
      total_chunks="$(echo "$chunk_meta" | jq -r '.result.total')"
      : >"$HOME_DIR/config/genesis.json"
      for ((i=0; i<total_chunks; i++)); do
        chunk_json="$(rpc_get "/genesis_chunked?chunk=${i}")"
        chunk_data="$(echo "$chunk_json" | jq -r '.result.data')"
        if [[ -z "$chunk_data" || "$chunk_data" == "null" ]]; then
          echo "Failed to fetch genesis chunk ${i}" >&2
          exit 1
        fi
        printf '%s' "$chunk_data" | base64 -d >>"$HOME_DIR/config/genesis.json"
      done
      genesis_ok=1
    fi
  fi

  if [[ "$genesis_ok" -eq 0 ]]; then
    echo "Failed to fetch genesis via /genesis and /genesis_chunked (provide --genesis-file or --bundle)" >&2
    exit 1
  fi
fi

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

set_top_level_key "$CONFIG_TOML" "moniker" "\"$MONIKER\""
set_top_level_key "$CONFIG_TOML" "seeds" "\"$SEEDS\""
set_top_level_key "$CONFIG_TOML" "persistent_peers" "\"$PERSISTENT_PEERS\""
set_top_level_key "$CONFIG_TOML" "addr_book_strict" "false"
set_section_key "$CONFIG_TOML" "p2p" "pex" "true"

statesync_mode="disabled"
if [[ "$ENABLE_STATESYNC" -eq 1 ]]; then
  if [[ "$latest_height" =~ ^[0-9]+$ ]]; then
    trust_height=$((latest_height - TRUST_OFFSET))
    if (( trust_height < 2 )); then
      trust_height=2
    fi
    trust_hash="$(rpc_get "/block?height=${trust_height}" | jq -r '.result.block_id.hash' || true)"
    if [[ -n "$trust_hash" && "$trust_hash" != "null" ]]; then
      set_section_key "$CONFIG_TOML" "statesync" "enable" "true"
      set_section_key "$CONFIG_TOML" "statesync" "rpc_servers" "\"${RPC_URL},${RPC_URL}\""
      set_section_key "$CONFIG_TOML" "statesync" "trust_height" "$trust_height"
      set_section_key "$CONFIG_TOML" "statesync" "trust_hash" "\"$trust_hash\""
      statesync_mode="enabled"
    else
      set_section_key "$CONFIG_TOML" "statesync" "enable" "false"
      statesync_mode="fallback-blocksync"
    fi
  else
    set_section_key "$CONFIG_TOML" "statesync" "enable" "false"
    statesync_mode="fallback-blocksync"
  fi
else
  set_section_key "$CONFIG_TOML" "statesync" "enable" "false"
fi

set_section_key "$APP_TOML" "api" "enable" "true"
set_section_key "$APP_TOML" "json-rpc" "enable" "true"

YNX_HOME="$HOME_DIR" "$ROOT_DIR/scripts/v2_role_apply.sh" "$ROLE" >/dev/null

echo
echo "Bootstrap complete"
echo "home=$HOME_DIR"
echo "role=$ROLE"
echo "chain_id=$CHAIN_ID"
echo "rpc=$RPC_URL"
echo "statesync=$statesync_mode"
echo "seeds=$SEEDS"
echo "persistent_peers=$PERSISTENT_PEERS"
if [[ -n "$BUNDLE_DIR" ]]; then
  echo "bundle=$BUNDLE_DIR"
fi
if [[ -n "$DESCRIPTOR_FILE" ]]; then
  echo "descriptor=$DESCRIPTOR_FILE"
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
