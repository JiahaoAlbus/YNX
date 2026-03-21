#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

OUTPUT_DIR="${REPO_ROOT}/output/runtime_evidence_${STAMP_LOCAL}"
STRICT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --allow-degraded)
      STRICT=0
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

RPC_STATUS_URL="${YNX_RPC_STATUS_URL:-https://rpc.ynxweb4.com/status}"
EVM_RPC_URL="${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}"
REST_NODE_INFO_URL="${YNX_REST_NODE_INFO_URL:-https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info}"
FAUCET_HEALTH_URL="${YNX_FAUCET_HEALTH_URL:-https://faucet.ynxweb4.com/health}"
INDEXER_OVERVIEW_URL="${YNX_INDEXER_OVERVIEW_URL:-https://indexer.ynxweb4.com/ynx/overview}"
INDEXER_HEALTH_URL="${YNX_INDEXER_HEALTH_URL:-https://indexer.ynxweb4.com/health}"
INDEXER_VALIDATORS_URL="${YNX_INDEXER_VALIDATORS_URL:-https://indexer.ynxweb4.com/validators}"
EXPLORER_CONFIG_URL="${YNX_EXPLORER_CONFIG_URL:-https://explorer.ynxweb4.com/config}"
AI_HEALTH_URL="${YNX_AI_HEALTH_URL:-https://ai.ynxweb4.com/health}"
WEB4_OVERVIEW_URL="${YNX_WEB4_OVERVIEW_URL:-https://web4.ynxweb4.com/web4/overview}"

EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-ynx_9102-1}"
EXPECTED_EVM_CHAIN_ID_HEX="${YNX_EXPECTED_EVM_CHAIN_ID_HEX:-0x238e}"
EXPECTED_TRACK="${YNX_EXPECTED_TRACK:-v2-web4}"

mkdir -p "${OUTPUT_DIR}/responses"

PASS_COUNT=0
FAIL_COUNT=0

check_ok() {
  PASS_COUNT=$((PASS_COUNT + 1))
}

check_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

fetch_json() {
  local name="$1"
  local url="$2"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  if curl -fsS --max-time 15 "${url}" > "${out}"; then
    check_ok
  else
    echo "{\"ok\":false,\"error\":\"fetch_failed\",\"url\":\"${url}\"}" > "${out}"
    check_fail
  fi
}

fetch_json rpc_status "${RPC_STATUS_URL}"
fetch_json rest_node_info "${REST_NODE_INFO_URL}"
fetch_json faucet_health "${FAUCET_HEALTH_URL}"
fetch_json indexer_overview "${INDEXER_OVERVIEW_URL}"
fetch_json indexer_health "${INDEXER_HEALTH_URL}"
fetch_json indexer_validators "${INDEXER_VALIDATORS_URL}"
fetch_json explorer_config "${EXPLORER_CONFIG_URL}"
fetch_json ai_health "${AI_HEALTH_URL}"
fetch_json web4_overview "${WEB4_OVERVIEW_URL}"

EVM_OUT="${OUTPUT_DIR}/responses/evm_chain_id.json"
if curl -fsS --max-time 15 -H "content-type: application/json" --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' "${EVM_RPC_URL}" > "${EVM_OUT}"; then
  check_ok
else
  echo '{"ok":false,"error":"fetch_failed"}' > "${EVM_OUT}"
  check_fail
fi

rpc_chain_id="$(jq -r '.result.node_info.network // empty' "${OUTPUT_DIR}/responses/rpc_status.json" 2>/dev/null || true)"
rest_chain_id="$(jq -r '.default_node_info.network // empty' "${OUTPUT_DIR}/responses/rest_node_info.json" 2>/dev/null || true)"
faucet_chain_id="$(jq -r '.chain_id // empty' "${OUTPUT_DIR}/responses/faucet_health.json" 2>/dev/null || true)"
overview_chain_id="$(jq -r '.chain_id // empty' "${OUTPUT_DIR}/responses/indexer_overview.json" 2>/dev/null || true)"
overview_track="$(jq -r '.track // empty' "${OUTPUT_DIR}/responses/indexer_overview.json" 2>/dev/null || true)"
evm_chain_id="$(jq -r '.result // empty' "${OUTPUT_DIR}/responses/evm_chain_id.json" 2>/dev/null || true)"
web4_ok="$(jq -r '.ok // empty' "${OUTPUT_DIR}/responses/web4_overview.json" 2>/dev/null || true)"
ai_chain_id="$(jq -r '.chain_id // empty' "${OUTPUT_DIR}/responses/ai_health.json" 2>/dev/null || true)"

if [[ "${rpc_chain_id}" == "${EXPECTED_CHAIN_ID}" ]]; then check_ok; else check_fail; fi
if [[ "${rest_chain_id}" == "${EXPECTED_CHAIN_ID}" ]]; then check_ok; else check_fail; fi
if [[ "${faucet_chain_id}" == "${EXPECTED_CHAIN_ID}" ]]; then check_ok; else check_fail; fi
if [[ "${overview_chain_id}" == "${EXPECTED_CHAIN_ID}" ]]; then check_ok; else check_fail; fi
if [[ "${overview_track}" == "${EXPECTED_TRACK}" ]]; then check_ok; else check_fail; fi
if [[ "${evm_chain_id}" == "${EXPECTED_EVM_CHAIN_ID_HEX}" ]]; then check_ok; else check_fail; fi
if [[ "${ai_chain_id}" == "${EXPECTED_CHAIN_ID}" ]]; then check_ok; else check_fail; fi
if [[ "${web4_ok}" == "true" ]]; then check_ok; else check_fail; fi

{
  echo "# YNX Public Runtime Evidence"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- Expected Chain ID: ${EXPECTED_CHAIN_ID}"
  echo "- Expected EVM Chain ID: ${EXPECTED_EVM_CHAIN_ID_HEX}"
  echo "- Expected Track: ${EXPECTED_TRACK}"
  echo "- Checks passed: ${PASS_COUNT}"
  echo "- Checks failed: ${FAIL_COUNT}"
  echo
  echo "## Endpoint values"
  echo
  echo "- rpc_chain_id: ${rpc_chain_id:-n/a}"
  echo "- rest_chain_id: ${rest_chain_id:-n/a}"
  echo "- faucet_chain_id: ${faucet_chain_id:-n/a}"
  echo "- indexer_chain_id: ${overview_chain_id:-n/a}"
  echo "- indexer_track: ${overview_track:-n/a}"
  echo "- evm_chain_id: ${evm_chain_id:-n/a}"
  echo "- ai_chain_id: ${ai_chain_id:-n/a}"
  echo "- web4_overview_ok: ${web4_ok:-n/a}"
  echo
  echo "## Source endpoints"
  echo
  echo "- ${RPC_STATUS_URL}"
  echo "- ${EVM_RPC_URL}"
  echo "- ${REST_NODE_INFO_URL}"
  echo "- ${FAUCET_HEALTH_URL}"
  echo "- ${INDEXER_OVERVIEW_URL}"
  echo "- ${INDEXER_HEALTH_URL}"
  echo "- ${INDEXER_VALIDATORS_URL}"
  echo "- ${EXPLORER_CONFIG_URL}"
  echo "- ${AI_HEALTH_URL}"
  echo "- ${WEB4_OVERVIEW_URL}"
} > "${OUTPUT_DIR}/RUNTIME_EVIDENCE.md"

if [[ "${STRICT}" -eq 1 && "${FAIL_COUNT}" -gt 0 ]]; then
  echo "Runtime evidence captured with failures: ${OUTPUT_DIR}/RUNTIME_EVIDENCE.md" >&2
  exit 1
fi

echo "Runtime evidence captured:"
echo "- ${OUTPUT_DIR}/RUNTIME_EVIDENCE.md"
