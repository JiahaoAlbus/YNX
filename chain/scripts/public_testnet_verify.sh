#!/usr/bin/env bash

set -euo pipefail

HOST="${YNX_PUBLIC_HOST:-43.134.23.58}"
RPC_PORT="${YNX_RPC_PORT:-26657}"
EVM_PORT="${YNX_EVM_PORT:-8545}"
REST_PORT="${YNX_REST_PORT:-1317}"
FAUCET_PORT="${YNX_FAUCET_PORT:-8080}"
INDEXER_PORT="${YNX_INDEXER_PORT:-8081}"
EXPLORER_PORT="${YNX_EXPLORER_PORT:-8082}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9002-1}"
EVM_CHAIN_ID_HEX="${YNX_EVM_CHAIN_ID_HEX:-0x232a}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

BASE="http://${HOST}"
RPC="${BASE}:${RPC_PORT}"
EVM="${BASE}:${EVM_PORT}"
REST="${BASE}:${REST_PORT}"
FAUCET="${BASE}:${FAUCET_PORT}"
INDEXER="${BASE}:${INDEXER_PORT}"
EXPLORER="${BASE}:${EXPLORER_PORT}"

echo "== YNX Public Testnet Verification =="
echo "Host: ${HOST}"

rpc_json="$(curl -fsS --max-time 8 "${RPC}/status")"
rpc_chain="$(echo "$rpc_json" | jq -r '.result.node_info.network')"
rpc_height="$(echo "$rpc_json" | jq -r '.result.sync_info.latest_block_height')"
rpc_syncing="$(echo "$rpc_json" | jq -r '.result.sync_info.catching_up')"
[[ "$rpc_chain" == "$CHAIN_ID" ]] || { echo "RPC chain id mismatch: $rpc_chain"; exit 1; }
[[ "$rpc_height" =~ ^[0-9]+$ ]] || { echo "RPC height invalid: $rpc_height"; exit 1; }

evm_json="$(curl -fsS --max-time 8 -H "content-type: application/json" --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' "${EVM}")"
evm_chain="$(echo "$evm_json" | jq -r '.result')"
[[ "$evm_chain" == "$EVM_CHAIN_ID_HEX" ]] || { echo "EVM chain id mismatch: $evm_chain"; exit 1; }

rest_chain="$(curl -fsS --max-time 8 "${REST}/cosmos/base/tendermint/v1beta1/node_info" | jq -r '.default_node_info.network')"
[[ "$rest_chain" == "$CHAIN_ID" ]] || { echo "REST chain id mismatch: $rest_chain"; exit 1; }

faucet_chain="$(curl -fsS --max-time 8 "${FAUCET}/health" | jq -r '.chain_id')"
[[ "$faucet_chain" == "$CHAIN_ID" ]] || { echo "Faucet chain id mismatch: $faucet_chain"; exit 1; }

indexer_json="$(curl -fsS --max-time 8 "${INDEXER}/health")"
indexer_last="$(echo "$indexer_json" | jq -r '.last_indexed')"
[[ "$indexer_last" =~ ^[0-9]+$ ]] || { echo "Indexer last_indexed invalid: $indexer_last"; exit 1; }

explorer_head="$(curl -fsS --max-time 8 "${EXPLORER}" | head -c 200)"
echo "$explorer_head" | grep -qi "<!DOCTYPE html>" || { echo "Explorer page invalid"; exit 1; }

echo
echo "PASS"
echo "rpc_chain_id=${rpc_chain}"
echo "rpc_height=${rpc_height}"
echo "rpc_catching_up=${rpc_syncing}"
echo "evm_chain_id=${evm_chain}"
echo "indexer_last_indexed=${indexer_last}"

