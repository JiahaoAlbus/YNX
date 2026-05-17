#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/public_uptime_slo_probe.sh [--once]

Read-only public endpoint SLO probe for the YNX Web4 public testnet.
It records latency/status for public HTTPS surfaces, writes JSONL samples,
emits a Markdown report, and can post state-change alerts.

Environment:
  CHECK_INTERVAL_SEC        default: 60
  OUTPUT_BASE_DIR           default: output/public_uptime_slo
  ALERT_WEBHOOK_URL         optional; receives JSON POSTs
  ALERT_COOLDOWN_SEC        default: 900
  FETCH_TIMEOUT_SEC         default: 12
  LATENCY_WARN_MS           default: 5000
  LATENCY_CRITICAL_MS       default: 10000
  YNX_EXPECTED_CHAIN_ID     default: ynx_9102-1
  YNX_EXPECTED_EVM_CHAIN_ID default: 0x238e

Examples:
  scripts/public_uptime_slo_probe.sh --once
  ALERT_WEBHOOK_URL=https://example/hook scripts/public_uptime_slo_probe.sh
EOF
}

ONCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --once)
      ONCE=1
      shift
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
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-${REPO_ROOT}/output/public_uptime_slo}"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-60}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-900}"
FETCH_TIMEOUT_SEC="${FETCH_TIMEOUT_SEC:-12}"
LATENCY_WARN_MS="${LATENCY_WARN_MS:-5000}"
LATENCY_CRITICAL_MS="${LATENCY_CRITICAL_MS:-10000}"
EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-ynx_9102-1}"
EXPECTED_EVM_CHAIN_ID="${YNX_EXPECTED_EVM_CHAIN_ID:-0x238e}"

mkdir -p "${OUTPUT_BASE_DIR}"

SAMPLES_JSONL="${OUTPUT_BASE_DIR}/samples.jsonl"
LATEST_JSON="${OUTPUT_BASE_DIR}/latest.json"
REPORT_MD="${OUTPUT_BASE_DIR}/LATEST_REPORT.md"

last_state=""
last_alert_at=0

probe_get() {
  local key="$1"
  local url="$2"
  local expect="$3"
  local tmp
  tmp="$(mktemp)"
  local meta code time_total latency_ms status error body ok
  meta="$(curl -sS -L --max-time "${FETCH_TIMEOUT_SEC}" -o "$tmp" -w "%{http_code} %{time_total}" "$url" 2>/dev/null || echo "000 0")"
  code="${meta%% *}"
  time_total="${meta#* }"
  latency_ms="$(awk -v t="$time_total" 'BEGIN { printf "%d", (t * 1000) }')"
  body="$(cat "$tmp" 2>/dev/null || true)"
  rm -f "$tmp"
  ok=false
  status="offline"
  error=""
  if [[ "$code" =~ ^[23][0-9][0-9]$ || "$expect" == "grpc" && "$code" == "415" ]]; then
    ok=true
    status="online"
  else
    error="http_${code}"
  fi
  if [[ "$status" == "online" && "$latency_ms" -ge "$LATENCY_CRITICAL_MS" ]]; then
    status="offline"
    error="latency_critical"
  elif [[ "$status" == "online" && "$latency_ms" -ge "$LATENCY_WARN_MS" ]]; then
    status="degraded"
    error="latency_warn"
  fi
  if [[ -n "$expect" && "$ok" == true ]]; then
    case "$expect" in
      chain_id)
        if ! jq -e --arg chain "$EXPECTED_CHAIN_ID" '(.result.node_info.network? // .default_node_info.network? // .chain_id? // "") == $chain' >/dev/null 2>&1 <<<"$body"; then
          ok=false
          status="offline"
          error="chain_id_mismatch"
        fi
        ;;
      web4)
        if ! jq -e '.ok == true and .service == "ynx-web4-hub"' >/dev/null 2>&1 <<<"$body"; then
          ok=false
          status="offline"
          error="web4_health_mismatch"
        fi
        ;;
      ai)
        if ! jq -e '.ok == true and .service == "ynx-ai-gateway"' >/dev/null 2>&1 <<<"$body"; then
          ok=false
          status="offline"
          error="ai_health_mismatch"
        fi
        ;;
    esac
  fi
  jq -n \
    --arg key "$key" \
    --arg url "$url" \
    --arg status "$status" \
    --arg error "$error" \
    --argjson code "${code:-0}" \
    --argjson latency_ms "$latency_ms" \
    '{key:$key,url:$url,status:$status,http_code:$code,latency_ms:$latency_ms,error:$error}'
}

probe_evm() {
  local tmp meta code time_total latency_ms body status error
  tmp="$(mktemp)"
  meta="$(curl -sS --max-time "${FETCH_TIMEOUT_SEC}" -o "$tmp" -w "%{http_code} %{time_total}" \
    -H "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
    "${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}" 2>/dev/null || echo "000 0")"
  code="${meta%% *}"
  time_total="${meta#* }"
  latency_ms="$(awk -v t="$time_total" 'BEGIN { printf "%d", (t * 1000) }')"
  body="$(cat "$tmp" 2>/dev/null || true)"
  rm -f "$tmp"
  status="online"
  error=""
  if [[ ! "$code" =~ ^[23][0-9][0-9]$ ]]; then
    status="offline"
    error="http_${code}"
  elif ! jq -e --arg evm "$EXPECTED_EVM_CHAIN_ID" '.result == $evm' >/dev/null 2>&1 <<<"$body"; then
    status="offline"
    error="evm_chain_id_mismatch"
  elif [[ "$latency_ms" -ge "$LATENCY_CRITICAL_MS" ]]; then
    status="offline"
    error="latency_critical"
  elif [[ "$latency_ms" -ge "$LATENCY_WARN_MS" ]]; then
    status="degraded"
    error="latency_warn"
  fi
  jq -n \
    --arg key "evm" \
    --arg url "${YNX_EVM_RPC_URL:-https://evm.ynxweb4.com}" \
    --arg status "$status" \
    --arg error "$error" \
    --argjson code "${code:-0}" \
    --argjson latency_ms "$latency_ms" \
    '{key:$key,url:$url,status:$status,http_code:$code,latency_ms:$latency_ms,error:$error}'
}

post_alert() {
  local state="$1"
  local message="$2"
  local now ts
  now="$(date +%s)"
  if [[ "$state" == "$last_state" && $((now - last_alert_at)) -lt "$ALERT_COOLDOWN_SEC" ]]; then
    return 0
  fi
  last_state="$state"
  last_alert_at="$now"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] $message"
  if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
    jq -n --arg ts "$ts" --arg state "$state" --arg message "$message" --arg report "$REPORT_MD" \
      '{ts:$ts,state:$state,message:$message,report:$report}' \
      | curl -fsS --max-time 10 -H "content-type: application/json" --data @- "$ALERT_WEBHOOK_URL" >/dev/null || true
  fi
}

run_once() {
  local ts results summary online degraded offline state
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  results="$(
    {
      probe_get website "${YNX_WEBSITE_URL:-https://www.ynxweb4.com}" ""
      probe_get rpc "${YNX_RPC_STATUS_URL:-https://rpc.ynxweb4.com/status}" chain_id
      probe_evm
      probe_get rest "${YNX_REST_NODE_INFO_URL:-https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info}" chain_id
      probe_get grpc "${YNX_GRPC_URL:-https://grpc.ynxweb4.com}" grpc
      probe_get faucet "${YNX_FAUCET_HEALTH_URL:-https://faucet.ynxweb4.com/health}" chain_id
      probe_get indexer "${YNX_INDEXER_HEALTH_URL:-https://indexer.ynxweb4.com/health}" chain_id
      probe_get explorer "${YNX_EXPLORER_URL:-https://explorer.ynxweb4.com}" ""
      probe_get ai "${YNX_AI_HEALTH_URL:-https://ai.ynxweb4.com/health}" ai
      probe_get web4 "${YNX_WEB4_HEALTH_URL:-https://web4.ynxweb4.com/health}" web4
    } | jq -s '.'
  )"
  online="$(jq '[.[] | select(.status == "online")] | length' <<<"$results")"
  degraded="$(jq '[.[] | select(.status == "degraded")] | length' <<<"$results")"
  offline="$(jq '[.[] | select(.status == "offline")] | length' <<<"$results")"
  if [[ "$offline" -eq 0 && "$degraded" -eq 0 ]]; then
    state="online"
  elif [[ "$online" -gt 0 ]]; then
    state="degraded"
  else
    state="offline"
  fi
  summary="$(jq -n --arg ts "$ts" --arg state "$state" --argjson online "$online" --argjson degraded "$degraded" --argjson offline "$offline" --argjson services "$results" '{ts:$ts,state:$state,online:$online,degraded:$degraded,offline:$offline,services:$services}')"
  echo "$summary" >> "$SAMPLES_JSONL"
  echo "$summary" > "$LATEST_JSON"
  {
    echo "# YNX Public Uptime SLO Probe"
    echo
    echo "- Timestamp: \`$ts\`"
    echo "- State: \`$state\`"
    echo "- Online: \`$online\`"
    echo "- Degraded: \`$degraded\`"
    echo "- Offline: \`$offline\`"
    echo
    echo "| Service | Status | HTTP | Error | URL |"
    echo "|---|---:|---:|---|---|"
    jq -r '.[] | "| `\(.key)` | `\(.status)` | `\(.http_code)` | `\(.error // "")` | \(.url) |"' <<<"$results"
  } > "$REPORT_MD"
  if [[ "$state" == "online" ]]; then
    post_alert "$state" "Public uptime probe passed: online=${online} degraded=${degraded} offline=${offline}"
  else
    post_alert "$state" "Public uptime probe ${state}: online=${online} degraded=${degraded} offline=${offline}"
  fi
  [[ "$offline" -eq 0 ]]
}

if [[ "$ONCE" -eq 1 ]]; then
  run_once
  exit $?
fi

echo "Starting public uptime SLO probe. interval=${CHECK_INTERVAL_SEC}s output=${OUTPUT_BASE_DIR}"
while true; do
  run_once || true
  sleep "$CHECK_INTERVAL_SEC"
done
