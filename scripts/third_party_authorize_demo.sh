#!/usr/bin/env bash
set -euo pipefail

WEB4_URL="${WEB4_URL:-https://web4.ynxweb4.com}"
SERVICE_URL="${SERVICE_URL:-https://httpbin.org/get}"
ACTION="${ACTION:-service.invoke}"
OWNER="${OWNER:-demo-owner-$(date +%s)}"
SPEND_LIMIT="${SPEND_LIMIT:-100}"
AMOUNT="${AMOUNT:-1}"
DO_CALL="${DO_CALL:-1}"
WEB4_INTERNAL_TOKEN="${WEB4_INTERNAL_TOKEN:-}"

for arg in "$@"; do
  case "$arg" in
    --web4-url=*) WEB4_URL="${arg#*=}" ;;
    --service-url=*) SERVICE_URL="${arg#*=}" ;;
    --action=*) ACTION="${arg#*=}" ;;
    --owner=*) OWNER="${arg#*=}" ;;
    --spend-limit=*) SPEND_LIMIT="${arg#*=}" ;;
    --amount=*) AMOUNT="${arg#*=}" ;;
    --do-call=*) DO_CALL="${arg#*=}" ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

SERVICE_HOST="$(echo "$SERVICE_URL" | sed -E 's#^[a-zA-Z]+://##' | cut -d/ -f1 | cut -d: -f1)"
if [[ -z "$SERVICE_HOST" ]]; then
  echo "Unable to parse service host from SERVICE_URL=$SERVICE_URL" >&2
  exit 1
fi

echo "==> Creating policy on $WEB4_URL for host $SERVICE_HOST"
POLICY_RAW="$(curl -sS -X POST "$WEB4_URL/web4/policies" \
  -H "content-type: application/json" \
  -d "{
    \"owner\": \"$OWNER\",
    \"name\": \"third-party-demo-$SERVICE_HOST\",
    \"allowed_actions\": [\"$ACTION\"],
    \"allowed_service_hosts\": [\"$SERVICE_HOST\"],
    \"max_total_spend\": $SPEND_LIMIT,
    \"max_daily_spend\": $SPEND_LIMIT,
    \"session_ttl_sec\": 900
  }")"

POLICY_ID="$(echo "$POLICY_RAW" | jq -r '.policy.policy_id // empty')"
OWNER_SECRET="$(echo "$POLICY_RAW" | jq -r '.owner_secret // empty')"
if [[ -z "$POLICY_ID" || -z "$OWNER_SECRET" ]]; then
  echo "Policy creation failed:" >&2
  echo "$POLICY_RAW" >&2
  exit 1
fi

echo "==> Policy created: $POLICY_ID"
SESSION_RAW="$(curl -sS -X POST "$WEB4_URL/web4/policies/$POLICY_ID/sessions" \
  -H "content-type: application/json" \
  -H "x-ynx-owner: $OWNER_SECRET" \
  -d "{
    \"capabilities\": [\"$ACTION\"],
    \"max_ops\": 5,
    \"max_spend\": $SPEND_LIMIT
  }")"

SESSION_TOKEN="$(echo "$SESSION_RAW" | jq -r '.token // empty')"
SESSION_ID="$(echo "$SESSION_RAW" | jq -r '.session.session_id // empty')"
if [[ -z "$SESSION_TOKEN" || -z "$SESSION_ID" ]]; then
  echo "Session issuance failed:" >&2
  echo "$SESSION_RAW" >&2
  exit 1
fi

echo "==> Session issued: $SESSION_ID"
echo "==> Authorizing third-party action ($ACTION) against $SERVICE_HOST"
AUTH_RAW="$(curl -sS -X POST "$WEB4_URL/web4/authorize" \
  -H "content-type: application/json" \
  -H "x-ynx-session: $SESSION_TOKEN" \
  -d "{
    \"policy_id\": \"$POLICY_ID\",
    \"action\": \"$ACTION\",
    \"amount\": $AMOUNT,
    \"resource_host\": \"$SERVICE_HOST\",
    \"resource\": \"$SERVICE_URL\"
  }")"

AUTH_OK="$(echo "$AUTH_RAW" | jq -r '.ok // false')"
if [[ "$AUTH_OK" != "true" ]]; then
  ERROR_CODE="$(echo "$AUTH_RAW" | jq -r '.error // empty')"
  if [[ "$ERROR_CODE" == "not_found" ]]; then
    echo "==> /web4/authorize unavailable, trying /web4/internal/authorize fallback"
    EXTRA_HEADER=()
    if [[ -n "$WEB4_INTERNAL_TOKEN" ]]; then
      EXTRA_HEADER=(-H "x-ynx-internal-token: $WEB4_INTERNAL_TOKEN")
    fi
    AUTH_RAW="$(curl -sS -X POST "$WEB4_URL/web4/internal/authorize" \
      -H "content-type: application/json" \
      -H "x-ynx-session: $SESSION_TOKEN" \
      "${EXTRA_HEADER[@]}" \
      -d "{
        \"policy_id\": \"$POLICY_ID\",
        \"action\": \"$ACTION\",
        \"amount\": $AMOUNT,
        \"resource_host\": \"$SERVICE_HOST\",
        \"resource\": \"$SERVICE_URL\"
      }")"
    AUTH_OK="$(echo "$AUTH_RAW" | jq -r '.ok // false')"
  fi
fi

if [[ "$AUTH_OK" != "true" ]]; then
  echo "Authorization failed:" >&2
  echo "$AUTH_RAW" >&2
  exit 1
fi

echo "==> Authorization success:"
echo "$AUTH_RAW" | jq .

if [[ "$DO_CALL" == "1" ]]; then
  echo "==> Calling third-party service: $SERVICE_URL"
  curl -sS "$SERVICE_URL" | head -c 800
  echo
fi

echo "==> Done. Try another API URL by setting:"
echo "    SERVICE_URL='https://api.github.com' ./scripts/third_party_authorize_demo.sh"
