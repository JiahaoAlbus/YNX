#!/usr/bin/env bash

set -euo pipefail

HOST="${YNX_PUBLIC_HOST:-127.0.0.1}"
RPC_PORT="${YNX_RPC_PORT:-36657}"
EVM_PORT="${YNX_EVM_PORT:-38545}"
REST_PORT="${YNX_REST_PORT:-31317}"
FAUCET_PORT="${YNX_FAUCET_PORT:-38080}"
INDEXER_PORT="${YNX_INDEXER_PORT:-38081}"
EXPLORER_PORT="${YNX_EXPLORER_PORT:-38082}"
AI_GATEWAY_PORT="${YNX_AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${YNX_WEB4_PORT:-38091}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
EVM_CHAIN_ID_HEX="${YNX_EVM_CHAIN_ID_HEX:-0x238e}"
TRACK="${YNX_TRACK:-v2-web4}"
BLOCK_ADVANCE_SEC="${YNX_VERIFY_BLOCK_ADVANCE_SEC:-6}"
SMOKE_WRITE="${YNX_SMOKE_WRITE:-0}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

curl_get_retry() {
  local url="$1"
  local attempts="${2:-45}"
  local sleep_sec="${3:-2}"
  local out=""
  for _ in $(seq 1 "$attempts"); do
    out="$(curl -fsS --max-time 8 "$url" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      echo "$out"
      return 0
    fi
    sleep "$sleep_sec"
  done
  return 1
}

curl_post_retry() {
  local url="$1"
  local body="$2"
  local attempts="${3:-45}"
  local sleep_sec="${4:-2}"
  local out=""
  for _ in $(seq 1 "$attempts"); do
    out="$(curl -fsS --max-time 8 -H "content-type: application/json" --data "$body" "$url" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      echo "$out"
      return 0
    fi
    sleep "$sleep_sec"
  done
  return 1
}

BASE="http://${HOST}"
RPC="${BASE}:${RPC_PORT}"
EVM="${BASE}:${EVM_PORT}"
REST="${BASE}:${REST_PORT}"
FAUCET="${BASE}:${FAUCET_PORT}"
INDEXER="${BASE}:${INDEXER_PORT}"
EXPLORER="${BASE}:${EXPLORER_PORT}"
AI="${BASE}:${AI_GATEWAY_PORT}"
WEB4="${BASE}:${WEB4_PORT}"

echo "== YNX v2 Public Testnet Verification =="
echo "Host: ${HOST}"

rpc_json="$(curl_get_retry "${RPC}/status")" || { echo "RPC not reachable: ${RPC}/status"; exit 1; }
rpc_chain="$(echo "$rpc_json" | jq -r '.result.node_info.network')"
rpc_height="$(echo "$rpc_json" | jq -r '.result.sync_info.latest_block_height')"
rpc_syncing="$(echo "$rpc_json" | jq -r '.result.sync_info.catching_up')"
[[ "$rpc_chain" == "$CHAIN_ID" ]] || { echo "RPC chain id mismatch: $rpc_chain"; exit 1; }
[[ "$rpc_height" =~ ^[0-9]+$ ]] || { echo "RPC height invalid: $rpc_height"; exit 1; }

sleep "$BLOCK_ADVANCE_SEC"
rpc_json_next="$(curl_get_retry "${RPC}/status" 12 1)" || { echo "RPC unreachable after wait: ${RPC}/status"; exit 1; }
rpc_height_next="$(echo "$rpc_json_next" | jq -r '.result.sync_info.latest_block_height')"
[[ "$rpc_height_next" =~ ^[0-9]+$ ]] || { echo "RPC next height invalid: $rpc_height_next"; exit 1; }
if (( rpc_height_next <= rpc_height )); then
  echo "RPC height did not advance: before=${rpc_height} after=${rpc_height_next}" >&2
  exit 1
fi

evm_json="$(curl_post_retry "${EVM}" '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}')" || { echo "EVM RPC not reachable: ${EVM}"; exit 1; }
evm_chain="$(echo "$evm_json" | jq -r '.result')"
[[ "$evm_chain" == "$EVM_CHAIN_ID_HEX" ]] || { echo "EVM chain id mismatch: $evm_chain"; exit 1; }

rest_chain="$(curl_get_retry "${REST}/cosmos/base/tendermint/v1beta1/node_info" | jq -r '.default_node_info.network')" || { echo "REST not reachable: ${REST}"; exit 1; }
[[ "$rest_chain" == "$CHAIN_ID" ]] || { echo "REST chain id mismatch: $rest_chain"; exit 1; }

faucet_chain="$(curl_get_retry "${FAUCET}/health" | jq -r '.chain_id')" || { echo "Faucet not reachable: ${FAUCET}"; exit 1; }
[[ "$faucet_chain" == "$CHAIN_ID" ]] || { echo "Faucet chain id mismatch: $faucet_chain"; exit 1; }

indexer_json="$(curl_get_retry "${INDEXER}/health")" || { echo "Indexer not reachable: ${INDEXER}"; exit 1; }
indexer_chain="$(echo "$indexer_json" | jq -r '.chain_id')"
indexer_last="$(echo "$indexer_json" | jq -r '.last_indexed')"
indexer_seen="$(echo "$indexer_json" | jq -r '.latest_seen')"
[[ "$indexer_chain" == "$CHAIN_ID" ]] || { echo "Indexer chain id mismatch: $indexer_chain"; exit 1; }
[[ "$indexer_last" =~ ^[0-9]+$ ]] || { echo "Indexer last_indexed invalid: $indexer_last"; exit 1; }
[[ "$indexer_seen" =~ ^[0-9]+$ ]] || { echo "Indexer latest_seen invalid: $indexer_seen"; exit 1; }

overview_json="$(curl_get_retry "${INDEXER}/ynx/overview")" || { echo "Overview not reachable: ${INDEXER}/ynx/overview"; exit 1; }
overview_chain="$(echo "$overview_json" | jq -r '.chain_id')"
overview_track="$(echo "$overview_json" | jq -r '.track')"
overview_ai="$(echo "$overview_json" | jq -r '.value_proposition.ai_native_settlement')"
overview_web4="$(echo "$overview_json" | jq -r '.value_proposition.web4_orientation')"
[[ "$overview_chain" == "$CHAIN_ID" ]] || { echo "Overview chain id mismatch: $overview_chain"; exit 1; }
[[ "$overview_track" == "$TRACK" ]] || { echo "Overview track mismatch: $overview_track"; exit 1; }
[[ "$overview_ai" == "true" ]] || { echo "Overview ai flag invalid: $overview_ai"; exit 1; }
[[ "$overview_web4" == "true" ]] || { echo "Overview web4 flag invalid: $overview_web4"; exit 1; }

descriptor_json="$(curl_get_retry "${INDEXER}/ynx/network-descriptor")" || { echo "Network descriptor not reachable: ${INDEXER}/ynx/network-descriptor"; exit 1; }
descriptor_chain="$(echo "$descriptor_json" | jq -r '.chain_id')"
descriptor_rpc="$(echo "$descriptor_json" | jq -r '.endpoints.rpc')"
[[ "$descriptor_chain" == "$CHAIN_ID" ]] || { echo "Descriptor chain id mismatch: $descriptor_chain"; exit 1; }
[[ -n "$descriptor_rpc" && "$descriptor_rpc" != "null" ]] || { echo "Descriptor rpc missing"; exit 1; }

explorer_head="$(curl_get_retry "${EXPLORER}" | head -c 600)" || { echo "Explorer not reachable: ${EXPLORER}"; exit 1; }
echo "$explorer_head" | grep -qi "<!DOCTYPE html>" || { echo "Explorer page invalid"; exit 1; }
echo "$explorer_head" | grep -qi "YNX Web4 Explorer" || { echo "Explorer title invalid"; exit 1; }

ai_health="$(curl_get_retry "${AI}/health")" || { echo "AI gateway not reachable: ${AI}/health"; exit 1; }
ai_chain="$(echo "$ai_health" | jq -r '.chain_id')"
ai_enforce_policy="$(echo "$ai_health" | jq -r '.enforce_policy')"
[[ "$ai_chain" == "$CHAIN_ID" ]] || { echo "AI gateway chain id mismatch: $ai_chain"; exit 1; }
[[ "$ai_enforce_policy" == "true" ]] || { echo "AI gateway policy enforcement disabled"; exit 1; }
ai_ready="$(curl_get_retry "${AI}/ready")" || { echo "AI gateway readiness not reachable: ${AI}/ready"; exit 1; }
ai_ready_ok="$(echo "$ai_ready" | jq -r '.ok')"
[[ "$ai_ready_ok" == "true" ]] || { echo "AI gateway readiness invalid"; exit 1; }
ai_stats="$(curl_get_retry "${AI}/ai/stats")" || { echo "AI stats not reachable: ${AI}/ai/stats"; exit 1; }
ai_ok="$(echo "$ai_stats" | jq -r '.ok')"
[[ "$ai_ok" == "true" ]] || { echo "AI stats invalid"; exit 1; }
ai_vaults="$(curl_get_retry "${AI}/ai/vaults")" || { echo "AI vault endpoint not reachable: ${AI}/ai/vaults"; exit 1; }
ai_vaults_ok="$(echo "$ai_vaults" | jq -r '.ok')"
[[ "$ai_vaults_ok" == "true" ]] || { echo "AI vault endpoint invalid"; exit 1; }
x402_code="$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "${AI}/x402/resource?resource=verify&units=1" || true)"
[[ "$x402_code" == "402" || "$x402_code" == "200" ]] || { echo "x402 endpoint invalid http_code=$x402_code"; exit 1; }

web4_health="$(curl_get_retry "${WEB4}/health")" || { echo "Web4 hub not reachable: ${WEB4}/health"; exit 1; }
web4_chain="$(echo "$web4_health" | jq -r '.chain_id')"
web4_track="$(echo "$web4_health" | jq -r '.track')"
web4_enforce_policy="$(echo "$web4_health" | jq -r '.enforce_policy')"
[[ "$web4_chain" == "$CHAIN_ID" ]] || { echo "Web4 hub chain id mismatch: $web4_chain"; exit 1; }
[[ "$web4_track" == "$TRACK" ]] || { echo "Web4 hub track mismatch: $web4_track"; exit 1; }
[[ "$web4_enforce_policy" == "true" ]] || { echo "Web4 hub policy enforcement disabled"; exit 1; }
web4_ready="$(curl_get_retry "${WEB4}/ready")" || { echo "Web4 readiness not reachable: ${WEB4}/ready"; exit 1; }
web4_ready_ok="$(echo "$web4_ready" | jq -r '.ok')"
[[ "$web4_ready_ok" == "true" ]] || { echo "Web4 readiness invalid"; exit 1; }
web4_overview="$(curl_get_retry "${WEB4}/web4/overview")" || { echo "Web4 overview not reachable: ${WEB4}/web4/overview"; exit 1; }
web4_ok="$(echo "$web4_overview" | jq -r '.ok')"
[[ "$web4_ok" == "true" ]] || { echo "Web4 overview invalid"; exit 1; }
web4_policies="$(curl_get_retry "${WEB4}/web4/policies")" || { echo "Web4 policies not reachable: ${WEB4}/web4/policies"; exit 1; }
web4_policies_ok="$(echo "$web4_policies" | jq -r '.ok')"
[[ "$web4_policies_ok" == "true" ]] || { echo "Web4 policies endpoint invalid"; exit 1; }

if [[ "$SMOKE_WRITE" == "1" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  YNX_PUBLIC_HOST="$HOST" \
  YNX_AI_GATEWAY_PORT="$AI_GATEWAY_PORT" \
  YNX_WEB4_PORT="$WEB4_PORT" \
  YNX_EXPECT_CHAIN_ID="$CHAIN_ID" \
  YNX_EXPECT_TRACK="$TRACK" \
  "$script_dir/v2_public_testnet_smoke.sh"
fi

echo
echo "PASS"
echo "rpc_chain_id=${rpc_chain}"
echo "rpc_height=${rpc_height_next}"
echo "rpc_catching_up=${rpc_syncing}"
echo "evm_chain_id=${evm_chain}"
echo "indexer_last_indexed=${indexer_last}"
echo "overview_track=${overview_track}"
echo "descriptor_rpc=${descriptor_rpc}"
echo "ai_gateway_chain_id=${ai_chain}"
echo "web4_track=${web4_track}"
