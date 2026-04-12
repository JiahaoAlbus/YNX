#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_cluster_sync_verify.sh <host1> <host2> [host3...]

Verify YNX v2 cluster node sync and service health for a host list.

Host format:
  - ip
  - domain
  - user@host   (user is ignored; host part is used for HTTP checks)

Environment:
  YNX_RPC_PORT         default: 36657
  YNX_EVM_PORT         default: 38545
  YNX_FAUCET_PORT      default: 38080
  YNX_INDEXER_PORT     default: 38081
  YNX_AI_GATEWAY_PORT  default: 38090
  YNX_WEB4_PORT        default: 38091
  HEIGHT_SPREAD_MAX    default: 8
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "$#" -lt 2 ]]; then
  usage
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

YNX_RPC_PORT="${YNX_RPC_PORT:-36657}"
YNX_EVM_PORT="${YNX_EVM_PORT:-38545}"
YNX_FAUCET_PORT="${YNX_FAUCET_PORT:-38080}"
YNX_INDEXER_PORT="${YNX_INDEXER_PORT:-38081}"
YNX_AI_GATEWAY_PORT="${YNX_AI_GATEWAY_PORT:-38090}"
YNX_WEB4_PORT="${YNX_WEB4_PORT:-38091}"
HEIGHT_SPREAD_MAX="${HEIGHT_SPREAD_MAX:-8}"

hosts=()
for raw in "$@"; do
  host="${raw##*@}"
  hosts+=("$host")
done

chain_ids=()
heights=()
catching=()
block_hashes=()
evm_chain_ids=()

min_height=""
max_height=0

for i in "${!hosts[@]}"; do
  host="${hosts[$i]}"
  status_json="$(curl -fsS --max-time 5 "http://${host}:${YNX_RPC_PORT}/status")"
  chain_ids[$i]="$(echo "$status_json" | jq -r '.result.node_info.network')"
  heights[$i]="$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height | tonumber')"
  catching[$i]="$(echo "$status_json" | jq -r '.result.sync_info.catching_up')"

  if [[ -z "$min_height" || "${heights[$i]}" -lt "$min_height" ]]; then
    min_height="${heights[$i]}"
  fi
  if [[ "${heights[$i]}" -gt "$max_height" ]]; then
    max_height="${heights[$i]}"
  fi

  evm_chain_ids[$i]="$(curl -fsS --max-time 5 \
    -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
    "http://${host}:${YNX_EVM_PORT}" | jq -r '.result')"

  curl -fsS --max-time 5 "http://${host}:${YNX_FAUCET_PORT}/health" >/dev/null
  curl -fsS --max-time 5 "http://${host}:${YNX_INDEXER_PORT}/health" >/dev/null
  curl -fsS --max-time 5 "http://${host}:${YNX_AI_GATEWAY_PORT}/health" | jq -e '.ok == true' >/dev/null
  curl -fsS --max-time 5 "http://${host}:${YNX_WEB4_PORT}/ready" | jq -e '.ok == true' >/dev/null
done

if [[ -z "$min_height" || "$min_height" -le 0 ]]; then
  echo "Invalid cluster height detected." >&2
  exit 1
fi

if [[ "$min_height" -gt 10 ]]; then
  target_height=$((min_height - 10))
else
  target_height="$min_height"
fi

base_hash=""
base_chain=""
for i in "${!hosts[@]}"; do
  host="${hosts[$i]}"
  block_hashes[$i]="$(curl -fsS --max-time 5 "http://${host}:${YNX_RPC_PORT}/block?height=${target_height}" | jq -r '.result.block_id.hash')"
  if [[ -z "$base_hash" ]]; then
    base_hash="${block_hashes[$i]}"
    base_chain="${chain_ids[$i]}"
  fi
  if [[ "${block_hashes[$i]}" != "$base_hash" ]]; then
    echo "Block hash mismatch at height $target_height: $host has ${block_hashes[$i]}, expected $base_hash" >&2
    exit 1
  fi
  if [[ "${chain_ids[$i]}" != "$base_chain" ]]; then
    echo "Chain ID mismatch: $host has ${chain_ids[$i]}, expected $base_chain" >&2
    exit 1
  fi
  if [[ "${catching[$i]}" != "false" ]]; then
    echo "Node still catching up: $host" >&2
    exit 1
  fi
done

height_spread=$((max_height - min_height))
if [[ "$height_spread" -gt "$HEIGHT_SPREAD_MAX" ]]; then
  echo "Height spread too large: ${height_spread} (max ${HEIGHT_SPREAD_MAX})" >&2
  exit 1
fi

echo "PASS cluster sync + health"
echo "target_height=$target_height"
echo "chain_id=$base_chain"
echo "reference_block_hash=$base_hash"
for i in "${!hosts[@]}"; do
  host="${hosts[$i]}"
  echo "$host height=${heights[$i]} catching_up=${catching[$i]} evm_chain_id=${evm_chain_ids[$i]}"
done
