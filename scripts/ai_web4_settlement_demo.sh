#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID="${RUN_ID:-demo_$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output/ai_web4_demo/$RUN_ID}"

WEB4_PORT="${WEB4_PORT:-18091}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-18090}"
WEB4_INTERNAL_TOKEN="${WEB4_INTERNAL_TOKEN:-demo-internal-token}"
WEB4_URL="${WEB4_URL:-http://127.0.0.1:$WEB4_PORT}"
AI_URL="${AI_URL:-http://127.0.0.1:$AI_GATEWAY_PORT}"
YNX_DEMO_USE_EXISTING="${YNX_DEMO_USE_EXISTING:-0}"
YNX_DEMO_ONCHAIN="${YNX_DEMO_ONCHAIN:-0}"
YNX_DEMO_ONCHAIN_VAULT_WEI="${YNX_DEMO_ONCHAIN_VAULT_WEI:-1000000000000000}"
YNX_DEMO_ONCHAIN_REWARD_WEI="${YNX_DEMO_ONCHAIN_REWARD_WEI:-100000000000000}"
YNX_DEMO_ONCHAIN_MAX_PER_PAYMENT_WEI="${YNX_DEMO_ONCHAIN_MAX_PER_PAYMENT_WEI:-1000000000000000}"

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
AI_PID=""

cleanup() {
  if [[ -n "$AI_PID" ]]; then kill "$AI_PID" >/dev/null 2>&1 || true; fi
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

if [[ "$YNX_DEMO_USE_EXISTING" != "1" ]]; then
  WEB4_DATA_DIR="$OUTPUT_DIR/web4-data" \
  WEB4_PORT="$WEB4_PORT" \
  WEB4_ENFORCE_POLICY=1 \
  WEB4_INTERNAL_TOKEN="$WEB4_INTERNAL_TOKEN" \
  WEB4_CHAIN_ID="${WEB4_CHAIN_ID:-ynx_9102-1}" \
    node "$ROOT_DIR/infra/web4-hub/server.js" > "$OUTPUT_DIR/web4.log" 2>&1 &
  WEB4_PID="$!"

  wait_ready "$WEB4_URL" "Web4 Hub"

  AI_DATA_DIR="$OUTPUT_DIR/ai-data" \
  AI_GATEWAY_PORT="$AI_GATEWAY_PORT" \
  AI_ENFORCE_POLICY=1 \
  AI_WEB4_HUB_URL="$WEB4_URL" \
  AI_WEB4_INTERNAL_TOKEN="$WEB4_INTERNAL_TOKEN" \
  AI_CHAIN_ID="${AI_CHAIN_ID:-ynx_9102-1}" \
    node "$ROOT_DIR/infra/ai-gateway/server.js" > "$OUTPUT_DIR/ai.log" 2>&1 &
  AI_PID="$!"

  wait_ready "$AI_URL" "AI Gateway"
else
  wait_ready "$WEB4_URL" "Web4 Hub"
  wait_ready "$AI_URL" "AI Gateway"
fi

echo "YNX AI/Web4 settlement demo"
echo "Run id: $RUN_ID"
echo "Web4: $WEB4_URL"
echo "AI:   $AI_URL"
echo "Output: $OUTPUT_DIR"
echo "On-chain: $YNX_DEMO_ONCHAIN"
echo

OWNER="demo-owner-$RUN_ID"
POLICY_ID="policy_$RUN_ID"
SESSION_ID="session_$RUN_ID"
VAULT_ID="vault_$RUN_ID"
JOB_ID="job_$RUN_ID"

policy_body="$(jq -n \
  --arg owner "$OWNER" \
  --arg policy_id "$POLICY_ID" \
  '{
    owner: $owner,
    policy_id: $policy_id,
    name: "YNX official AI settlement demo",
    allowed_actions: [
      "ai.vault.create",
      "ai.job.create",
      "ai.job.commit",
      "ai.job.finalize",
      "ai.payment.charge"
    ],
    max_total_spend: 1000,
    max_daily_spend: 1000,
    default_session_max_ops: 10,
    default_session_max_spend: 1000,
    session_ttl_sec: 900
  }')"
policy_json="$(post_json "$WEB4_URL/web4/policies" "$policy_body")"
save_step "01_policy" "$policy_json"
owner_secret="$(printf '%s\n' "$policy_json" | jq -r '.owner_secret')"
policy_id="$(printf '%s\n' "$policy_json" | jq -r '.policy.policy_id')"
echo "1. Created Web4 policy: $policy_id"

session_body="$(jq -n \
  --arg session_id "$SESSION_ID" \
  '{
    session_id: $session_id,
    capabilities: [
      "ai.vault.create",
      "ai.job.create",
      "ai.job.commit",
      "ai.job.finalize",
      "ai.payment.charge"
    ],
    ttl_sec: 900,
    max_ops: 10,
    max_spend: 1000
  }')"
session_json="$(post_json "$WEB4_URL/web4/policies/$policy_id/sessions" "$session_body" -H "x-ynx-owner: $owner_secret")"
save_step "02_session" "$session_json"
session_token="$(printf '%s\n' "$session_json" | jq -r '.token')"
echo "2. Issued bounded session key: $(printf '%s\n' "$session_json" | jq -r '.session.session_id')"

vault_body="$(jq -n \
  --arg vault_id "$VAULT_ID" \
  --arg owner "$OWNER" \
  --arg policy_id "$policy_id" \
  --arg onchain "$YNX_DEMO_ONCHAIN" \
  --arg onchain_value_wei "$YNX_DEMO_ONCHAIN_VAULT_WEI" \
  --arg onchain_max_per_payment_wei "$YNX_DEMO_ONCHAIN_MAX_PER_PAYMENT_WEI" \
  '{
    vault_id: $vault_id,
    owner: $owner,
    policy_id: $policy_id,
    balance: 250,
    max_daily_spend: 100,
    max_per_payment: 50,
    metadata: { purpose: "demo AI reward budget" }
  } + if $onchain == "1" then {
    onchain: true,
    onchain_value_wei: $onchain_value_wei,
    onchain_max_per_payment_wei: $onchain_max_per_payment_wei
  } else {} end')"
vault_json="$(post_json "$AI_URL/ai/vaults" "$vault_body" -H "x-ynx-session: $session_token")"
save_step "03_vault" "$vault_json"
vault_id="$(printf '%s\n' "$vault_json" | jq -r '.vault.vault_id')"
echo "3. Created AI payment vault: $vault_id"

job_body="$(jq -n \
  --arg job_id "$JOB_ID" \
  --arg creator "$OWNER" \
  --arg policy_id "$policy_id" \
  --arg vault_id "$vault_id" \
  --arg onchain "$YNX_DEMO_ONCHAIN" \
  --arg reward_wei "$YNX_DEMO_ONCHAIN_REWARD_WEI" \
  '{
    job_id: $job_id,
    creator: $creator,
    policy_id: $policy_id,
    vault_id: $vault_id,
    reward: "42",
    stake: "5",
    input_uri: "ipfs://ynx-demo/summarize-market-brief",
    challenge_window_blocks: 12
  } + if $onchain == "1" then {
    onchain: true,
    reward_wei: $reward_wei,
    stake_wei: "0",
    challenge_window_blocks: 0
  } else {} end')"
job_json="$(post_json "$AI_URL/ai/jobs" "$job_body" -H "x-ynx-session: $session_token")"
save_step "04_job_created" "$job_json"
job_id="$(printf '%s\n' "$job_json" | jq -r '.job.job_id')"
echo "4. Published AI job: $job_id"

result_text="YNX demo result for $job_id"
result_hash="$(printf '%s' "$result_text" | shasum -a 256 | awk '{print $1}')"
commit_body="$(jq -n \
  --arg worker "agent-demo-worker" \
  --arg result_hash "$result_hash" \
  '{
    worker: $worker,
    result_hash: $result_hash,
    attestation_uri: "ipfs://ynx-demo/attestation"
  }')"
commit_json="$(post_json "$AI_URL/ai/jobs/$job_id/commit" "$commit_body" -H "x-ynx-session: $session_token")"
save_step "05_job_committed" "$commit_json"
echo "5. Worker committed result hash: $result_hash"

if [[ "$YNX_DEMO_ONCHAIN" == "1" ]]; then
  sleep "${YNX_DEMO_ONCHAIN_FINALIZE_DELAY_SEC:-3}"
fi

finalize_body="$(jq -n --arg policy_id "$policy_id" '{ policy_id: $policy_id, status: "finalized" }')"
finalize_json="$(post_json "$AI_URL/ai/jobs/$job_id/finalize" "$finalize_body" -H "x-ynx-session: $session_token")"
save_step "06_job_finalized" "$finalize_json"
payment_id="$(printf '%s\n' "$finalize_json" | jq -r '.job.payout_payment_id')"
echo "6. Finalized job and settled reward payment: $payment_id"

stats_json="$(curl -fsS "$AI_URL/ai/stats")"
save_step "07_ai_stats" "$stats_json"
overview_json="$(curl -fsS "$WEB4_URL/web4/overview")"
save_step "08_web4_overview" "$overview_json"

cat > "$OUTPUT_DIR/README.md" <<EOF
# YNX AI/Web4 Settlement Demo Evidence

- Run id: \`$RUN_ID\`
- Web4 URL: \`$WEB4_URL\`
- AI URL: \`$AI_URL\`
- Policy: \`$policy_id\`
- Vault: \`$vault_id\`
- Job: \`$job_id\`
- Reward payment: \`$payment_id\`
- On-chain: \`$YNX_DEMO_ONCHAIN\`

Flow:

1. Web4 owner creates a policy.
2. Owner issues a bounded session key.
3. AI Gateway creates a vault under that policy.
4. Creator publishes an AI job.
5. Worker commits a result hash.
6. Job finalizes and reward is charged from the vault.
EOF

echo
echo "Demo completed."
echo "Evidence files written to: $OUTPUT_DIR"
