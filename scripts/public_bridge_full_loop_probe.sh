#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/public_bridge_full_loop_probe.sh [--output-dir DIR]

Read-only public Testnet bridge boundary probe. It verifies the current chain,
coordinator, provider observation and fail-closed external-execution state. A
transparent unavailable route is a PASS; it is never reported as a full loop.
EOF
}

OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done
for bin in curl jq date; do command -v "$bin" >/dev/null || { echo "$bin is required" >&2; exit 1; }; done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STAMP="$(date +"%Y%m%d_%H%M%S")"
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/output/public_bridge_boundary_${STAMP}}"
mkdir -p "${OUTPUT_DIR}/responses"
RPC_URL="${YNX_RPC_URL:-https://rpc.ynxweb4.com}"
EVM_URL="${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}"
BRIDGE_URL="${YNX_BRIDGE_URL:-https://bridge.ynxweb4.com}"
EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-6423}"
EXPECTED_EVM_CHAIN_ID="${YNX_EXPECTED_EVM_CHAIN_ID:-0x1917}"
TIMEOUT="${YNX_FETCH_TIMEOUT_SEC:-15}"; RETRIES="${YNX_FETCH_RETRIES:-3}"; ADVANCE="${YNX_BLOCK_ADVANCE_SEC:-8}"
pass=0; fail=0; warn=0; rows=()

record() { rows+=("| $2 | $1 | ${3//|/\\|} |"); case "$1" in PASS) pass=$((pass+1));; WARN) warn=$((warn+1));; FAIL) fail=$((fail+1));; esac; }
fetch() {
  local name="$1" url="$2" out="${OUTPUT_DIR}/responses/$1.json" attempt
  for ((attempt=1; attempt<=RETRIES; attempt++)); do
    if curl -fsS --max-time "$TIMEOUT" "$url" > "${out}.tmp"; then mv "${out}.tmp" "$out"; record PASS "fetch:$name" "$url attempt=$attempt/$RETRIES"; return; fi
  done
  printf '{"ok":false,"error":"fetch_failed"}\n' > "$out"; record FAIL "fetch:$name" "$url attempts=$RETRIES"
}
evm() {
  jq -n --arg method "$2" '{jsonrpc:"2.0",id:1,method:$method,params:[]}' | curl -fsS --max-time "$TIMEOUT" -H 'content-type: application/json' --data @- "$EVM_URL" > "${OUTPUT_DIR}/responses/$1.json"
}

fetch rpc_before "${RPC_URL}/status"; sleep "$ADVANCE"; fetch rpc_after "${RPC_URL}/status"
fetch bridge_health "${BRIDGE_URL}/health"
fetch bridge_status "${BRIDGE_URL}/bridge/status"
fetch bridge_routes "${BRIDGE_URL}/bridge/routes"
fetch bridge_providers "${BRIDGE_URL}/bridge/providers"
fetch bridge_transparency "${BRIDGE_URL}/bridge/transparency"
if evm evm_chain_id eth_chainId; then record PASS fetch:evm_chain_id "$EVM_URL"; else record FAIL fetch:evm_chain_id "$EVM_URL"; fi
if evm evm_block_number eth_blockNumber; then record PASS fetch:evm_block_number "$EVM_URL"; else record FAIL fetch:evm_block_number "$EVM_URL"; fi

before="$(jq -r '.height // 0' "${OUTPUT_DIR}/responses/rpc_before.json")"; after="$(jq -r '.height // 0' "${OUTPUT_DIR}/responses/rpc_after.json")"
[[ "$(jq -r '.chainId // 0' "${OUTPUT_DIR}/responses/rpc_after.json")" == "$EXPECTED_CHAIN_ID" ]] && record PASS rpc_chain_id "$EXPECTED_CHAIN_ID" || record FAIL rpc_chain_id "expected=$EXPECTED_CHAIN_ID"
((after > before)) && record PASS block_advancement "before=$before after=$after" || record FAIL block_advancement "before=$before after=$after"
[[ "$(jq -r '.result // ""' "${OUTPUT_DIR}/responses/evm_chain_id.json")" == "$EXPECTED_EVM_CHAIN_ID" ]] && record PASS evm_chain_id "$EXPECTED_EVM_CHAIN_ID" || record FAIL evm_chain_id "expected=$EXPECTED_EVM_CHAIN_ID"
[[ "$(jq -r '.result // "0x0"' "${OUTPUT_DIR}/responses/evm_block_number.json")" != 0x0 ]] && record PASS evm_block_number 'nonzero' || record FAIL evm_block_number 'zero'

health="${OUTPUT_DIR}/responses/bridge_health.json"; status="${OUTPUT_DIR}/responses/bridge_status.json"; routes="${OUTPUT_DIR}/responses/bridge_routes.json"
[[ "$(jq -r '.ok // false' "$health")" == true ]] && record PASS bridge_process 'ok=true' || record FAIL bridge_process 'ok=false'
[[ "$(jq -r '.nativeSymbol // ""' "$health")" == YNXT ]] && record PASS bridge_native_asset YNXT || record FAIL bridge_native_asset 'expected=YNXT'
[[ "$(jq -r 'has("externalSubmissionEnabled") and (.externalSubmissionEnabled == false)' "$health")" == true ]] && record PASS external_submission_boundary 'disabled' || record FAIL external_submission_boundary 'unexpectedly enabled or absent'
[[ "$(jq -r 'has("liveBridge") and (.liveBridge == false)' "$health")" == true ]] && record PASS live_bridge_claim 'false' || record FAIL live_bridge_claim 'unexpectedly true or absent'
[[ "$(jq -r 'has("externalSubmissionEnabled") and (.externalSubmissionEnabled == false)' "$status")" == true ]] && record PASS status_external_execution 'disabled' || record FAIL status_external_execution 'unexpectedly enabled or absent'
[[ "$(jq -r 'has("userAssetMovementEnabled") and (.userAssetMovementEnabled == false)' "$status")" == true ]] && record PASS user_asset_movement 'disabled' || record FAIL user_asset_movement 'unexpectedly enabled or absent'
[[ "$(jq -r 'has("deployedPublic") and (.deployedPublic == false)' "$status")" == true ]] && record PASS product_deployment_claim 'false' || record FAIL product_deployment_claim 'unexpectedly true or absent'
route_count="$(jq -r '.routes | length' "$routes")"; unavailable="$(jq -r '[.routes[] | select(.availability=="unavailable" and .executable==false and .externalSubmissionEnabled==false)] | length' "$routes")"
((route_count > 0)) && [[ "$unavailable" == "$route_count" ]] && record PASS fail_closed_routes "routes=$route_count unavailable=$unavailable" || record FAIL fail_closed_routes "routes=$route_count unavailable=$unavailable"
[[ "$(jq -r '.capabilities.readOnlyEvidence // false' "$status")" == true ]] && record PASS readonly_evidence 'available' || record FAIL readonly_evidence 'unavailable'
[[ "$(jq -r '.capabilities | has("quoteExecution") and (.quoteExecution == false)' "$status")" == true ]] && record PASS quote_execution 'disabled' || record FAIL quote_execution 'unexpectedly enabled or absent'
[[ "$(jq -r '.reconciliation | has("independentVerification") and (.independentVerification == false)' "$status")" == true ]] && record PASS reconciliation_boundary 'not independently verified' || record FAIL reconciliation_boundary 'unexpected independent claim or absent'

report="${OUTPUT_DIR}/PUBLIC_BRIDGE_BOUNDARY.md"
{
  echo '# YNX Public Bridge Boundary Probe'; echo
  echo "- Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"; echo "- Chain: ${EXPECTED_CHAIN_ID} / ${EXPECTED_EVM_CHAIN_ID}"
  echo '- Result semantics: process availability and fail-closed route truthfulness; not an external-chain full-loop proof.'
  echo "- Passed: $pass"; echo "- Warned: $warn"; echo "- Failed: $fail"; echo
  echo '| Check | Status | Details |'; echo '|---|---|---|'; printf '%s\n' "${rows[@]}"; echo
  ((fail==0)) && echo 'PASS' || echo 'FAIL'
} > "$report"
echo "Bridge boundary report: $report"; echo "PASS=$pass WARN=$warn FAIL=$fail"
((fail==0))
