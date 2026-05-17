#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/testnet_launch_grade_monitor.sh [--once]

Continuously runs the public launch-grade testnet readiness gate and emits
state-change alerts. This is read-only.

Environment:
  CHECK_INTERVAL_SEC       default: 300
  ALERT_WEBHOOK_URL        optional; receives JSON POSTs
  ALERT_COOLDOWN_SEC       default: 900
  OUTPUT_BASE_DIR          default: output/launch_grade_monitor
  YNX_*                    forwarded to public_testnet_extreme_readiness.sh

Examples:
  scripts/testnet_launch_grade_monitor.sh --once
  ALERT_WEBHOOK_URL=https://example/hook scripts/testnet_launch_grade_monitor.sh
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

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
READINESS_SCRIPT="${REPO_ROOT}/scripts/public_testnet_extreme_readiness.sh"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-300}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-900}"
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-${REPO_ROOT}/output/launch_grade_monitor}"

mkdir -p "$OUTPUT_BASE_DIR"

last_state=""
last_alert_at=0

post_alert() {
  local level="$1"
  local state="$2"
  local message="$3"
  local report="$4"
  local now
  now="$(date +%s)"
  if [[ "$state" == "$last_state" && $((now - last_alert_at)) -lt "$ALERT_COOLDOWN_SEC" ]]; then
    return 0
  fi
  last_state="$state"
  last_alert_at="$now"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] [$level] $message report=$report"

  if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
    jq -n \
      --arg ts "$ts" \
      --arg level "$level" \
      --arg state "$state" \
      --arg message "$message" \
      --arg report "$report" \
      '{ts:$ts, level:$level, state:$state, message:$message, report:$report}' \
      | curl -fsS --max-time 10 -H "content-type: application/json" --data @- "$ALERT_WEBHOOK_URL" >/dev/null || true
  fi
}

run_once() {
  local stamp out report summary fail warn pass status
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  out="${OUTPUT_BASE_DIR}/${stamp}"
  status=0
  "$READINESS_SCRIPT" --output-dir "$out" > "${out}.log" 2>&1 || status=$?
  report="${out}/EXTREME_READINESS.md"
  summary="$(tail -n 1 "${out}.log" 2>/dev/null || true)"
  pass="$(echo "$summary" | sed -nE 's/.*PASS=([0-9]+).*/\1/p')"
  warn="$(echo "$summary" | sed -nE 's/.*WARN=([0-9]+).*/\1/p')"
  fail="$(echo "$summary" | sed -nE 's/.*FAIL=([0-9]+).*/\1/p')"
  pass="${pass:-0}"
  warn="${warn:-0}"
  fail="${fail:-1}"

  if [[ "$status" -eq 0 && "$fail" -eq 0 ]]; then
    post_alert "INFO" "pass" "Launch-grade testnet gate passed: PASS=${pass} WARN=${warn} FAIL=${fail}" "$report"
    return 0
  fi

  post_alert "CRITICAL" "fail" "Launch-grade testnet gate failed: PASS=${pass} WARN=${warn} FAIL=${fail}" "$report"
  return 1
}

if [[ "$ONCE" -eq 1 ]]; then
  run_once
  exit $?
fi

echo "Starting launch-grade testnet monitor. interval=${CHECK_INTERVAL_SEC}s output=${OUTPUT_BASE_DIR}"
while true; do
  run_once || true
  sleep "$CHECK_INTERVAL_SEC"
done
