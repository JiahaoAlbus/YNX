#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$ROOT_DIR/.."

HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
DENOM="${YNX_DENOM:-anyxt}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${WEB4_PORT:-38091}"
AI_ENFORCE_POLICY="${AI_ENFORCE_POLICY:-1}"
WEB4_ENFORCE_POLICY="${WEB4_ENFORCE_POLICY:-1}"
WEB4_INTERNAL_TOKEN="${WEB4_INTERNAL_TOKEN:-ynx-v2-internal}"
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

echo "Applying port config to v2 home: $HOME_DIR"
"$ROOT_DIR/scripts/v2_ports_apply.sh"

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
  YNX_DENOM="$DENOM" \
  YNX_MIN_GAS_PRICES="0.000000007${DENOM}" \
  YNX_PUBLIC_RPC="${YNX_PUBLIC_RPC:-http://127.0.0.1:${YNX_RPC_PORT}}" \
  YNX_PUBLIC_EVM_RPC="${YNX_PUBLIC_EVM_RPC:-http://127.0.0.1:${YNX_EVM_PORT}}" \
  YNX_PUBLIC_EVM_WS="${YNX_PUBLIC_EVM_WS:-ws://127.0.0.1:${YNX_EVM_WS_PORT}}" \
  YNX_PUBLIC_REST="${YNX_PUBLIC_REST:-http://127.0.0.1:${YNX_REST_PORT}}" \
  YNX_PUBLIC_GRPC="${YNX_PUBLIC_GRPC:-http://127.0.0.1:${YNX_GRPC_PORT}}" \
  YNX_PUBLIC_FAUCET="${YNX_PUBLIC_FAUCET:-http://127.0.0.1:${YNX_FAUCET_PORT:-38080}}" \
  YNX_PUBLIC_INDEXER="${YNX_PUBLIC_INDEXER:-http://127.0.0.1:${YNX_INDEXER_PORT:-38081}}" \
  YNX_PUBLIC_EXPLORER="${YNX_PUBLIC_EXPLORER:-http://127.0.0.1:${YNX_EXPLORER_PORT:-38082}}" \
  YNX_PUBLIC_AI_GATEWAY="${YNX_PUBLIC_AI_GATEWAY:-http://127.0.0.1:${AI_GATEWAY_PORT}}" \
  YNX_PUBLIC_WEB4_HUB="${YNX_PUBLIC_WEB4_HUB:-http://127.0.0.1:${WEB4_PORT}}" \
  YNX_SEEDS="${YNX_SEEDS:-}" \
  YNX_PERSISTENT_PEERS="${YNX_PERSISTENT_PEERS:-}" \
  YNX_BINARY_VERSION="${YNX_BINARY_VERSION:-local-build}" \
  YNX_RELEASE_URL="${YNX_RELEASE_URL:-}" \
  YNX_DESCRIPTOR_URL="${YNX_DESCRIPTOR_URL:-}" \
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
  AI_ENFORCE_POLICY="$AI_ENFORCE_POLICY" \
  AI_WEB4_HUB_URL="http://127.0.0.1:${WEB4_PORT}" \
  AI_WEB4_INTERNAL_TOKEN="$WEB4_INTERNAL_TOKEN" \
  AI_DATA_DIR="$HOME_DIR/ai-gateway-data" \
  "$NODE_BIN" "$PROJECT_ROOT/infra/ai-gateway/server.js"

screen -dmS ynx-v2-web4-hub env \
  WEB4_CHAIN_ID="$CHAIN_ID" \
  WEB4_PORT="$WEB4_PORT" \
  WEB4_ENFORCE_POLICY="$WEB4_ENFORCE_POLICY" \
  WEB4_INTERNAL_TOKEN="$WEB4_INTERNAL_TOKEN" \
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
