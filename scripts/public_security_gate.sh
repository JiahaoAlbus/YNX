#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/public_security_gate.sh [--output-dir DIR]

Read-only public security and feature gate for YNX public testnet.
It validates service health, public security headers, unauthorized write-path
rejection, bridge operator gating, Web4 policy controls, AI factual boundaries,
and frontend XSS hardening signals.

Environment:
  YNX_RPC_URL             default: https://rpc.ynxweb4.com
  YNX_EVM_RPC_URL         default: https://evm.ynxweb4.com
  YNX_REST_URL            default: https://rest.ynxweb4.com
  YNX_FAUCET_URL          default: https://faucet.ynxweb4.com
  YNX_INDEXER_URL         default: https://indexer.ynxweb4.com
  YNX_EXPLORER_URL        default: https://explorer.ynxweb4.com
  YNX_AI_URL              default: https://ai.ynxweb4.com
  YNX_WEB4_URL            default: https://web4.ynxweb4.com
  YNX_BRIDGE_URL          default: https://rpc.ynxweb4.com/bridge
  YNX_WEBSITE_URL         default: https://www.ynxweb4.com
  YNX_EXPECTED_CHAIN_ID   default: ynx_9102-1
  YNX_EXPECTED_EVM_CHAIN  default: 0x238e
  YNX_FETCH_TIMEOUT_SEC   default: 15
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

for bin in curl jq date sed awk; do
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
  OUTPUT_DIR="${REPO_ROOT}/output/public_security_gate_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}/responses" "${OUTPUT_DIR}/headers"

RPC_URL="${YNX_RPC_URL:-https://rpc.ynxweb4.com}"
EVM_RPC_URL="${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}"
REST_URL="${YNX_REST_URL:-https://rest.ynxweb4.com}"
FAUCET_URL="${YNX_FAUCET_URL:-https://faucet.ynxweb4.com}"
INDEXER_URL="${YNX_INDEXER_URL:-https://indexer.ynxweb4.com}"
EXPLORER_URL="${YNX_EXPLORER_URL:-https://explorer.ynxweb4.com}"
AI_URL="${YNX_AI_URL:-https://ai.ynxweb4.com}"
WEB4_URL="${YNX_WEB4_URL:-https://web4.ynxweb4.com}"
BRIDGE_URL="${YNX_BRIDGE_URL:-https://rpc.ynxweb4.com/bridge}"
WEBSITE_URL="${YNX_WEBSITE_URL:-https://www.ynxweb4.com}"
EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-ynx_9102-1}"
EXPECTED_EVM_CHAIN="${YNX_EXPECTED_EVM_CHAIN:-0x238e}"
FETCH_TIMEOUT_SEC="${YNX_FETCH_TIMEOUT_SEC:-15}"

pass=0
warn=0
fail=0
rows=()
ai_rows=()

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

record_ai() {
  local aspect="$1"
  local status="$2"
  local detail="$3"
  ai_rows+=("| ${aspect} | ${status} | ${detail//|/\\|} |")
  record "$status" "ai:${aspect}" "$detail"
}

save_json() {
  local name="$1"
  local payload="$2"
  printf '%s\n' "$payload" > "${OUTPUT_DIR}/responses/${name}.json"
}

fetch_json() {
  local name="$1"
  local url="$2"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  if curl -fsS --max-time "$FETCH_TIMEOUT_SEC" "$url" > "$out"; then
    record PASS "fetch:${name}" "$url"
  else
    printf '{"ok":false,"error":"fetch_failed","url":"%s"}\n' "$url" > "$out"
    record FAIL "fetch:${name}" "$url"
  fi
}

fetch_text() {
  local name="$1"
  local url="$2"
  local out="${OUTPUT_DIR}/responses/${name}.txt"
  if curl -fsS --max-time "$FETCH_TIMEOUT_SEC" "$url" > "$out"; then
    record PASS "fetch:${name}" "$url"
  else
    printf 'fetch_failed %s\n' "$url" > "$out"
    record FAIL "fetch:${name}" "$url"
  fi
}

fetch_headers() {
  local name="$1"
  local url="$2"
  local out="${OUTPUT_DIR}/headers/${name}.headers"
  if curl -fsSI --max-time "$FETCH_TIMEOUT_SEC" "$url" > "$out"; then
    record PASS "headers:${name}" "$url"
  else
    : > "$out"
    record WARN "headers:${name}" "header fetch failed: ${url}"
  fi
}

post_json_status() {
  local name="$1"
  local url="$2"
  local body="$3"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  local status
  status="$(curl -sS --max-time "$FETCH_TIMEOUT_SEC" -o "$out" -w '%{http_code}' -H 'content-type: application/json' --data "$body" "$url" || true)"
  if [[ -z "$status" || ! -s "$out" ]]; then
    printf '{"ok":false,"error":"request_failed_or_timed_out","url":"%s"}\n' "$url" > "$out"
    status="${status:-000}"
  fi
  printf '%s' "$status"
}

evm_rpc() {
  local name="$1"
  local method="$2"
  local params="$3"
  local out="${OUTPUT_DIR}/responses/${name}.json"
  jq -n --arg method "$method" --argjson params "$params" \
    '{jsonrpc:"2.0",id:1,method:$method,params:$params}' \
    | curl -fsS --max-time "$FETCH_TIMEOUT_SEC" -H 'content-type: application/json' --data @- "$EVM_RPC_URL" > "$out"
}

assert_status() {
  local name="$1"
  local status="$2"
  local expected_regex="$3"
  local detail="$4"
  if [[ "$status" =~ $expected_regex ]]; then
    record PASS "$name" "status=${status}; ${detail}"
  else
    record FAIL "$name" "status=${status}; expected=${expected_regex}; ${detail}"
  fi
}

assert_header_present() {
  local name="$1"
  local file="$2"
  local header="$3"
  if grep -iq "^${header}:" "$file"; then
    record PASS "header:${name}:${header}" "present"
  else
    record WARN "header:${name}:${header}" "missing or set only at another edge"
  fi
}

assert_no_header_combo() {
  local name="$1"
  local file="$2"
  local header_a="$3"
  local pattern_a="$4"
  local header_b="$5"
  local pattern_b="$6"
  if grep -iq "^${header_a}:.*${pattern_a}" "$file" && grep -iq "^${header_b}:.*${pattern_b}" "$file"; then
    record FAIL "header:${name}:unsafe_combo" "${header_a}=${pattern_a} with ${header_b}=${pattern_b}"
  else
    record PASS "header:${name}:unsafe_combo" "no ${header_a}/${header_b} unsafe combination"
  fi
}

contains_secret_words() {
  local file="$1"
  grep -Eiv '(<runtime-only|runtime-only|placeholder|example|never commit|do not commit|不要提交)' "$file" \
    | grep -Eiq '(private[_-]?key[[:space:]_:-]*[=:][[:space:]]*["'\'']?([A-Za-z0-9+/=_-]{24,}|0x[0-9a-fA-F]{32,})|mnemonic[[:space:]_:-]*[=:]|seed phrase[[:space:]_:-]*[=:]|secret[[:space:]_:-]*[=:][[:space:]]*["'\'']?[A-Za-z0-9+/=_-]{24,}|BEGIN (RSA|EC|OPENSSH)|password[[:space:]_:-]*[=:][[:space:]]*["'\'']?.{8,})'
}

fetch_json rpc_status "${RPC_URL}/status"
fetch_json faucet_health "${FAUCET_URL}/health"
fetch_json indexer_health "${INDEXER_URL}/health"
fetch_json web4_ready "${WEB4_URL}/ready"
fetch_json ai_health "${AI_URL}/health"
fetch_json ai_brief "${AI_URL}/ai/intelligence/brief"
fetch_json ai_actions "${AI_URL}/ai/actions"
fetch_json bridge_health "${BRIDGE_URL}/health"
fetch_json bridge_readiness "${BRIDGE_URL}/route-readiness"
fetch_text website_ai "${WEBSITE_URL}/ai"
fetch_text website_docs_ai "${WEBSITE_URL}/docs/en/ynx-v2-ai-settlement-api.md"
fetch_headers website "${WEBSITE_URL}/"
fetch_headers explorer "${EXPLORER_URL}/"
fetch_headers ai "${AI_URL}/health"
fetch_headers web4 "${WEB4_URL}/ready"
fetch_headers bridge "${BRIDGE_URL}/health"

rpc_chain="$(jq -r '.result.node_info.network // ""' "${OUTPUT_DIR}/responses/rpc_status.json")"
if [[ "$rpc_chain" == "$EXPECTED_CHAIN_ID" ]]; then
  record PASS "chain_id" "$rpc_chain"
else
  record FAIL "chain_id" "got=${rpc_chain}, expected=${EXPECTED_CHAIN_ID}"
fi

if evm_rpc evm_chain_id eth_chainId "[]"; then
  evm_chain="$(jq -r '.result // ""' "${OUTPUT_DIR}/responses/evm_chain_id.json")"
  [[ "$evm_chain" == "$EXPECTED_EVM_CHAIN" ]] && record PASS "evm_chain_id" "$evm_chain" || record FAIL "evm_chain_id" "got=${evm_chain}, expected=${EXPECTED_EVM_CHAIN}"
else
  record FAIL "evm_chain_id" "eth_chainId failed"
fi

for item in faucet_health indexer_health web4_ready ai_health bridge_health; do
  ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/${item}.json")"
  [[ "$ok" == "true" ]] && record PASS "${item}:ok" "ok=true" || record FAIL "${item}:ok" "ok=${ok}"
done

assert_header_present website "${OUTPUT_DIR}/headers/website.headers" "x-content-type-options"
assert_header_present website "${OUTPUT_DIR}/headers/website.headers" "x-frame-options"
assert_header_present website "${OUTPUT_DIR}/headers/website.headers" "content-security-policy"
assert_no_header_combo ai "${OUTPUT_DIR}/headers/ai.headers" "access-control-allow-origin" "\\*" "access-control-allow-credentials" "true"
assert_no_header_combo web4 "${OUTPUT_DIR}/headers/web4.headers" "access-control-allow-origin" "\\*" "access-control-allow-credentials" "true"
assert_no_header_combo bridge "${OUTPUT_DIR}/headers/bridge.headers" "access-control-allow-origin" "\\*" "access-control-allow-credentials" "true"

status="$(post_json_status bridge_scan_unauth "${BRIDGE_URL}/watchers/scan" '{}')"
assert_status "bridge_operator_scan_requires_token" "$status" '^(401|403)$' "/bridge/watchers/scan"
status="$(post_json_status bridge_deposit_prove_unauth "${BRIDGE_URL}/deposits/prove" '{}')"
assert_status "bridge_deposit_prove_requires_token" "$status" '^(401|403)$' "/bridge/deposits/prove"
status="$(post_json_status bridge_withdraw_request_unauth "${BRIDGE_URL}/withdrawals/request" '{}')"
assert_status "bridge_withdraw_request_requires_token" "$status" '^(401|403)$' "/bridge/withdrawals/request"

status="$(post_json_status web4_internal_unauth "${WEB4_URL}/web4/internal/authorize" '{"policy_id":"missing","action":"ai.job.create"}')"
assert_status "web4_internal_authorize_requires_token" "$status" '^(401|403)$' "/web4/internal/authorize"
status="$(post_json_status web4_private_tool_rejected "${WEB4_URL}/web4/tools" '{"tool_id":"security_private_probe","base_url":"http://127.0.0.1:1","allowed_paths":["/"]}')"
assert_status "web4_private_tool_url_rejected" "$status" '^400$' "SSRF guard"
status="$(post_json_status web4_agent_requires_policy "${WEB4_URL}/web4/agents" '{"agent_id":"security_probe_agent"}')"
assert_status "web4_agent_create_requires_policy" "$status" '^(400|401|403)$' "policy/session guard"

status="$(post_json_status ai_job_requires_policy "${AI_URL}/ai/jobs" '{"job_id":"security_probe_job","creator":"probe","reward":"1"}')"
assert_status "ai_job_create_requires_policy" "$status" '^(400|401|403)$' "policy/session guard"
status="$(post_json_status ai_vault_requires_policy "${AI_URL}/ai/vaults" '{"vault_id":"security_probe_vault","owner":"probe","balance":1}')"
assert_status "ai_vault_create_requires_policy" "$status" '^(400|401|403)$' "policy/session guard"
status="$(post_json_status ai_action_monitor_requires_policy "${AI_URL}/ai/actions/run" '{"action":"ai.monitor.create","target":"validators"}')"
assert_status "ai_action_monitor_requires_policy" "$status" '^(400|401|403)$' "AI action policy/session guard"

ai_chat_status="$(post_json_status ai_chat "${AI_URL}/ai/chat" '{"message":"用中文简短总结 YNX 当前 AI 和交易状态。"}')"
assert_status "ai_chat_public" "$ai_chat_status" '^200$' "/ai/chat"
ai_mode="$(jq -r '.mode // ""' "${OUTPUT_DIR}/responses/ai_chat.json")"
ai_model="$(jq -r '.model // ""' "${OUTPUT_DIR}/responses/ai_chat.json")"
ai_answer="$(jq -r '.answer // ""' "${OUTPUT_DIR}/responses/ai_chat.json")"
ai_model_answer="$(jq -r '.model_answer // empty' "${OUTPUT_DIR}/responses/ai_chat.json")"
[[ "$ai_mode" == llm:* || "$ai_mode" == "live-deterministic" ]] && record_ai "server_model_or_live_mode" PASS "mode=${ai_mode}, model=${ai_model}" || record_ai "server_model_or_live_mode" FAIL "mode=${ai_mode}"
[[ "$ai_answer" == *"2/5"* && "$ai_answer" == *"full-loop-tested"* ]] && record_ai "factual_route_boundary" PASS "answer reports exact full-loop route count" || record_ai "factual_route_boundary" FAIL "answer did not report exact 2/5 route count"
[[ -z "$ai_model_answer" || "$ai_model_answer" == "null" ]] && record_ai "model_answer_hidden_by_default" PASS "raw model text hidden unless requested" || record_ai "model_answer_hidden_by_default" FAIL "model_answer exposed by default"

status="$(post_json_status ai_chat_with_model "${AI_URL}/ai/chat" '{"message":"请用中文解释 Intelligence Layer 这个产品定位，三句话。","include_model_answer":true}')"
assert_status "ai_chat_model_answer_opt_in" "$status" '^200$' "include_model_answer"
model_answer_opt="$(jq -r '.model_answer // empty' "${OUTPUT_DIR}/responses/ai_chat_with_model.json")"
health_mode="$(jq -r '.intelligence.mode // ""' "${OUTPUT_DIR}/responses/ai_health.json")"
if [[ "$health_mode" == llm:* ]]; then
  [[ -n "$model_answer_opt" && "$model_answer_opt" != "null" ]] && record_ai "local_llm_opt_in_output" PASS "model_answer returned on opt-in" || record_ai "local_llm_opt_in_output" WARN "model configured but model_answer empty"
else
  record_ai "local_llm_opt_in_output" WARN "LLM not configured; deterministic mode only"
fi

status="$(post_json_status ai_chat_validators "${AI_URL}/ai/chat" '{"message":"我们链验证人的状态怎么样？"}')"
assert_status "ai_chat_validator_status" "$status" '^200$' "validator live status"
validator_answer="$(jq -r '.answer // ""' "${OUTPUT_DIR}/responses/ai_chat_validators.json")"
if [[ "$validator_answer" == *"验证人"* && "$validator_answer" == *"上一块签名"* ]]; then
  record_ai "validator_status_live_answer" PASS "validator answer includes live signing status"
else
  record_ai "validator_status_live_answer" FAIL "validator answer did not include live signing status"
fi

status="$(post_json_status ai_chat_assets "${AI_URL}/ai/chat" '{"message":"给我我们 chain 上面现在能够流通的货币？"}')"
assert_status "ai_chat_circulating_assets" "$status" '^200$' "circulating asset live status"
asset_answer="$(jq -r '.answer // ""' "${OUTPUT_DIR}/responses/ai_chat_assets.json")"
if [[ "$asset_answer" == *"NYXT"* && "$asset_answer" == *"YUSD.test"* && "$asset_answer" == *"wUSDC.y"* && "$asset_answer" == *"wETH.y"* && "$asset_answer" == *"AMM"* ]]; then
  record_ai "circulating_assets_live_answer" PASS "asset answer lists live assets and AMM pairs"
else
  record_ai "circulating_assets_live_answer" FAIL "asset answer did not list live assets and AMM pairs"
fi

actions_count="$(jq -r '.actions | length' "${OUTPUT_DIR}/responses/ai_actions.json")"
if [[ "$actions_count" -ge 8 ]] && jq -e '.actions[] | select(.action=="ai.monitor.create")' "${OUTPUT_DIR}/responses/ai_actions.json" >/dev/null; then
  record_ai "action_catalog_live" PASS "actions=${actions_count}"
else
  record_ai "action_catalog_live" FAIL "AI action catalog missing expected actions"
fi

status="$(post_json_status ai_action_assets "${AI_URL}/ai/actions/run" '{"action":"assets.list"}')"
assert_status "ai_action_assets_list" "$status" '^200$' "AI action assets.list"
action_assets="$(jq -r '.result.assets[]?.symbol' "${OUTPUT_DIR}/responses/ai_action_assets.json" | tr '\n' ' ')"
if [[ "$action_assets" == *"NYXT"* && "$action_assets" == *"YUSD.test"* && "$action_assets" == *"wUSDC.y"* && "$action_assets" == *"wETH.y"* ]]; then
  record_ai "action_assets_live" PASS "$action_assets"
else
  record_ai "action_assets_live" FAIL "assets.list action missing live assets"
fi

ai_onchain="$(jq -r '.intelligence.mode // .ai.model // empty' "${OUTPUT_DIR}/responses/ai_health.json")"
settlement_ready="$(jq -r '.onchain.ready // false' "${OUTPUT_DIR}/responses/ai_health.json")"
stats_jobs="$(jq -r '.stats.total_jobs // 0' "${OUTPUT_DIR}/responses/ai_health.json")"
stats_payments="$(jq -r '.stats.total_payments // 0' "${OUTPUT_DIR}/responses/ai_health.json")"
[[ "$settlement_ready" == "true" ]] && record_ai "onchain_settlement_ready" PASS "YNXAISettlement ready" || record_ai "onchain_settlement_ready" FAIL "settlement_ready=${settlement_ready}"
[[ "$stats_jobs" -ge 7 && "$stats_payments" -ge 7 ]] && record_ai "job_vault_payment_accounting" PASS "jobs=${stats_jobs}, payments=${stats_payments}" || record_ai "job_vault_payment_accounting" FAIL "jobs=${stats_jobs}, payments=${stats_payments}"

route_full="$(jq -r '.summary.full_loop_tested // 0' "${OUTPUT_DIR}/responses/bridge_readiness.json")"
route_total="$(jq -r '.summary.routes // 0' "${OUTPUT_DIR}/responses/bridge_readiness.json")"
[[ "$route_total" -ge 5 && "$route_full" -ge 2 ]] && record PASS "bridge_route_readiness" "full_loop=${route_full}/${route_total}" || record FAIL "bridge_route_readiness" "full_loop=${route_full}/${route_total}"

if grep -q '<div id="root"' "${OUTPUT_DIR}/responses/website_ai.txt"; then
  record_ai "website_ai_console" PASS "${WEBSITE_URL}/ai renders SPA root"
else
  record_ai "website_ai_console" FAIL "${WEBSITE_URL}/ai root missing"
fi

if grep -q "include_model_answer" "${OUTPUT_DIR}/responses/website_docs_ai.txt"; then
  record_ai "docs_ai_contract" PASS "AI docs explain factual answer/model opt-in"
else
  record_ai "docs_ai_contract" FAIL "AI docs missing factual answer/model opt-in"
fi

for file in "${OUTPUT_DIR}"/responses/*.json "${OUTPUT_DIR}"/responses/*.txt; do
  if contains_secret_words "$file"; then
    record FAIL "secret_leak_scan:$(basename "$file")" "secret-like material appeared in public response"
  fi
done

report="${OUTPUT_DIR}/PUBLIC_SECURITY_GATE.md"
{
  echo "# YNX Public Security and Feature Gate"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- RPC: ${RPC_URL}"
  echo "- EVM RPC: ${EVM_RPC_URL}"
  echo "- Website: ${WEBSITE_URL}"
  echo "- AI: ${AI_URL}"
  echo "- Web4: ${WEB4_URL}"
  echo "- Bridge: ${BRIDGE_URL}"
  echo "- Passed: ${pass}"
  echo "- Warned: ${warn}"
  echo "- Failed: ${fail}"
  echo
  echo "## AI Capability Coverage"
  echo
  echo "| AI aspect | Status | Evidence |"
  echo "|---|---|---|"
  printf '%s\n' "${ai_rows[@]}"
  echo
  echo "## Security Checks"
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

echo "Security gate report: $report"
echo "PASS=${pass} WARN=${warn} FAIL=${fail}"

if (( fail > 0 )); then
  exit 1
fi
