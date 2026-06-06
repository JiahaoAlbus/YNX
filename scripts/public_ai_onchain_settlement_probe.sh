#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/public_ai_onchain_settlement_probe.sh [--job-id JOB_ID] [--output-dir DIR]

Read-only public AI/Web4 on-chain settlement probe.

Environment:
  YNX_AI_URL                 default: https://ai.ynxweb4.com
  YNX_WEB4_URL               default: https://web4.ynxweb4.com
  YNX_EXPECTED_CHAIN_ID      default: ynx_9102-1
  YNX_MIN_AI_FINALIZED_JOBS  default: 5
  YNX_MIN_AI_PAYMENTS        default: 7
  YNX_FETCH_TIMEOUT_SEC      default: 15
  YNX_FETCH_RETRIES          default: 3
EOF
}

JOB_ID="${YNX_AI_PROBE_JOB_ID:-job_public_onchain_20260606T053758Z}"
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-id)
      JOB_ID="${2:-}"
      shift 2
      ;;
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
  OUTPUT_DIR="${REPO_ROOT}/output/public_ai_onchain_probe_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}/responses"

AI_URL="${YNX_AI_URL:-https://ai.ynxweb4.com}"
WEB4_URL="${YNX_WEB4_URL:-https://web4.ynxweb4.com}"
EXPECTED_CHAIN_ID="${YNX_EXPECTED_CHAIN_ID:-ynx_9102-1}"
MIN_AI_FINALIZED_JOBS="${YNX_MIN_AI_FINALIZED_JOBS:-5}"
MIN_AI_PAYMENTS="${YNX_MIN_AI_PAYMENTS:-7}"
FETCH_TIMEOUT_SEC="${YNX_FETCH_TIMEOUT_SEC:-15}"
FETCH_RETRIES="${YNX_FETCH_RETRIES:-3}"

pass=0
fail=0
rows=()

record() {
  local status="$1"
  local name="$2"
  local detail="$3"
  rows+=("| ${name} | ${status} | ${detail//|/\\|} |")
  case "$status" in
    PASS) pass=$((pass + 1)) ;;
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

fetch ai_health "${AI_URL}/health"
fetch ai_ready "${AI_URL}/ready"
fetch ai_stats "${AI_URL}/ai/stats"
fetch ai_job "${AI_URL}/ai/jobs/${JOB_ID}"
fetch web4_ready "${WEB4_URL}/ready"

ai_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/ai_health.json")"
ai_chain="$(jq -r '.chain_id // ""' "${OUTPUT_DIR}/responses/ai_health.json")"
ai_onchain_ready="$(jq -r '.onchain.ready // false' "${OUTPUT_DIR}/responses/ai_health.json")"
ai_last_tx="$(jq -r '.onchain.last_tx_hash // ""' "${OUTPUT_DIR}/responses/ai_health.json")"
stats_jobs="$(jq -r '.total_jobs // 0' "${OUTPUT_DIR}/responses/ai_stats.json")"
stats_payments="$(jq -r '.total_payments // 0' "${OUTPUT_DIR}/responses/ai_stats.json")"
stats_finalized="$(jq -r '.by_status.finalized // 0' "${OUTPUT_DIR}/responses/ai_stats.json")"
job_status="$(jq -r '.job.status // ""' "${OUTPUT_DIR}/responses/ai_job.json")"
job_payment="$(jq -r '.job.payout_payment_id // ""' "${OUTPUT_DIR}/responses/ai_job.json")"
job_contract="$(jq -r '.job.onchain.contract // ""' "${OUTPUT_DIR}/responses/ai_job.json")"
job_finalize_tx="$(jq -r '.job.onchain.finalize_tx_hash // .job.onchain.tx_hash // ""' "${OUTPUT_DIR}/responses/ai_job.json")"
web4_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/web4_ready.json")"

[[ "$ai_ok" == "true" ]] && record PASS "ai_health" "ok=true" || record FAIL "ai_health" "ok=${ai_ok}"
[[ "$ai_chain" == "$EXPECTED_CHAIN_ID" ]] && record PASS "ai_chain_id" "$ai_chain" || record FAIL "ai_chain_id" "got=${ai_chain}, expected=${EXPECTED_CHAIN_ID}"
[[ "$ai_onchain_ready" == "true" ]] && record PASS "ai_onchain_ready" "true" || record FAIL "ai_onchain_ready" "$ai_onchain_ready"
[[ "$ai_last_tx" =~ ^0x[0-9a-fA-F]{64}$ ]] && record PASS "ai_last_tx_hash" "$ai_last_tx" || record FAIL "ai_last_tx_hash" "$ai_last_tx"
[[ "$stats_finalized" -ge "$MIN_AI_FINALIZED_JOBS" ]] && record PASS "ai_finalized_jobs" "finalized=${stats_finalized}, min=${MIN_AI_FINALIZED_JOBS}" || record FAIL "ai_finalized_jobs" "finalized=${stats_finalized}, min=${MIN_AI_FINALIZED_JOBS}"
[[ "$stats_payments" -ge "$MIN_AI_PAYMENTS" ]] && record PASS "ai_payments" "payments=${stats_payments}, min=${MIN_AI_PAYMENTS}" || record FAIL "ai_payments" "payments=${stats_payments}, min=${MIN_AI_PAYMENTS}"
[[ "$job_status" == "finalized" ]] && record PASS "probe_job_finalized" "$JOB_ID" || record FAIL "probe_job_finalized" "status=${job_status}"
[[ "$job_payment" == pay_* ]] && record PASS "probe_job_payment" "$job_payment" || record FAIL "probe_job_payment" "$job_payment"
[[ "$job_contract" =~ ^0x[0-9a-fA-F]{40}$ ]] && record PASS "probe_job_contract" "$job_contract" || record FAIL "probe_job_contract" "$job_contract"
[[ "$job_finalize_tx" =~ ^0x[0-9a-fA-F]{64}$ ]] && record PASS "probe_job_finalize_tx" "$job_finalize_tx" || record FAIL "probe_job_finalize_tx" "$job_finalize_tx"
[[ "$web4_ok" == "true" ]] && record PASS "web4_ready" "ok=true" || record FAIL "web4_ready" "ok=${web4_ok}"

report="${OUTPUT_DIR}/PUBLIC_AI_ONCHAIN_SETTLEMENT.md"
{
  echo "# YNX Public AI On-chain Settlement Probe"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- AI URL: ${AI_URL}"
  echo "- Web4 URL: ${WEB4_URL}"
  echo "- Probe job: ${JOB_ID}"
  echo "- Total jobs: ${stats_jobs}"
  echo "- Finalized jobs: ${stats_finalized}"
  echo "- Total payments: ${stats_payments}"
  echo "- Passed: ${pass}"
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

echo "AI on-chain settlement report: $report"
echo "PASS=${pass} FAIL=${fail}"

if (( fail > 0 )); then
  exit 1
fi
