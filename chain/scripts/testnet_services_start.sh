#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

screen -dmS ynx-ynxd "$ROOT_DIR/ynxd" start \
  --home "$ROOT_DIR/.testnet" \
  --minimum-gas-prices "0anyxt" \
  --json-rpc.enable \
  --json-rpc.address 0.0.0.0:8545 \
  --json-rpc.ws-address 0.0.0.0:8546 \
  --json-rpc.api eth,net,web3

NODE_BIN="$(command -v node)"
if [[ -z "$NODE_BIN" ]]; then
  echo "node not found in PATH" >&2
  exit 1
fi

screen -dmS ynx-faucet "$NODE_BIN" "$ROOT_DIR/../infra/faucet/server.js"
screen -dmS ynx-indexer "$NODE_BIN" "$ROOT_DIR/../infra/indexer/server.js"
screen -dmS ynx-explorer "$NODE_BIN" "$ROOT_DIR/../infra/explorer/server.js"

sleep 2

echo "Started services:"
echo "- ynxd (26657/8545)"
echo "- faucet (8080)"
echo "- indexer (8081)"
echo "- explorer (8082)"
