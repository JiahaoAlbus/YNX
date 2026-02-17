#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${YNX_BIN:-$ROOT_DIR/ynxd}"
RPC="${YNX_RPC:-http://127.0.0.1:26657}"
JSONRPC="${YNX_JSONRPC:-http://127.0.0.1:8545}"
FAUCET_ADDR="${YNX_FAUCET_ADDRESS:-}"

echo "RPC:     $RPC"
echo "JSONRPC: $JSONRPC"
echo

status_json="$(curl -s "$RPC/status")"
if [[ -z "$status_json" ]]; then
  echo "ERROR: RPC status is empty" >&2
  exit 1
fi

node_id="$(S="$status_json" node -e "const s=JSON.parse(process.env.S);console.log(s.result.node_info.id||'')")"
network="$(S="$status_json" node -e "const s=JSON.parse(process.env.S);console.log(s.result.node_info.network||'')")"
height="$(S="$status_json" node -e "const s=JSON.parse(process.env.S);console.log(s.result.sync_info.latest_block_height||'0')")"
catching_up="$(S="$status_json" node -e "const s=JSON.parse(process.env.S);console.log(s.result.sync_info.catching_up||false)")"

echo "Node ID:     $node_id"
echo "Chain ID:    $network"
echo "Height:      $height"
echo "CatchingUp:  $catching_up"

net_json="$(curl -s "$RPC/net_info")"
peers="$(S="$net_json" node -e "const s=JSON.parse(process.env.S);console.log((s.result.peers||[]).length)")"
echo "Peers:       $peers"

jsonrpc_payload='{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
jsonrpc_resp="$(curl -s -X POST -H "content-type: application/json" --data "$jsonrpc_payload" "$JSONRPC")"
chain_id_hex="$(S="$jsonrpc_resp" node -e "const s=JSON.parse(process.env.S);console.log(s.result||'')")"

if [[ -z "$chain_id_hex" ]]; then
  echo "ERROR: JSON-RPC eth_chainId failed" >&2
  exit 1
fi

echo "EVM ChainId: $chain_id_hex"

if [[ -n "$FAUCET_ADDR" ]]; then
  faucet_json="$("$BIN" query bank balances "$FAUCET_ADDR" --node "$RPC" --output json 2>/dev/null || true)"
  faucet_amount="$(S="$faucet_json" node -e "const s=JSON.parse(process.env.S||'{}');const b=(s.balances||[])[0];console.log((b&&b.amount)||'0')")"
  faucet_denom="$(S="$faucet_json" node -e "const s=JSON.parse(process.env.S||'{}');const b=(s.balances||[])[0];console.log((b&&b.denom)||'')")"
  echo "Faucet Addr: $FAUCET_ADDR"
  echo "Faucet Bal:  ${faucet_amount}${faucet_denom}"
fi

echo
echo "Healthcheck OK"
