#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/public_ai_onchain_settlement_probe.sh [--output-dir DIR]

Read-only public AI and Web4 chain-binding probe. It deliberately verifies the
settlement boundary instead of claiming an on-chain AI settlement that the
current public gateway does not expose.
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
OUTPUT_DIR="${OUTPUT_DIR:-${REPO_ROOT}/output/public_ai_chain_binding_${STAMP}}"
mkdir -p "${OUTPUT_DIR}/responses"
AI_URL="${YNX_AI_URL:-https://ai.ynxweb4.com}"
WEB4_URL="${YNX_WEB4_URL:-https://web4.ynxweb4.com}"
EXPECTED_NUMERIC_CHAIN_ID="${YNX_EXPECTED_NUMERIC_CHAIN_ID:-6423}"
EXPECTED_COSMOS_CHAIN_ID="${YNX_EXPECTED_COSMOS_CHAIN_ID:-ynx_6423-1}"
TIMEOUT="${YNX_FETCH_TIMEOUT_SEC:-15}"
RETRIES="${YNX_FETCH_RETRIES:-3}"
pass=0; fail=0; rows=()

record() { rows+=("| $2 | $1 | ${3//|/\\|} |"); [[ "$1" == PASS ]] && pass=$((pass+1)) || fail=$((fail+1)); }
fetch() {
  local name="$1" url="$2" out="${OUTPUT_DIR}/responses/$1.json" attempt
  for ((attempt=1; attempt<=RETRIES; attempt++)); do
    if curl -fsS --max-time "$TIMEOUT" "$url" > "${out}.tmp"; then mv "${out}.tmp" "$out"; record PASS "fetch:$name" "$url attempt=$attempt/$RETRIES"; return; fi
  done
  printf '{"ok":false,"error":"fetch_failed"}\n' > "$out"; record FAIL "fetch:$name" "$url attempts=$RETRIES"
}

fetch ai_health "${AI_URL}/health"
fetch web4_health "${WEB4_URL}/health"
ai="${OUTPUT_DIR}/responses/ai_health.json"; web4="${OUTPUT_DIR}/responses/web4_health.json"
[[ "$(jq -r '.ok // false' "$ai")" == true ]] && record PASS ai_health 'ok=true' || record FAIL ai_health 'ok=false'
[[ "$(jq -r '.chainId // 0' "$ai")" == "$EXPECTED_NUMERIC_CHAIN_ID" ]] && record PASS ai_chain_id "$EXPECTED_NUMERIC_CHAIN_ID" || record FAIL ai_chain_id "expected=$EXPECTED_NUMERIC_CHAIN_ID"
[[ "$(jq -r '.nativeSymbol // ""' "$ai")" == YNXT ]] && record PASS ai_native_asset YNXT || record FAIL ai_native_asset 'expected=YNXT'
[[ "$(jq -r '.upstreamOk // false' "$ai")" == true ]] && record PASS ai_chain_upstream 'connected' || record FAIL ai_chain_upstream 'not connected'
[[ "$(jq -r '.providerConfigured // false' "$ai")" == true ]] && record PASS ai_provider_config 'configured' || record FAIL ai_provider_config 'not configured'
[[ "$(jq -r '.truthfulStatus // ""' "$ai")" == chain-context-and-provider-backed-ai-gateway ]] && record PASS ai_truthful_status 'chain-context-and-provider-backed-ai-gateway' || record FAIL ai_truthful_status 'unexpected status'
[[ "$(jq -r '.ok // false' "$web4")" == true ]] && record PASS web4_health 'ok=true' || record FAIL web4_health 'ok=false'
[[ "$(jq -r '.chain_id // ""' "$web4")" == "$EXPECTED_COSMOS_CHAIN_ID" ]] && record PASS web4_chain_id "$EXPECTED_COSMOS_CHAIN_ID" || record FAIL web4_chain_id "expected=$EXPECTED_COSMOS_CHAIN_ID"
[[ "$(jq -r '.chain_binding.verified // false' "$web4")" == true ]] && record PASS web4_chain_binding 'verified=true' || record FAIL web4_chain_binding 'verified=false'
[[ "$(jq -r '.chain_binding.observed.native_symbol // ""' "$web4")" == YNXT ]] && record PASS web4_native_asset YNXT || record FAIL web4_native_asset 'expected=YNXT'

report="${OUTPUT_DIR}/PUBLIC_AI_CHAIN_BINDING.md"
{
  echo '# YNX Public AI Chain-Binding and Settlement Boundary Probe'; echo
  echo "- Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
  echo '- Scope: public health, provider configuration, and exact current-chain binding.'
  echo '- Boundary: this probe does not claim an on-chain AI settlement transaction.'
  echo "- Passed: ${pass}"; echo "- Failed: ${fail}"; echo
  echo '| Check | Status | Details |'; echo '|---|---|---|'; printf '%s\n' "${rows[@]}"; echo
  ((fail==0)) && echo 'PASS' || echo 'FAIL'
} > "$report"
echo "AI chain-binding report: $report"; echo "PASS=$pass FAIL=$fail"
((fail==0))
