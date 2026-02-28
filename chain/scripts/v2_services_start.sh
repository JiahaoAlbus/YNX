#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR/.."

HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
DENOM="${YNX_DENOM:-anyxt}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${WEB4_PORT:-38091}"
WEB4_ENFORCE_POLICY="${WEB4_ENFORCE_POLICY:-0}"
YNX_P2P_PORT="${YNX_P2P_PORT:-36656}"
YNX_RPC_PORT="${YNX_RPC_PORT:-36657}"
YNX_REST_PORT="${YNX_REST_PORT:-31317}"
YNX_GRPC_PORT="${YNX_GRPC_PORT:-39090}"
YNX_EVM_PORT="${YNX_EVM_PORT:-38545}"
YNX_EVM_WS_PORT="${YNX_EVM_WS_PORT:-38546}"
YNX_PROM_PORT="${YNX_PROM_PORT:-36660}"
YNX_PPROF_PORT="${YNX_PPROF_PORT:-36661}"
YNX_GETH_METRICS_PORT="${YNX_GETH_METRICS_PORT:-38100}"

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

NODE_BIN="$(command -v node)"
if [[ -z "$NODE_BIN" ]]; then
  echo "node not found in PATH" >&2
  exit 1
fi

if ! command -v screen >/dev/null 2>&1; then
  echo "screen not found in PATH" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_TOML" || ! -f "$APP_TOML" ]]; then
  echo "Missing config files under $HOME_DIR (run v2_testnet_bootstrap.sh first)" >&2
  exit 1
fi

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

echo "Applying port config to v2 home: $HOME_DIR"
set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://0.0.0.0:${YNX_RPC_PORT}\""
set_section_key "$CONFIG_TOML" "rpc" "pprof_laddr" "\"localhost:${YNX_PPROF_PORT}\""
set_section_key "$CONFIG_TOML" "p2p" "laddr" "\"tcp://0.0.0.0:${YNX_P2P_PORT}\""
set_section_key "$CONFIG_TOML" "instrumentation" "prometheus_listen_addr" "\":${YNX_PROM_PORT}\""
set_section_key "$APP_TOML" "api" "address" "\"tcp://0.0.0.0:${YNX_REST_PORT}\""
set_section_key "$APP_TOML" "grpc" "address" "\"0.0.0.0:${YNX_GRPC_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "address" "\"0.0.0.0:${YNX_EVM_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"0.0.0.0:${YNX_EVM_WS_PORT}\""
set_section_key "$APP_TOML" "evm" "geth-metrics-address" "\"127.0.0.1:${YNX_GETH_METRICS_PORT}\""

screen -dmS ynx-v2-ynxd "$ROOT_DIR/ynxd" start \
  --home "$HOME_DIR" \
  --chain-id "$CHAIN_ID" \
  --minimum-gas-prices "0.000000007${DENOM}" \
  --api.enable \
  --grpc.enable \
  --grpc.address "0.0.0.0:${YNX_GRPC_PORT}" \
  --json-rpc.enable \
  --json-rpc.address "0.0.0.0:${YNX_EVM_PORT}" \
  --json-rpc.ws-address "0.0.0.0:${YNX_EVM_WS_PORT}"

screen -dmS ynx-v2-faucet env \
  FAUCET_HOME="$HOME_DIR" \
  FAUCET_CHAIN_ID="$CHAIN_ID" \
  FAUCET_DENOM="$DENOM" \
  FAUCET_GAS_PRICES="0.000000007${DENOM}" \
  FAUCET_KEYRING_DIR="$HOME_DIR" \
  FAUCET_PORT="${YNX_FAUCET_PORT:-38080}" \
  FAUCET_NODE="http://127.0.0.1:${YNX_RPC_PORT}" \
  FAUCET_DATA_DIR="$HOME_DIR/faucet-data" \
  "$NODE_BIN" "$PROJECT_ROOT/infra/faucet/server.js"

screen -dmS ynx-v2-indexer env \
  INDEXER_RPC="http://127.0.0.1:${YNX_RPC_PORT}" \
  INDEXER_PORT="${YNX_INDEXER_PORT:-38081}" \
  YNX_OVERVIEW_TRACK="v2-web4" \
  INDEXER_DATA_DIR="$HOME_DIR/indexer-data" \
  "$NODE_BIN" "$PROJECT_ROOT/infra/indexer/server.js"

screen -dmS ynx-v2-explorer env \
  EXPLORER_INDEXER="http://127.0.0.1:${YNX_INDEXER_PORT:-38081}" \
  EXPLORER_PORT="${YNX_EXPLORER_PORT:-38082}" \
  "$NODE_BIN" "$PROJECT_ROOT/infra/explorer/server.js"

screen -dmS ynx-v2-ai-gateway env \
  AI_CHAIN_ID="$CHAIN_ID" \
  AI_GATEWAY_PORT="$AI_GATEWAY_PORT" \
  AI_DATA_DIR="$HOME_DIR/ai-gateway-data" \
  "$NODE_BIN" "$PROJECT_ROOT/infra/ai-gateway/server.js"

screen -dmS ynx-v2-web4-hub env \
  WEB4_CHAIN_ID="$CHAIN_ID" \
  WEB4_PORT="$WEB4_PORT" \
  WEB4_ENFORCE_POLICY="$WEB4_ENFORCE_POLICY" \
  WEB4_DATA_DIR="$HOME_DIR/web4-hub-data" \
  "$NODE_BIN" "$PROJECT_ROOT/infra/web4-hub/server.js"

sleep 2

echo "Started YNX v2 services:"
echo "- ynxd         (${YNX_RPC_PORT} / ${YNX_EVM_PORT})"
echo "- faucet       (${YNX_FAUCET_PORT:-38080})"
echo "- indexer      (${YNX_INDEXER_PORT:-38081})"
echo "- explorer     (${YNX_EXPLORER_PORT:-38082})"
echo "- ai-gateway   (${AI_GATEWAY_PORT})"
echo "- web4-hub     (${WEB4_PORT})"
