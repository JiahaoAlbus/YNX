#!/usr/bin/env bash
set -euo pipefail

STRICT=1
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-degraded)
      STRICT=0
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/public_testnet_extreme_readiness.sh [--allow-degraded] [--output-dir DIR]

Read-only public testnet readiness gate.

Environment:
  YNX_MIN_PUBLIC_PEERS       default: 2
  YNX_MIN_VALIDATORS         default: 4
  YNX_BLOCK_ADVANCE_SEC      default: 8
  YNX_FETCH_RETRIES          default: 4
  YNX_FETCH_RETRY_DELAY_SEC  default: 2
  YNX_FETCH_TIMEOUT_SEC      default: 15
  YNX_P2P_PROBE_TIMEOUT_SEC  default: 5
  YNX_EXPECTED_CHAIN_ID      default: ynx_9102-1
  YNX_EXPECTED_EVM_CHAIN_ID  default: 0x238e
  YNX_EXPECTED_TRACK         default: v2-web4
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/output/extreme_readiness_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}/responses"

RPC_STATUS_URL="${YNX_RPC_STATUS_URL:-https://rpc.ynxweb4.com/status}"
RPC_NET_INFO_URL="${YNX_RPC_NET_INFO_URL:-https://rpc.ynxweb4.com/net_info}"
RPC_VALIDATORS_URL="${YNX_RPC_VALIDATORS_URL:-https://rpc.ynxweb4.com/validators?per_page=100}"
EVM_RPC_URL="${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}"
REST_NODE_INFO_URL="${YNX_REST_NODE_INFO_URL:-https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info}"
FAUCET_HEALTH_URL="${YNX_FAUCET_HEALTH_URL:-https://faucet.ynxweb4.com/health}"
INDEXER_HEALTH_URL="${YNX_INDEXER_HEALTH_URL:-https://indexer.ynxweb4.com/health}"
INDEXER_OVERVIEW_URL="${YNX_INDEXER_OVERVIEW_URL:-https://indexer.ynxweb4.com/ynx/overview}"
INDEXER_VALIDATORS_URL="${YNX_INDEXER_VALIDATORS_URL:-https://indexer.ynxweb4.com/validators}"
EXPLORER_CONFIG_URL="${YNX_EXPLORER_CONFIG_URL:-https://explorer.ynxweb4.com/config}"
AI_READY_URL="${YNX_AI_READY_URL:-https://ai.ynxweb4.com/ready}"
WEB4_READY_URL="${YNX_WEB4_READY_URL:-https://web4.ynxweb4.com/ready}"
WEB4_OVERVIEW_URL="${YNX_WEB4_OVERVIEW_URL:-https://web4.ynxweb4.com/web4/overview}"

EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-ynx_9102-1}"
EXPECTED_EVM_CHAIN_ID="${YNX_EXPECTED_EVM_CHAIN_ID:-0x238e}"
EXPECTED_TRACK="${YNX_EXPECTED_TRACK:-v2-web4}"
BLOCK_ADVANCE_SEC="${YNX_BLOCK_ADVANCE_SEC:-8}"
FETCH_RETRIES="${YNX_FETCH_RETRIES:-4}"
FETCH_RETRY_DELAY_SEC="${YNX_FETCH_RETRY_DELAY_SEC:-2}"
FETCH_TIMEOUT_SEC="${YNX_FETCH_TIMEOUT_SEC:-15}"
P2P_PROBE_TIMEOUT_SEC="${YNX_P2P_PROBE_TIMEOUT_SEC:-5}"
MIN_PUBLIC_PEERS="${YNX_MIN_PUBLIC_PEERS:-2}"
MIN_VALIDATORS="${YNX_MIN_VALIDATORS:-4}"

pass=0
fail=0
warn=0
rows=()

record() {
  local status="$1"
  local name="$2"
  local detail="$3"
  rows+=("| ${name} | ${status} | ${detail//|/\\|} |")
  case "$status" in
    PASS) pass=$((pass + 1)) ;;
    WARN) warn=$((warn + 1)) ;;
    FAIL) fail=$((fail + 1)) ;;
  esac
}

fetch() {
  local name="$1"
  local url="$2"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  local tmp="${out}.tmp"
  local attempt=1
  while (( attempt <= FETCH_RETRIES )); do
    if curl -fsS --max-time "$FETCH_TIMEOUT_SEC" "$url" > "$tmp"; then
      mv "$tmp" "$out"
      record PASS "fetch:${name}" "${url} attempt=${attempt}/${FETCH_RETRIES}"
      return
    fi
    rm -f "$tmp"
    if (( attempt < FETCH_RETRIES )); then
      sleep "$FETCH_RETRY_DELAY_SEC"
    fi
    attempt=$((attempt + 1))
  done
  echo "{\"ok\":false,\"error\":\"fetch_failed\",\"url\":\"${url}\",\"attempts\":${FETCH_RETRIES}}" > "$out"
  record FAIL "fetch:${name}" "${url} attempts=${FETCH_RETRIES}"
}

post_json() {
  local name="$1"
  local url="$2"
  local body="$3"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  local tmp="${out}.tmp"
  local attempt=1
  while (( attempt <= FETCH_RETRIES )); do
    if curl -fsS --max-time "$FETCH_TIMEOUT_SEC" -H "content-type: application/json" --data "$body" "$url" > "$tmp"; then
      mv "$tmp" "$out"
      record PASS "fetch:${name}" "${url} attempt=${attempt}/${FETCH_RETRIES}"
      return
    fi
    rm -f "$tmp"
    if (( attempt < FETCH_RETRIES )); then
      sleep "$FETCH_RETRY_DELAY_SEC"
    fi
    attempt=$((attempt + 1))
  done
  echo "{\"ok\":false,\"error\":\"fetch_failed\",\"url\":\"${url}\",\"attempts\":${FETCH_RETRIES}}" > "$out"
  record FAIL "fetch:${name}" "${url} attempts=${FETCH_RETRIES}"
}

probe_tcp() {
  local host="$1"
  local port="$2"
  nc -G "$P2P_PROBE_TIMEOUT_SEC" -z "$host" "$port" >/dev/null 2>&1 && return 0
  nc -w "$P2P_PROBE_TIMEOUT_SEC" -z "$host" "$port" >/dev/null 2>&1 && return 0
  return 1
}

fetch rpc_status "$RPC_STATUS_URL"
sleep "$BLOCK_ADVANCE_SEC"
fetch rpc_status_after "$RPC_STATUS_URL"
fetch rpc_net_info "$RPC_NET_INFO_URL"
fetch rpc_validators "$RPC_VALIDATORS_URL"
fetch rest_node_info "$REST_NODE_INFO_URL"
fetch faucet_health "$FAUCET_HEALTH_URL"
fetch indexer_health "$INDEXER_HEALTH_URL"
fetch indexer_overview "$INDEXER_OVERVIEW_URL"
fetch indexer_validators "$INDEXER_VALIDATORS_URL"
fetch explorer_config "$EXPLORER_CONFIG_URL"
fetch ai_ready "$AI_READY_URL"
fetch web4_ready "$WEB4_READY_URL"
fetch web4_overview "$WEB4_OVERVIEW_URL"

evm_out="${OUTPUT_DIR}/responses/evm_chain_id.json"
post_json evm_chain_id "$EVM_RPC_URL" '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'

rpc_chain="$(jq -r '.result.node_info.network // ""' "${OUTPUT_DIR}/responses/rpc_status.json")"
rest_chain="$(jq -r '.default_node_info.network // ""' "${OUTPUT_DIR}/responses/rest_node_info.json")"
faucet_chain="$(jq -r '.chain_id // ""' "${OUTPUT_DIR}/responses/faucet_health.json")"
indexer_chain="$(jq -r '.chain_id // ""' "${OUTPUT_DIR}/responses/indexer_overview.json")"
track="$(jq -r '.track // ""' "${OUTPUT_DIR}/responses/indexer_overview.json")"
evm_chain="$(jq -r '.result // ""' "$evm_out")"
ai_ready="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/ai_ready.json")"
web4_ready="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/web4_ready.json")"
web4_overview="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/web4_overview.json")"
height_before="$(jq -r '.result.sync_info.latest_block_height // "0"' "${OUTPUT_DIR}/responses/rpc_status.json")"
height_after="$(jq -r '.result.sync_info.latest_block_height // "0"' "${OUTPUT_DIR}/responses/rpc_status_after.json")"
height_delta=0
if [[ "$height_before" =~ ^[0-9]+$ && "$height_after" =~ ^[0-9]+$ ]]; then
  height_delta=$((height_after - height_before))
fi
p2p_peers="$(jq -r '.result.n_peers // "0"' "${OUTPUT_DIR}/responses/rpc_net_info.json")"
validator_total="$(jq -r '.result.total // .total // "0"' "${OUTPUT_DIR}/responses/rpc_validators.json")"
indexer_signed="$(jq -r '.signed_count // "0"' "${OUTPUT_DIR}/responses/indexer_validators.json")"
p2p_reachable=0
p2p_probe_total=0
if command -v nc >/dev/null 2>&1; then
  while IFS= read -r peer_ip; do
    [[ -z "$peer_ip" ]] && continue
    p2p_probe_total=$((p2p_probe_total + 1))
    if probe_tcp "$peer_ip" 36656; then
      p2p_reachable=$((p2p_reachable + 1))
    fi
  done < <(jq -r '.result.peers[]?.remote_ip // empty' "${OUTPUT_DIR}/responses/rpc_net_info.json" | sort -u)
fi

[[ "$rpc_chain" == "$EXPECTED_CHAIN_ID" ]] && record PASS "rpc_chain_id" "$rpc_chain" || record FAIL "rpc_chain_id" "got=${rpc_chain}, expected=${EXPECTED_CHAIN_ID}"
[[ "$rest_chain" == "$EXPECTED_CHAIN_ID" ]] && record PASS "rest_chain_id" "$rest_chain" || record FAIL "rest_chain_id" "got=${rest_chain}, expected=${EXPECTED_CHAIN_ID}"
[[ "$faucet_chain" == "$EXPECTED_CHAIN_ID" ]] && record PASS "faucet_chain_id" "$faucet_chain" || record FAIL "faucet_chain_id" "got=${faucet_chain}, expected=${EXPECTED_CHAIN_ID}"
[[ "$indexer_chain" == "$EXPECTED_CHAIN_ID" ]] && record PASS "indexer_chain_id" "$indexer_chain" || record FAIL "indexer_chain_id" "got=${indexer_chain}, expected=${EXPECTED_CHAIN_ID}"
[[ "$track" == "$EXPECTED_TRACK" ]] && record PASS "track" "$track" || record FAIL "track" "got=${track}, expected=${EXPECTED_TRACK}"
[[ "$evm_chain" == "$EXPECTED_EVM_CHAIN_ID" ]] && record PASS "evm_chain_id" "$evm_chain" || record FAIL "evm_chain_id" "got=${evm_chain}, expected=${EXPECTED_EVM_CHAIN_ID}"
[[ "$ai_ready" == "true" ]] && record PASS "ai_ready" "true" || record FAIL "ai_ready" "$ai_ready"
[[ "$web4_ready" == "true" ]] && record PASS "web4_ready" "true" || record FAIL "web4_ready" "$web4_ready"
[[ "$web4_overview" == "true" ]] && record PASS "web4_overview" "true" || record FAIL "web4_overview" "$web4_overview"
(( height_delta > 0 )) && record PASS "block_advancement" "before=${height_before}, after=${height_after}, delta=${height_delta}" || record FAIL "block_advancement" "before=${height_before}, after=${height_after}, delta=${height_delta}"

if [[ "$p2p_peers" =~ ^[0-9]+$ && "$p2p_peers" -ge "$MIN_PUBLIC_PEERS" ]]; then
  record PASS "public_p2p_peers" "n_peers=${p2p_peers}, min=${MIN_PUBLIC_PEERS}"
else
  record FAIL "public_p2p_peers" "n_peers=${p2p_peers}, min=${MIN_PUBLIC_PEERS}"
fi

if ! command -v nc >/dev/null 2>&1; then
  record WARN "public_p2p_ports" "nc unavailable; skipped TCP probe"
elif [[ "$p2p_reachable" -ge "$MIN_PUBLIC_PEERS" ]]; then
  record PASS "public_p2p_ports" "reachable=${p2p_reachable}/${p2p_probe_total}, min=${MIN_PUBLIC_PEERS}"
else
  record FAIL "public_p2p_ports" "reachable=${p2p_reachable}/${p2p_probe_total}, min=${MIN_PUBLIC_PEERS}"
fi

if [[ "$validator_total" =~ ^[0-9]+$ && "$validator_total" -ge "$MIN_VALIDATORS" ]]; then
  record PASS "validator_set_size" "validators=${validator_total}, min=${MIN_VALIDATORS}"
else
  record FAIL "validator_set_size" "validators=${validator_total}, min=${MIN_VALIDATORS}"
fi

if [[ "$indexer_signed" =~ ^[0-9]+$ && "$indexer_signed" -eq "$validator_total" && "$validator_total" -gt 0 ]]; then
  record PASS "validator_signing" "signed=${indexer_signed}/${validator_total}"
else
  record WARN "validator_signing" "signed=${indexer_signed}/${validator_total}"
fi

report="${OUTPUT_DIR}/EXTREME_READINESS.md"
{
  echo "# YNX Public Testnet Extreme Readiness"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- Strict mode: ${STRICT}"
  echo "- Expected Chain ID: ${EXPECTED_CHAIN_ID}"
  echo "- Expected EVM Chain ID: ${EXPECTED_EVM_CHAIN_ID}"
  echo "- Expected Track: ${EXPECTED_TRACK}"
  echo "- Min public peers: ${MIN_PUBLIC_PEERS}"
  echo "- Min validators: ${MIN_VALIDATORS}"
  echo "- Fetch retries: ${FETCH_RETRIES}"
  echo "- Fetch timeout seconds: ${FETCH_TIMEOUT_SEC}"
  echo "- Passed: ${pass}"
  echo "- Warned: ${warn}"
  echo "- Failed: ${fail}"
  echo
  echo "| Check | Status | Details |"
  echo "|---|---|---|"
  printf '%s\n' "${rows[@]}"
  echo
  if (( fail == 0 )); then
    echo "## Result"
    echo
    echo "PASS"
  else
    echo "## Result"
    echo
    echo "DEGRADED"
  fi
} > "$report"

echo "Extreme readiness report: $report"
echo "PASS=${pass} WARN=${warn} FAIL=${fail}"

if [[ "$STRICT" -eq 1 && "$fail" -gt 0 ]]; then
  exit 1
fi
