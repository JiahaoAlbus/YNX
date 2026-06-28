#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID="${RUN_ID:-card_demo_$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output/ynx_card_demo/$RUN_ID}"

WEB4_PORT="${WEB4_PORT:-18191}"
WEB4_URL="${WEB4_URL:-http://127.0.0.1:$WEB4_PORT}"
YNX_CARD_DEMO_USE_EXISTING="${YNX_CARD_DEMO_USE_EXISTING:-0}"
WEB4_INTERNAL_TOKEN="${WEB4_INTERNAL_TOKEN:-demo-internal-token}"

mkdir -p "$OUTPUT_DIR"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need curl
need jq
need node

WEB4_PID=""

cleanup() {
  if [[ -n "$WEB4_PID" ]]; then kill "$WEB4_PID" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

wait_ready() {
  local url="$1"
  local name="$2"
  for _ in $(seq 1 40); do
    if curl -fsS "$url/ready" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out waiting for $name at $url/ready" >&2
  exit 1
}

post_json() {
  local url="$1"
  local body="$2"
  shift 2
  curl -fsS "$url" \
    -H "content-type: application/json" \
    "$@" \
    --data "$body"
}

save_step() {
  local name="$1"
  local body="$2"
  printf '%s\n' "$body" | jq . > "$OUTPUT_DIR/${name}.json"
}

if [[ "$YNX_CARD_DEMO_USE_EXISTING" != "1" ]]; then
  WEB4_DATA_DIR="$OUTPUT_DIR/web4-data" \
  WEB4_PORT="$WEB4_PORT" \
  WEB4_ENFORCE_POLICY=1 \
  WEB4_INTERNAL_TOKEN="$WEB4_INTERNAL_TOKEN" \
  WEB4_REQUIRE_BOOTSTRAP_FOR_POLICY_CREATE=1 \
  WEB4_CHAIN_ID="${WEB4_CHAIN_ID:-ynx_9102-1}" \
    node "$ROOT_DIR/infra/web4-hub/server.js" > "$OUTPUT_DIR/web4.log" 2>&1 &
  WEB4_PID="$!"
fi

wait_ready "$WEB4_URL" "Web4 Hub"

echo "YNX Card Mock demo"
echo "Run id: $RUN_ID"
echo "Web4:   $WEB4_URL"
echo "Output: $OUTPUT_DIR"
echo

BOOTSTRAP_ID="bootstrap_$RUN_ID"
POLICY_ID="policy_$RUN_ID"
OWNER_SESSION_ID="owner_session_$RUN_ID"
CARD_SESSION_ID="card_session_$RUN_ID"
AGENT_ID="agent_$RUN_ID"
CARD_ID="card_$RUN_ID"

wallet_json="$(
  node <<'EOF'
const { ethers } = require("ethers");
const wallet = ethers.Wallet.createRandom();
console.log(JSON.stringify({ address: wallet.address, privateKey: wallet.privateKey }));
EOF
)"
save_step "00_wallet" "$wallet_json"
wallet_address="$(printf '%s\n' "$wallet_json" | jq -r '.address')"
wallet_private_key="$(printf '%s\n' "$wallet_json" | jq -r '.privateKey')"
echo "0. Created demo wallet: $wallet_address"

bootstrap_body="$(jq -n --arg bootstrap_id "$BOOTSTRAP_ID" --arg wallet_address "$wallet_address" '{
  bootstrap_id: $bootstrap_id,
  wallet_address: $wallet_address
}')"
bootstrap_json="$(post_json "$WEB4_URL/web4/wallet/bootstrap" "$bootstrap_body")"
save_step "01_wallet_bootstrap" "$bootstrap_json"
siwe_message="$(printf '%s\n' "$bootstrap_json" | jq -r '.siwe_message')"
echo "1. Requested wallet bootstrap: $(printf '%s\n' "$bootstrap_json" | jq -r '.bootstrap.bootstrap_id')"

signature_json="$(
  WALLET_PRIVATE_KEY="$wallet_private_key" \
  SIWE_MESSAGE="$siwe_message" \
  node <<'EOF'
const { ethers } = require("ethers");
const wallet = new ethers.Wallet(process.env.WALLET_PRIVATE_KEY);
(async () => {
  const signature = await wallet.signMessage(process.env.SIWE_MESSAGE);
  console.log(JSON.stringify({ signature }));
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
EOF
)"
signature="$(printf '%s\n' "$signature_json" | jq -r '.signature')"

verify_body="$(jq -n --arg bootstrap_id "$BOOTSTRAP_ID" --arg signature "$signature" '{
  bootstrap_id: $bootstrap_id,
  signature: $signature
}')"
verify_json="$(post_json "$WEB4_URL/web4/wallet/verify" "$verify_body")"
save_step "02_wallet_verified" "$verify_json"
api_key="$(printf '%s\n' "$verify_json" | jq -r '.api_key')"
echo "2. Verified wallet bootstrap and received bootstrap API key"

policy_body="$(jq -n \
  --arg policy_id "$POLICY_ID" \
  '{
    policy_id: $policy_id,
    name: "YNX Card Mock official demo",
    allowed_actions: [
      "agent.create",
      "card.authorize",
      "audit.read"
    ],
    max_total_spend: 500,
    max_daily_spend: 500,
    default_session_max_ops: 20,
    default_session_max_spend: 200
  }')"
policy_json="$(post_json "$WEB4_URL/web4/policies" "$policy_body" -H "x-ynx-api-key: $api_key")"
save_step "03_policy" "$policy_json"
owner_secret="$(printf '%s\n' "$policy_json" | jq -r '.owner_secret')"
policy_id="$(printf '%s\n' "$policy_json" | jq -r '.policy.policy_id')"
echo "3. Created wallet-backed policy: $policy_id"

owner_session_body="$(jq -n --arg session_id "$OWNER_SESSION_ID" '{
  session_id: $session_id,
  capabilities: ["agent.create", "card.authorize", "audit.read"],
  ttl_sec: 900,
  max_ops: 20,
  max_spend: 200
}')"
owner_session_json="$(post_json "$WEB4_URL/web4/policies/$policy_id/sessions" "$owner_session_body" -H "x-ynx-owner: $owner_secret")"
save_step "04_owner_session" "$owner_session_json"
owner_session_token="$(printf '%s\n' "$owner_session_json" | jq -r '.token')"
echo "4. Issued owner-scoped working session"

agent_body="$(jq -n --arg agent_id "$AGENT_ID" --arg policy_id "$policy_id" --arg owner "$wallet_address" '{
  agent_id: $agent_id,
  policy_id: $policy_id,
  owner: $owner,
  name: "YNX Card spending agent",
  model: "demo-agent",
  capabilities: ["spend", "review"]
}')"
agent_json="$(post_json "$WEB4_URL/web4/agents" "$agent_body" -H "x-ynx-session: $owner_session_token")"
save_step "05_agent" "$agent_json"
agent_id="$(printf '%s\n' "$agent_json" | jq -r '.agent.agent_id')"
echo "5. Created bounded agent: $agent_id"

card_body="$(jq -n \
  --arg card_id "$CARD_ID" \
  --arg policy_id "$policy_id" \
  --arg agent_id "$agent_id" \
  '{
    card_id: $card_id,
    policy_id: $policy_id,
    label: "YNX Card Mock demo",
    asset_ref: "YUSD.test",
    vault_id: "mock_vault_demo",
    require_agent: true,
    allowed_agents: [$agent_id],
    allowed_merchants: ["OpenAI"],
    allowed_mccs: ["5734"],
    allowed_countries: ["US"],
    max_per_txn: 50,
    max_daily_spend: 100,
    max_total_spend: 200
  }')"
card_json="$(post_json "$WEB4_URL/web4/cards" "$card_body" -H "x-ynx-owner: $owner_secret")"
save_step "06_card" "$card_json"
card_id="$(printf '%s\n' "$card_json" | jq -r '.card.card_id')"
echo "6. Created YNX Card Mock: $card_id"

card_session_body="$(jq -n --arg session_id "$CARD_SESSION_ID" '{
  session_id: $session_id,
  capabilities: ["card.authorize", "audit.read"],
  ttl_sec: 900,
  max_ops: 10,
  max_spend: 120
}')"
card_session_json="$(post_json "$WEB4_URL/web4/policies/$policy_id/sessions" "$card_session_body" -H "x-ynx-owner: $owner_secret")"
save_step "07_card_session" "$card_session_json"
card_session_token="$(printf '%s\n' "$card_session_json" | jq -r '.token')"
echo "7. Issued card-authorization session"

approve_body="$(jq -n \
  --arg policy_id "$policy_id" \
  --arg agent_id "$agent_id" \
  '{
    policy_id: $policy_id,
    agent_id: $agent_id,
    amount: 20,
    currency: "USD",
    merchant: "OpenAI",
    mcc: "5734",
    country: "US"
  }')"
approve_json="$(post_json "$WEB4_URL/web4/cards/$card_id/authorize" "$approve_body" -H "x-ynx-session: $card_session_token")"
save_step "08_authorize_approved" "$approve_json"
authorization_id="$(printf '%s\n' "$approve_json" | jq -r '.authorization.authorization_id')"
echo "8. Approved bounded spend attempt"

settle_body="$(jq -n \
  --arg authorization_id "$authorization_id" \
  '{
    authorization_id: $authorization_id,
    amount: 12,
    external_ref: "demo-settle-1",
    note: "mock settlement leg"
  }')"
settle_json="$(post_json "$WEB4_URL/web4/cards/$card_id/settle" "$settle_body" -H "x-ynx-owner: $owner_secret")"
save_step "09_settle" "$settle_json"
echo "9. Recorded mock settlement"

reverse_body="$(jq -n \
  --arg authorization_id "$authorization_id" \
  '{
    authorization_id: $authorization_id,
    amount: 8,
    external_ref: "demo-reverse-1",
    note: "mock auth reversal leg"
  }')"
reverse_json="$(post_json "$WEB4_URL/web4/cards/$card_id/reverse" "$reverse_body" -H "x-ynx-owner: $owner_secret")"
save_step "10_reverse" "$reverse_json"
echo "10. Recorded mock authorization reversal"

refund_body="$(jq -n \
  --arg authorization_id "$authorization_id" \
  '{
    authorization_id: $authorization_id,
    amount: 4,
    external_ref: "demo-refund-1",
    note: "mock post-settlement refund leg"
  }')"
refund_json="$(post_json "$WEB4_URL/web4/cards/$card_id/refund" "$refund_body" -H "x-ynx-owner: $owner_secret")"
save_step "11_refund" "$refund_json"
echo "11. Recorded mock refund"

decline_body="$(jq -n \
  --arg policy_id "$policy_id" \
  --arg agent_id "$agent_id" \
  '{
    policy_id: $policy_id,
    agent_id: $agent_id,
    amount: 80,
    currency: "USD",
    merchant: "UnknownVendor",
    mcc: "5999",
    country: "US"
  }')"
decline_response_file="$OUTPUT_DIR/12_authorize_declined.raw"
decline_status="$(
  curl -sS -o "$decline_response_file" -w "%{http_code}" \
    "$WEB4_URL/web4/cards/$card_id/authorize" \
    -H "content-type: application/json" \
    -H "x-ynx-session: $card_session_token" \
    --data "$decline_body"
)"
jq . "$decline_response_file" > "$OUTPUT_DIR/12_authorize_declined.json"
echo "12. Declined out-of-policy spend attempt (HTTP $decline_status)"

card_detail_json="$(curl -fsS "$WEB4_URL/web4/cards/$card_id")"
save_step "13_card_detail" "$card_detail_json"

audit_json="$(curl -fsS "$WEB4_URL/web4/audit?policy_id=$policy_id" -H "x-ynx-session: $card_session_token")"
save_step "14_audit" "$audit_json"

cat > "$OUTPUT_DIR/README.md" <<EOF
# YNX Card Mock Demo Evidence

- Run id: \`$RUN_ID\`
- Wallet address: \`$wallet_address\`
- Policy: \`$policy_id\`
- Agent: \`$agent_id\`
- Card: \`$card_id\`

## What this run proves

- wallet bootstrap challenge and signature verification
- bootstrap-backed policy creation
- owner-issued session delegation
- bounded agent creation under policy
- YNX Card Mock creation tied to the same policy
- approved mock spend inside rules
- mock settlement entry against approved spend
- mock authorization reversal against remaining hold
- mock refund against settled amount
- declined mock spend outside rules
- audit visibility for authorization and reconciliation outcomes

## Open these files first

- \`03_policy.json\`
- \`05_agent.json\`
- \`06_card.json\`
- \`08_authorize_approved.json\`
- \`09_settle.json\`
- \`10_reverse.json\`
- \`11_refund.json\`
- \`12_authorize_declined.json\`
- \`13_card_detail.json\`
- \`14_audit.json\`
EOF

echo
echo "Demo complete."
echo "Evidence written to: $OUTPUT_DIR"
