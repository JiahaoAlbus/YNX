#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  testnet_watchdog.sh

Continuously checks public testnet health and emits alerts to stdout/webhook.

Environment:
  RPC_URL                    default: http://43.134.23.58:26657
  INDEXER_URL                default: http://43.134.23.58:8081
  CHECK_INTERVAL_SEC         default: 15
  HEIGHT_STALL_THRESHOLD_SEC default: 45
  REQUIRE_BONDED             default: 1
  MIN_SIGNED_RATIO           default: 0.66  (from /validators signed_count / total)
  ALERT_WEBHOOK_URL          optional; if set, POST JSON payload
  ALERT_COOLDOWN_SEC         default: 120
  HTTP_CONNECT_TIMEOUT_SEC   default: 5
  HTTP_MAX_TIME_SEC          default: 8

Example:
  ./scripts/testnet_watchdog.sh
  ALERT_WEBHOOK_URL="https://example.com/hook" ./scripts/testnet_watchdog.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

RPC_URL="${RPC_URL:-http://43.134.23.58:26657}"
INDEXER_URL="${INDEXER_URL:-http://43.134.23.58:8081}"
CHECK_INTERVAL_SEC="${CHECK_INTERVAL_SEC:-15}"
HEIGHT_STALL_THRESHOLD_SEC="${HEIGHT_STALL_THRESHOLD_SEC:-45}"
REQUIRE_BONDED="${REQUIRE_BONDED:-1}"
MIN_SIGNED_RATIO="${MIN_SIGNED_RATIO:-0.66}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
ALERT_COOLDOWN_SEC="${ALERT_COOLDOWN_SEC:-120}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
YNXD_BIN="${YNXD_BIN:-$CHAIN_DIR/ynxd}"
HTTP_CONNECT_TIMEOUT_SEC="${HTTP_CONNECT_TIMEOUT_SEC:-5}"
HTTP_MAX_TIME_SEC="${HTTP_MAX_TIME_SEC:-8}"

last_height=""
last_height_at="$(date +%s)"
last_alert_at=0

send_alert() {
  local level="$1"
  local message="$2"
  local now
  now="$(date +%s)"
  if (( now - last_alert_at < ALERT_COOLDOWN_SEC )); then
    return 0
  fi
  last_alert_at="$now"

  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "[$ts] [$level] $message"

  if [[ -n "$ALERT_WEBHOOK_URL" ]]; then
    curl -fsSL --connect-timeout "$HTTP_CONNECT_TIMEOUT_SEC" --max-time "$HTTP_MAX_TIME_SEC" -X POST "$ALERT_WEBHOOK_URL" \
      -H 'content-type: application/json' \
      --data "{\"ts\":\"$ts\",\"level\":\"$level\",\"message\":\"$message\"}" >/dev/null || true
  fi
}

echo "Starting YNX watchdog..."
echo "RPC_URL=$RPC_URL INDEXER_URL=$INDEXER_URL interval=${CHECK_INTERVAL_SEC}s"

while true; do
  now="$(date +%s)"
  status_json="$(curl -fsSL --connect-timeout "$HTTP_CONNECT_TIMEOUT_SEC" --max-time "$HTTP_MAX_TIME_SEC" "$RPC_URL/status" 2>/dev/null || true)"
  if [[ -z "$status_json" ]]; then
    send_alert "ERROR" "RPC unreachable: $RPC_URL"
    sleep "$CHECK_INTERVAL_SEC"
    continue
  fi

  height="$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height // empty')"
  catching_up="$(echo "$status_json" | jq -r '.result.sync_info.catching_up // false')"

  if [[ -z "$height" ]]; then
    send_alert "ERROR" "RPC status parse failed"
    sleep "$CHECK_INTERVAL_SEC"
    continue
  fi

  if [[ "$height" != "$last_height" ]]; then
    last_height="$height"
    last_height_at="$now"
  fi

  if (( now - last_height_at > HEIGHT_STALL_THRESHOLD_SEC )); then
    send_alert "CRITICAL" "Block production stalled for >${HEIGHT_STALL_THRESHOLD_SEC}s at height=$height"
  fi

  if [[ "$catching_up" == "true" ]]; then
    send_alert "WARN" "RPC catching_up=true"
  fi

  validators_json="$(curl -fsSL --connect-timeout "$HTTP_CONNECT_TIMEOUT_SEC" --max-time "$HTTP_MAX_TIME_SEC" "$RPC_URL/validators?per_page=100" 2>/dev/null || true)"
  [[ -z "$validators_json" ]] && validators_json='{}'
  total="$(echo "$validators_json" | jq -r '.result.validators | length // 0' 2>/dev/null || echo 0)"
  if [[ "$total" -eq 0 ]]; then
    send_alert "WARN" "No validators returned by RPC"
  fi

  signed_json="$(curl -fsSL --connect-timeout "$HTTP_CONNECT_TIMEOUT_SEC" --max-time "$HTTP_MAX_TIME_SEC" "$INDEXER_URL/validators" 2>/dev/null || true)"
  [[ -z "$signed_json" ]] && signed_json='{}'
  signed_count="$(echo "$signed_json" | jq -r '.signed_count // 0' 2>/dev/null || echo 0)"
  signed_total="$(echo "$signed_json" | jq -r '.total // 0' 2>/dev/null || echo 0)"
  if [[ "$signed_total" -gt 0 ]]; then
    ratio="$(awk -v a="$signed_count" -v b="$signed_total" 'BEGIN { if (b==0) print 0; else printf "%.4f", a/b }')"
    below="$(awk -v r="$ratio" -v m="$MIN_SIGNED_RATIO" 'BEGIN { if (r < m) print 1; else print 0 }')"
    if [[ "$below" -eq 1 ]]; then
      send_alert "WARN" "Signed ratio low: ${signed_count}/${signed_total} (${ratio})"
    fi
  fi

  if [[ "$REQUIRE_BONDED" == "1" ]]; then
    staking_json="$("$YNXD_BIN" query staking validators --node "$RPC_URL" -o json 2>/dev/null || true)"
    if [[ -n "$staking_json" ]]; then
      non_bonded="$(echo "$staking_json" | jq -r '[.validators[] | select(.status != "BOND_STATUS_BONDED" or .jailed == true)] | length')"
      if [[ "$non_bonded" -gt 0 ]]; then
        send_alert "WARN" "Non-bonded or jailed validators detected: $non_bonded"
      fi
    fi
  fi

  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) OK height=$height catching_up=$catching_up signed=${signed_count}/${signed_total}"
  sleep "$CHECK_INTERVAL_SEC"
done
