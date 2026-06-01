#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/public_bridge_full_loop_probe.sh [--output-dir DIR]

Read-only full-loop probe for the YNX public testnet bridge and trading path.
It checks chain liveness, EVM contracts, bridge deposit/withdrawal watchers,
YUSD.test/AMM contracts, and the public website/docs status.

Environment:
  YNX_RPC_STATUS_URL       default: https://rpc.ynxweb4.com/status
  YNX_EVM_RPC_URL          default: https://evm.ynxweb4.com
  YNX_BRIDGE_BASE_URL      default: https://rpc.ynxweb4.com/bridge
  YNX_WEBSITE_URL          default: https://www.ynxweb4.com
  YNX_BLOCK_ADVANCE_SEC    default: 8
  YNX_FETCH_TIMEOUT_SEC    default: 15
  YNX_FETCH_RETRIES        default: 3
  YNX_EXPECTED_CHAIN_ID    default: ynx_9102-1
  YNX_EXPECTED_EVM_CHAIN_ID default: 0x238e
EOF
}

OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for bin in curl jq date; do
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
  OUTPUT_DIR="${REPO_ROOT}/output/public_bridge_full_loop_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}/responses"

RPC_STATUS_URL="${YNX_RPC_STATUS_URL:-https://rpc.ynxweb4.com/status}"
EVM_RPC_URL="${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}"
BRIDGE_BASE_URL="${YNX_BRIDGE_BASE_URL:-https://rpc.ynxweb4.com/bridge}"
WEBSITE_URL="${YNX_WEBSITE_URL:-https://www.ynxweb4.com}"
EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-ynx_9102-1}"
EXPECTED_EVM_CHAIN_ID="${YNX_EXPECTED_EVM_CHAIN_ID:-0x238e}"
BLOCK_ADVANCE_SEC="${YNX_BLOCK_ADVANCE_SEC:-8}"
FETCH_TIMEOUT_SEC="${YNX_FETCH_TIMEOUT_SEC:-15}"
FETCH_RETRIES="${YNX_FETCH_RETRIES:-3}"

BRIDGE_ROUTES_CONFIG="${REPO_ROOT}/infra/bridge-service/config/testnet-routes.json"
YUSD_CONFIG="${REPO_ROOT}/packages/contracts/config/yusd-test-9102.json"
AMM_CONFIG="${REPO_ROOT}/packages/contracts/config/testnet-amm-9102.json"

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
    attempt=$((attempt + 1))
  done
  echo "{\"ok\":false,\"error\":\"fetch_failed\",\"url\":\"${url}\",\"attempts\":${FETCH_RETRIES}}" > "$out"
  record FAIL "fetch:${name}" "${url} attempts=${FETCH_RETRIES}"
}

fetch_text() {
  local name="$1"
  local url="$2"
  local out="${OUTPUT_DIR}/responses/${name}.txt"
  local tmp="${out}.tmp"
  local attempt=1
  while (( attempt <= FETCH_RETRIES )); do
    if curl -fsS --max-time "$FETCH_TIMEOUT_SEC" "$url" > "$tmp"; then
      mv "$tmp" "$out"
      record PASS "fetch:${name}" "${url} attempt=${attempt}/${FETCH_RETRIES}"
      return
    fi
    rm -f "$tmp"
    attempt=$((attempt + 1))
  done
  echo "fetch_failed ${url} attempts=${FETCH_RETRIES}" > "$out"
  record FAIL "fetch:${name}" "${url} attempts=${FETCH_RETRIES}"
}

evm_rpc() {
  local name="$1"
  local method="$2"
  local params="$3"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  jq -n --arg method "$method" --argjson params "$params" \
    '{jsonrpc:"2.0",id:1,method:$method,params:$params}' \
    | curl -fsS --max-time "$FETCH_TIMEOUT_SEC" -H "content-type: application/json" --data @- "$EVM_RPC_URL" > "$out"
}

hex_to_dec() {
  local value="${1#0x}"
  if [[ -z "$value" ]]; then
    echo 0
    return
  fi
  printf "%d" "0x${value}"
}

is_nonzero_hex() {
  local value="${1:-0x}"
  [[ "$value" != "0x" && "$value" != "0x0" && "$value" != "0x00" ]]
}

eth_get_code_check() {
  local name="$1"
  local address="$2"
  if evm_rpc "code_${name}" eth_getCode "[\"${address}\",\"latest\"]"; then
    local code
    code="$(jq -r '.result // "0x"' "${OUTPUT_DIR}/responses/code_${name}.json")"
    if is_nonzero_hex "$code"; then
      record PASS "contract:${name}" "${address} code_bytes=$(( (${#code} - 2) / 2 ))"
    else
      record FAIL "contract:${name}" "${address} has no code"
    fi
  else
    record FAIL "contract:${name}" "${address} eth_getCode failed"
  fi
}

eth_call_uint_check() {
  local name="$1"
  local address="$2"
  local selector="$3"
  local min_value="$4"
  if evm_rpc "call_${name}" eth_call "[{\"to\":\"${address}\",\"data\":\"${selector}\"},\"latest\"]"; then
    local raw value
    raw="$(jq -r '.result // "0x0"' "${OUTPUT_DIR}/responses/call_${name}.json")"
    value="$(hex_to_dec "$raw")"
    if [[ "$value" =~ ^[0-9]+$ && "$value" -ge "$min_value" ]]; then
      record PASS "call:${name}" "value=${value}, min=${min_value}"
    else
      record FAIL "call:${name}" "value=${value}, min=${min_value}"
    fi
  else
    record FAIL "call:${name}" "${address} ${selector} failed"
  fi
}

fetch rpc_status "$RPC_STATUS_URL"
sleep "$BLOCK_ADVANCE_SEC"
fetch rpc_status_after "$RPC_STATUS_URL"
fetch bridge_health "${BRIDGE_BASE_URL}/health"
fetch bridge_routes "${BRIDGE_BASE_URL}/routes"
fetch bridge_assets "${BRIDGE_BASE_URL}/assets"
fetch bridge_source_status "${BRIDGE_BASE_URL}/source-status"
fetch bridge_route_checks "${BRIDGE_BASE_URL}/route-checks"
fetch bridge_route_readiness "${BRIDGE_BASE_URL}/route-readiness"
fetch bridge_watchers "${BRIDGE_BASE_URL}/watchers"
fetch bridge_withdrawal_watchers "${BRIDGE_BASE_URL}/withdrawal-watchers"
fetch bridge_withdrawals "${BRIDGE_BASE_URL}/withdrawals"
fetch_text website_withdraw "${WEBSITE_URL}/withdraw"
fetch_text website_readiness "${WEBSITE_URL}/readiness"
fetch_text docs_public_asset_status "${WEBSITE_URL}/docs/en/public-asset-status.md"

if evm_rpc evm_chain_id eth_chainId "[]"; then
  record PASS "fetch:evm_chain_id" "$EVM_RPC_URL"
else
  record FAIL "fetch:evm_chain_id" "$EVM_RPC_URL"
fi
if evm_rpc evm_block_number eth_blockNumber "[]"; then
  record PASS "fetch:evm_block_number" "$EVM_RPC_URL"
else
  record FAIL "fetch:evm_block_number" "$EVM_RPC_URL"
fi

rpc_chain="$(jq -r '.result.node_info.network // ""' "${OUTPUT_DIR}/responses/rpc_status.json")"
height_before="$(jq -r '.result.sync_info.latest_block_height // "0"' "${OUTPUT_DIR}/responses/rpc_status.json")"
height_after="$(jq -r '.result.sync_info.latest_block_height // "0"' "${OUTPUT_DIR}/responses/rpc_status_after.json")"
height_delta=0
if [[ "$height_before" =~ ^[0-9]+$ && "$height_after" =~ ^[0-9]+$ ]]; then
  height_delta=$((height_after - height_before))
fi
evm_chain="$(jq -r '.result // ""' "${OUTPUT_DIR}/responses/evm_chain_id.json")"
evm_block="$(jq -r '.result // "0x0"' "${OUTPUT_DIR}/responses/evm_block_number.json")"

[[ "$rpc_chain" == "$EXPECTED_CHAIN_ID" ]] && record PASS "rpc_chain_id" "$rpc_chain" || record FAIL "rpc_chain_id" "got=${rpc_chain}, expected=${EXPECTED_CHAIN_ID}"
(( height_delta > 0 )) && record PASS "block_advancement" "before=${height_before}, after=${height_after}, delta=${height_delta}" || record FAIL "block_advancement" "before=${height_before}, after=${height_after}, delta=${height_delta}"
[[ "$evm_chain" == "$EXPECTED_EVM_CHAIN_ID" ]] && record PASS "evm_chain_id" "$evm_chain" || record FAIL "evm_chain_id" "got=${evm_chain}, expected=${EXPECTED_EVM_CHAIN_ID}"
record PASS "evm_block_number" "$(hex_to_dec "$evm_block")"

health_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/bridge_health.json")"
onchain_ready="$(jq -r '.onchain.ready // false' "${OUTPUT_DIR}/responses/bridge_health.json")"
withdraw_release_enabled="$(jq -r '.onchain.withdrawal_release_enabled // false' "${OUTPUT_DIR}/responses/bridge_health.json")"
source_relayer_configured="$(jq -r '.onchain.source_relayer_configured // false' "${OUTPUT_DIR}/responses/bridge_health.json")"
routes_count="$(jq -r '[.items[]?] | length' "${OUTPUT_DIR}/responses/bridge_routes.json")"
route_failures="$(jq -r '[.items[]? | select(.ok != true)] | length' "${OUTPUT_DIR}/responses/bridge_route_checks.json")"
full_loop_ready_routes="$(jq -r '.summary.full_loop_ready // 0' "${OUTPUT_DIR}/responses/bridge_route_readiness.json")"
full_loop_tested_routes="$(jq -r '.summary.full_loop_tested // 0' "${OUTPUT_DIR}/responses/bridge_route_readiness.json")"
mapped_only_routes="$(jq -r '.summary.mapped_route_only // 0' "${OUTPUT_DIR}/responses/bridge_route_readiness.json")"
deposit_watcher_count="$(jq -r '(.items // {}) | keys | length' "${OUTPUT_DIR}/responses/bridge_watchers.json")"
deposit_watcher_errors="$(jq -r '[.items[]? | select((.last_error // "") != "")] | length' "${OUTPUT_DIR}/responses/bridge_watchers.json")"
withdraw_watcher_count="$(jq -r '(.items // {}) | keys | length' "${OUTPUT_DIR}/responses/bridge_withdrawal_watchers.json")"
withdraw_watcher_errors="$(jq -r '[.items[]? | select((.last_error // "") != "")] | length' "${OUTPUT_DIR}/responses/bridge_withdrawal_watchers.json")"
minted_deposits="$(jq -r '.stats.minted_deposits // 0' "${OUTPUT_DIR}/responses/bridge_health.json")"
released_withdrawals="$(jq -r '.stats.released_withdrawals // 0' "${OUTPUT_DIR}/responses/bridge_health.json")"
withdrawal_items="$(jq -r '[.items[]?] | length' "${OUTPUT_DIR}/responses/bridge_withdrawals.json")"
released_items="$(jq -r '[.items[]? | select(.status == "released" and (.release.tx_hash // "") != "")] | length' "${OUTPUT_DIR}/responses/bridge_withdrawals.json")"

[[ "$health_ok" == "true" ]] && record PASS "bridge_health" "ok=true" || record FAIL "bridge_health" "ok=${health_ok}"
[[ "$onchain_ready" == "true" ]] && record PASS "bridge_onchain_ready" "true" || record FAIL "bridge_onchain_ready" "$onchain_ready"
[[ "$withdraw_release_enabled" == "true" ]] && record PASS "withdrawal_release_enabled" "true" || record FAIL "withdrawal_release_enabled" "$withdraw_release_enabled"
[[ "$source_relayer_configured" == "true" ]] && record PASS "source_relayer_configured" "true" || record FAIL "source_relayer_configured" "$source_relayer_configured"
[[ "$routes_count" == "5" ]] && record PASS "bridge_routes" "routes=${routes_count}" || record FAIL "bridge_routes" "routes=${routes_count}, expected=5"
[[ "$route_failures" == "0" ]] && record PASS "bridge_route_checks" "failures=0" || record FAIL "bridge_route_checks" "failures=${route_failures}"
[[ "$full_loop_ready_routes" -ge 2 ]] && record PASS "route_readiness_full_loop_ready" "full_loop_ready=${full_loop_ready_routes}" || record FAIL "route_readiness_full_loop_ready" "full_loop_ready=${full_loop_ready_routes}, expected>=2"
[[ "$full_loop_tested_routes" -ge 1 ]] && record PASS "route_readiness_full_loop_tested" "full_loop_tested=${full_loop_tested_routes}, mapped_only=${mapped_only_routes}" || record FAIL "route_readiness_full_loop_tested" "full_loop_tested=${full_loop_tested_routes}, expected>=1"
[[ "$deposit_watcher_count" -ge 2 && "$deposit_watcher_errors" == "0" ]] && record PASS "deposit_watchers" "routes=${deposit_watcher_count}, errors=${deposit_watcher_errors}" || record FAIL "deposit_watchers" "routes=${deposit_watcher_count}, errors=${deposit_watcher_errors}"
[[ "$withdraw_watcher_count" == "5" && "$withdraw_watcher_errors" == "0" ]] && record PASS "withdrawal_watchers" "routes=${withdraw_watcher_count}, errors=${withdraw_watcher_errors}" || record FAIL "withdrawal_watchers" "routes=${withdraw_watcher_count}, errors=${withdraw_watcher_errors}"
[[ "$minted_deposits" -ge 2 ]] && record PASS "deposit_mint_evidence" "minted=${minted_deposits}" || record FAIL "deposit_mint_evidence" "minted=${minted_deposits}, expected>=2"
[[ "$released_withdrawals" -ge 1 && "$withdrawal_items" -ge 1 && "$released_items" -ge 1 ]] && record PASS "withdraw_release_evidence" "released=${released_withdrawals}, items=${withdrawal_items}, released_items=${released_items}" || record FAIL "withdraw_release_evidence" "released=${released_withdrawals}, items=${withdrawal_items}, released_items=${released_items}"

gateway="$(jq -r '.gateway // empty' "$BRIDGE_ROUTES_CONFIG")"
yusd_token="$(jq -r '.token // empty' "$YUSD_CONFIG")"
eth_call_uint_check yusd_decimals "$yusd_token" "0x313ce567" 6
eth_get_code_check gateway "$gateway"
eth_get_code_check yusd "$yusd_token"

while IFS=$'\t' read -r symbol token decimals; do
  [[ -z "$symbol" || -z "$token" ]] && continue
  eth_get_code_check "wrapped_${symbol}" "$token"
  eth_call_uint_check "decimals_${symbol}" "$token" "0x313ce567" "$decimals"
done < <(jq -r '.routes[] | [.wrappedSymbol, .wrappedToken, .decimals] | @tsv' "$BRIDGE_ROUTES_CONFIG")

while IFS=$'\t' read -r label pair; do
  [[ -z "$label" || -z "$pair" ]] && continue
  safe_label="${label//[^A-Za-z0-9_]/_}"
  eth_get_code_check "amm_${safe_label}" "$pair"
  eth_call_uint_check "amm_${safe_label}_reserve0" "$pair" "0x443cb4bc" 1
  eth_call_uint_check "amm_${safe_label}_reserve1" "$pair" "0x5a76f25e" 1
done < <(jq -r '.pairs[] | [.label, .pair] | @tsv' "$AMM_CONFIG")

if grep -q "2026-06-01" "${OUTPUT_DIR}/responses/docs_public_asset_status.txt" \
  && grep -q "Sepolia USDC release tx" "${OUTPUT_DIR}/responses/docs_public_asset_status.txt"; then
  record PASS "website_docs_bridge_status" "public asset status is current"
else
  record FAIL "website_docs_bridge_status" "missing 2026-06-01 or release tx"
fi

if grep -q '<div id="root">' "${OUTPUT_DIR}/responses/website_withdraw.txt"; then
  record PASS "website_withdraw_page" "${WEBSITE_URL}/withdraw"
else
  record FAIL "website_withdraw_page" "app root missing"
fi

if grep -q '<div id="root">' "${OUTPUT_DIR}/responses/website_readiness.txt"; then
  record PASS "website_readiness_page" "${WEBSITE_URL}/readiness"
else
  record FAIL "website_readiness_page" "app root missing"
fi

report="${OUTPUT_DIR}/PUBLIC_BRIDGE_FULL_LOOP.md"
{
  echo "# YNX Public Bridge Full Loop Probe"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- RPC chain: ${rpc_chain}"
  echo "- RPC height: ${height_before} -> ${height_after}"
  echo "- EVM chain: ${evm_chain}"
  echo "- Bridge base: ${BRIDGE_BASE_URL}"
  echo "- Website: ${WEBSITE_URL}"
  echo "- Passed: ${pass}"
  echo "- Warned: ${warn}"
  echo "- Failed: ${fail}"
  echo
  echo "| Check | Status | Details |"
  echo "|---|---|---|"
  printf '%s\n' "${rows[@]}"
  echo
  echo "## Result"
  echo
  if (( fail == 0 )); then
    echo "PASS"
  else
    echo "FAIL"
  fi
} > "$report"

echo "Full-loop report: $report"
echo "PASS=${pass} WARN=${warn} FAIL=${fail}"

if (( fail > 0 )); then
  exit 1
fi
