#!/usr/bin/env bash

set -euo pipefail

RPC="${YNX_RPC:-http://127.0.0.1:26657}"
JSONRPC="${YNX_JSONRPC:-http://127.0.0.1:8545}"

echo "RPC:     $RPC"
echo "JSONRPC: $JSONRPC"
echo

status_json="$(curl -s "$RPC/status")"
if [[ -z "$status_json" ]]; then
  echo "ERROR: RPC status is empty" >&2
  exit 1
fi

node_id="$(node -e "const s=JSON.parse(process.env.S);console.log(s.result.node_info.id||'')" S="$status_json")"
network="$(node -e "const s=JSON.parse(process.env.S);console.log(s.result.node_info.network||'')" S="$status_json")"
height="$(node -e "const s=JSON.parse(process.env.S);console.log(s.result.sync_info.latest_block_height||'0')" S="$status_json")"
catching_up="$(node -e "const s=JSON.parse(process.env.S);console.log(s.result.sync_info.catching_up||false)" S="$status_json")"

echo "Node ID:     $node_id"
echo "Chain ID:    $network"
echo "Height:      $height"
echo "CatchingUp:  $catching_up"

net_json="$(curl -s "$RPC/net_info")"
peers="$(node -e "const s=JSON.parse(process.env.S);console.log((s.result.peers||[]).length)" S="$net_json")"
echo "Peers:       $peers"

jsonrpc_payload='{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
jsonrpc_resp="$(curl -s -X POST -H "content-type: application/json" --data "$jsonrpc_payload" "$JSONRPC")"
chain_id_hex="$(node -e "const s=JSON.parse(process.env.S);console.log(s.result||'')" S="$jsonrpc_resp")"

if [[ -z "$chain_id_hex" ]]; then
  echo "ERROR: JSON-RPC eth_chainId failed" >&2
  exit 1
fi

echo "EVM ChainId: $chain_id_hex"
echo
echo "Healthcheck OK"
