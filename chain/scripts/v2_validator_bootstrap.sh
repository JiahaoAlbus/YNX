#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ynx_ui.sh"
ynx_ui_init

usage() {
  cat <<'EOF'
Usage:
  v2_validator_bootstrap.sh [--rpc <rpc_url> | --bundle <bundle_path_or_url> | --descriptor <descriptor_path_or_url>] [options]

Bootstrap a new validator, full-node, or public-RPC home for YNX v2.

Input sources:
  --rpc <url>                 Live RPC endpoint (example: https://rpc.ynxweb4.com)
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
  --port-offset <n>           Default: 0 (apply to all service ports)
  --minimum-gas-prices <val>  Default: from descriptor or 0.000000007anyxt
  --no-statesync              Disable state sync setup
  --force-blocksync           Alias for --no-statesync
  --plan-only                 print resolved bootstrap plan and exit
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
PORT_OFFSET=0
MIN_GAS_PRICES=""
ENABLE_STATESYNC=1
PLAN_ONLY=0
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
    --port-offset)
      PORT_OFFSET="${2:-0}"
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
    --plan-only)
      PLAN_ONLY=1
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

if ! [[ "$PORT_OFFSET" =~ ^[0-9]+$ ]]; then
  echo "--port-offset must be integer >= 0" >&2
  exit 1
fi

for bin in curl jq tar mktemp base64; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${YNX_BIN:-$ROOT_DIR/ynxd}"
if [[ ! -x "$BIN" ]]; then
  if [[ "$PLAN_ONLY" -eq 1 ]]; then
    BIN="unresolved(plan-only)"
  else
    DEFAULT_GOPROXY="https://goproxy.cn,https://proxy.golang.org,direct"
    echo "Building ynxd..."
    (cd "$ROOT_DIR" && GOPROXY="${GOPROXY:-$DEFAULT_GOPROXY}" CGO_ENABLED=0 go build -buildvcs=false -o "$BIN" ./cmd/ynxd)
  fi
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

rpc_get_retry() {
  local path="$1"
  local attempts="${2:-8}"
  local sleep_sec="${3:-2}"
  local max_time="${4:-30}"
  local out=""
  local i
  for ((i=1; i<=attempts; i++)); do
    out="$(curl -fsS --max-time "$max_time" "${RPC_URL}${path}" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      printf '%s\n' "$out"
      return 0
    fi
    sleep "$sleep_sec"
  done
  return 1
}

validate_genesis_file() {
  local file="$1"
  # Accept both classic Comet genesis and AppGenesis layouts.
  if ! jq -e '.chain_id != null and .app_state != null' "$file" >/dev/null 2>&1; then
    return 1
  fi
  if [[ -n "$CHAIN_ID" ]]; then
    local g_chain_id
    g_chain_id="$(jq -r '.chain_id' "$file" 2>/dev/null || true)"
    if [[ "$g_chain_id" != "$CHAIN_ID" ]]; then
      return 1
    fi
  fi
  return 0
}

fetch_genesis_chunked() {
  local out_file="$1"
  local meta_json total_chunks i chunk_json chunk_data tmp_file

  meta_json="$(rpc_get_retry "/genesis_chunked?chunk=0" 4 2 15 || true)"
  if [[ -z "$meta_json" ]]; then
    return 1
  fi
  if ! echo "$meta_json" | jq -e '.result.total != null and .result.data != null' >/dev/null 2>&1; then
    return 1
  fi

  total_chunks="$(echo "$meta_json" | jq -r '.result.total' 2>/dev/null || true)"
  if ! [[ "$total_chunks" =~ ^[0-9]+$ ]] || (( total_chunks < 1 )); then
    return 1
  fi

  tmp_file="$TMP_DIR/genesis.chunked.json"
  : >"$tmp_file"

  for ((i=0; i<total_chunks; i++)); do
    chunk_json="$(rpc_get_retry "/genesis_chunked?chunk=${i}" 6 2 15 || true)"
    if [[ -z "$chunk_json" ]]; then
      return 1
    fi
    chunk_data="$(echo "$chunk_json" | jq -r '.result.data // empty' 2>/dev/null || true)"
    if [[ -z "$chunk_data" || "$chunk_data" == "null" ]]; then
      return 1
    fi
    if ! printf '%s' "$chunk_data" | base64 -d >>"$tmp_file" 2>/dev/null; then
      return 1
    fi
  done

  if ! validate_genesis_file "$tmp_file"; then
    return 1
  fi
  mv "$tmp_file" "$out_file"
  return 0
}

fetch_genesis_full() {
  local out_file="$1"
  local raw_file tmp_file
  raw_file="$TMP_DIR/genesis.full.raw.json"
  tmp_file="$TMP_DIR/genesis.full.json"

  if ! curl -fsS --max-time 120 "${RPC_URL}/genesis" -o "$raw_file"; then
    return 1
  fi
  if ! jq -e '.result.genesis != null' "$raw_file" >/dev/null 2>&1; then
    return 1
  fi
  if ! jq -r '.result.genesis' "$raw_file" >"$tmp_file"; then
    return 1
  fi
  if ! validate_genesis_file "$tmp_file"; then
    return 1
  fi
  mv "$tmp_file" "$out_file"
  return 0
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
  RPC_URL="$(descriptor_get '.network.rpc' || true)"
fi
if [[ -z "$RPC_URL" ]]; then
  RPC_URL="$(descriptor_get '.endpoints.rpc' || true)"
fi
if [[ -z "$CHAIN_ID" ]]; then
  CHAIN_ID="$(descriptor_get '.chain_id' || true)"
fi
if [[ -z "$SEEDS" ]]; then
  SEEDS="$(descriptor_get '.network.seeds' || true)"
fi
if [[ -z "$PERSISTENT_PEERS" ]]; then
  PERSISTENT_PEERS="$(descriptor_get '.network.persistent_peers' || true)"
fi
if [[ -z "$MIN_GAS_PRICES" ]]; then
  MIN_GAS_PRICES="$(descriptor_get '.minimum_gas_prices' || true)"
fi
if [[ -z "$MIN_GAS_PRICES" ]]; then
  MIN_GAS_PRICES="0.000000007anyxt"
fi

if [[ "${YNX_UI_EMBEDDED:-0}" -ne 1 && "${YNX_UI_SUPPRESS_HEADER:-0}" -ne 1 ]]; then
  ynx_ui_banner "Bootstrap chain home" "This stage resolves RPC and descriptor inputs, writes genesis/config, and prepares a fresh machine for joining."
  ynx_ui_plan "Bootstrap order" \
    "Resolve bundle, descriptor, and genesis sources" \
    "Resolve RPC endpoint, chain ID, seeds, and persistent peers" \
    "Fetch and validate genesis from file, bundle, or RPC" \
    "Initialize the chain home and write network ports" \
    "Apply role-specific config and then restore network settings" \
    "Print the exact next commands for key creation and node start"
  ynx_ui_kv "home" "$HOME_DIR"
  ynx_ui_kv "role" "$ROLE"
  ynx_ui_kv "rpc" "${RPC_URL:-auto}"
  ynx_ui_kv "chain_id" "${CHAIN_ID:-auto}"
  ynx_ui_kv "port_offset" "$PORT_OFFSET"
  ynx_ui_kv "statesync" "$ENABLE_STATESYNC"
  ynx_ui_kv "plan_only" "$PLAN_ONLY"
  echo
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

if [[ "${YNX_UI_EMBEDDED:-0}" -ne 1 && "${YNX_UI_SUPPRESS_HEADER:-0}" -ne 1 ]]; then
  ynx_ui_kv "resolved_rpc" "$RPC_URL"
  ynx_ui_kv "resolved_chain_id" "$CHAIN_ID"
  ynx_ui_kv "resolved_moniker" "$MONIKER"
fi

if [[ "$PLAN_ONLY" -eq 1 ]]; then
  ynx_ui_note "Plan-only mode: bootstrap input resolution completed, but no home/config/genesis changes were written."
  exit 0
fi

if [[ "$RESET" -eq 1 ]]; then
  rm -rf "$HOME_DIR"
fi

mkdir -p "$HOME_DIR"
if [[ ! -f "$HOME_DIR/config/config.toml" ]]; then
  "$BIN" init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null 2>&1
fi

if [[ -n "$GENESIS_FILE" ]]; then
  if [[ ! -f "$GENESIS_FILE" ]]; then
    echo "Genesis file not found: $GENESIS_FILE" >&2
    exit 1
  fi
  cp "$GENESIS_FILE" "$HOME_DIR/config/genesis.json"
  if ! validate_genesis_file "$HOME_DIR/config/genesis.json"; then
    echo "Provided genesis file is invalid or chain-id mismatch: $GENESIS_FILE" >&2
    exit 1
  fi
else
  if ! fetch_genesis_chunked "$HOME_DIR/config/genesis.json"; then
    if ! fetch_genesis_full "$HOME_DIR/config/genesis.json"; then
      echo "Failed to fetch a valid genesis via /genesis_chunked and /genesis (provide --genesis-file or --bundle)" >&2
      exit 1
    fi
  fi

  if ! validate_genesis_file "$HOME_DIR/config/genesis.json"; then
    echo "Fetched genesis is invalid or chain-id mismatch for ${CHAIN_ID}" >&2
    exit 1
  fi
fi

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

P2P_PORT=$((36656 + PORT_OFFSET))
RPC_PORT=$((36657 + PORT_OFFSET))
ABCI_PORT=$((36658 + PORT_OFFSET))
API_PORT=$((1317 + PORT_OFFSET))
GRPC_PORT=$((9090 + PORT_OFFSET))
GRPC_WEB_PORT=$((9091 + PORT_OFFSET))
EVM_RPC_PORT=$((8545 + PORT_OFFSET))
EVM_WS_PORT=$((8546 + PORT_OFFSET))

set_top_level_key "$CONFIG_TOML" "moniker" "\"$MONIKER\""
set_top_level_key "$CONFIG_TOML" "seeds" "\"$SEEDS\""
set_top_level_key "$CONFIG_TOML" "persistent_peers" "\"$PERSISTENT_PEERS\""
set_top_level_key "$CONFIG_TOML" "addr_book_strict" "false"
set_top_level_key "$CONFIG_TOML" "proxy_app" "\"tcp://127.0.0.1:${ABCI_PORT}\""
set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://127.0.0.1:${RPC_PORT}\""
set_section_key "$CONFIG_TOML" "p2p" "pex" "true"
set_section_key "$CONFIG_TOML" "p2p" "laddr" "\"tcp://0.0.0.0:${P2P_PORT}\""

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
set_section_key "$APP_TOML" "api" "address" "\"tcp://0.0.0.0:${API_PORT}\""
set_section_key "$APP_TOML" "grpc" "address" "\"0.0.0.0:${GRPC_PORT}\""
set_section_key "$APP_TOML" "grpc-web" "address" "\"0.0.0.0:${GRPC_WEB_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "address" "\"0.0.0.0:${EVM_RPC_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"0.0.0.0:${EVM_WS_PORT}\""

YNX_HOME="$HOME_DIR" "$ROOT_DIR/scripts/v2_role_apply.sh" "$ROLE" >/dev/null

# v2_role_apply may override networking settings. Re-apply desired values.
set_top_level_key "$CONFIG_TOML" "seeds" "\"$SEEDS\""
set_top_level_key "$CONFIG_TOML" "persistent_peers" "\"$PERSISTENT_PEERS\""
set_top_level_key "$CONFIG_TOML" "proxy_app" "\"tcp://127.0.0.1:${ABCI_PORT}\""
set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://127.0.0.1:${RPC_PORT}\""
set_section_key "$CONFIG_TOML" "p2p" "laddr" "\"tcp://0.0.0.0:${P2P_PORT}\""
set_section_key "$APP_TOML" "api" "address" "\"tcp://0.0.0.0:${API_PORT}\""
set_section_key "$APP_TOML" "grpc" "address" "\"0.0.0.0:${GRPC_PORT}\""
set_section_key "$APP_TOML" "grpc-web" "address" "\"0.0.0.0:${GRPC_WEB_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "address" "\"0.0.0.0:${EVM_RPC_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"0.0.0.0:${EVM_WS_PORT}\""

if [[ "${YNX_UI_EMBEDDED:-0}" -ne 1 ]]; then
  echo
  ynx_ui_note "Bootstrap complete"
  ynx_ui_kv "home" "$HOME_DIR"
  ynx_ui_kv "role" "$ROLE"
  ynx_ui_kv "chain_id" "$CHAIN_ID"
  ynx_ui_kv "rpc" "$RPC_URL"
  ynx_ui_kv "statesync" "$statesync_mode"
  ynx_ui_kv "port_offset" "$PORT_OFFSET"
  ynx_ui_kv "p2p_port" "$P2P_PORT"
  ynx_ui_kv "rpc_port" "$RPC_PORT"
  ynx_ui_kv "api_port" "$API_PORT"
  ynx_ui_kv "grpc_port" "$GRPC_PORT"
  ynx_ui_kv "evm_rpc_port" "$EVM_RPC_PORT"
  ynx_ui_kv "seeds" "$SEEDS"
  ynx_ui_kv "persistent_peers" "$PERSISTENT_PEERS"
  if [[ -n "$BUNDLE_DIR" ]]; then
    ynx_ui_kv "bundle" "$BUNDLE_DIR"
  fi
  if [[ -n "$DESCRIPTOR_FILE" ]]; then
    ynx_ui_kv "descriptor" "$DESCRIPTOR_FILE"
  fi
  echo
  ynx_ui_note "Create validator key:"
  echo "$BIN keys add validator --home \"$HOME_DIR\" --keyring-backend os --key-type eth_secp256k1"
  echo
  ynx_ui_note "Start node:"
  echo "$BIN start --home \"$HOME_DIR\" --chain-id \"$CHAIN_ID\" --minimum-gas-prices \"$MIN_GAS_PRICES\""
  echo
  ynx_ui_note "After funding validator account, create validator tx:"
  echo "$BIN tx staking create-validator --amount 100000000000000000000anyxt --pubkey \"\$($BIN comet show-validator --home \"$HOME_DIR\")\" --moniker \"$MONIKER\" --chain-id \"$CHAIN_ID\" --commission-rate 0.10 --commission-max-rate 0.20 --commission-max-change-rate 0.01 --min-self-delegation 1 --from validator --home \"$HOME_DIR\" --keyring-backend os --node \"$RPC_URL\" --gas auto --gas-adjustment 1.2 --gas-prices \"$MIN_GAS_PRICES\""
fi

if [[ "$START" -eq 1 ]]; then
  exec "$BIN" start --home "$HOME_DIR" --chain-id "$CHAIN_ID" --minimum-gas-prices "$MIN_GAS_PRICES"
fi
