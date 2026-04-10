#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_public_testnet_smoke.sh

Run write-path smoke tests for YNX v2 Web4 public testnet APIs.

Environment:
  YNX_PUBLIC_HOST         default: 127.0.0.1
  YNX_AI_GATEWAY_PORT     default: 38090
  YNX_WEB4_PORT           default: 38091
  YNX_EXPECT_CHAIN_ID     default: ynx_9102-1
  YNX_EXPECT_TRACK        default: v2-web4
  YNX_SMOKE_ENFORCE_POLICY default: 1
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

for bin in curl jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

HOST="${YNX_PUBLIC_HOST:-127.0.0.1}"
AI_PORT="${YNX_AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${YNX_WEB4_PORT:-38091}"
EXPECT_CHAIN_ID="${YNX_EXPECT_CHAIN_ID:-ynx_9102-1}"
EXPECT_TRACK="${YNX_EXPECT_TRACK:-v2-web4}"
SMOKE_ENFORCE_POLICY="${YNX_SMOKE_ENFORCE_POLICY:-1}"

AI_BASE="http://${HOST}:${AI_PORT}"
WEB4_BASE="http://${HOST}:${WEB4_PORT}"
STAMP="$(date +%s)"
RAND="$(printf '%04x' "$((RANDOM % 65536))")"
SUFFIX="${STAMP}_${RAND}"

curl_json() {
  local method="$1"
  local url="$2"
  local data="${3:-}"
  local extra_header="${4:-}"
  if [[ "$method" == "GET" ]]; then
    if [[ -n "$extra_header" ]]; then
      curl -fsS --max-time 10 -H "$extra_header" "$url"
    else
      curl -fsS --max-time 10 "$url"
    fi
    return 0
  fi
  if [[ -n "$extra_header" ]]; then
    curl -fsS --max-time 10 -H "content-type: application/json" -H "$extra_header" -X "$method" --data "$data" "$url"
  else
    curl -fsS --max-time 10 -H "content-type: application/json" -X "$method" --data "$data" "$url"
  fi
}

echo "== YNX v2 Web4 Smoke =="
echo "Host: $HOST"

ai_health="$(curl_json GET "${AI_BASE}/health")"
ai_chain_id="$(echo "$ai_health" | jq -r '.chain_id')"
[[ "$ai_chain_id" == "$EXPECT_CHAIN_ID" ]] || { echo "AI chain mismatch: $ai_chain_id"; exit 1; }

web4_health="$(curl_json GET "${WEB4_BASE}/health")"
web4_chain_id="$(echo "$web4_health" | jq -r '.chain_id')"
web4_track="$(echo "$web4_health" | jq -r '.track')"
[[ "$web4_chain_id" == "$EXPECT_CHAIN_ID" ]] || { echo "Web4 chain mismatch: $web4_chain_id"; exit 1; }
[[ "$web4_track" == "$EXPECT_TRACK" ]] || { echo "Web4 track mismatch: $web4_track"; exit 1; }

policy_payload="$(cat <<EOF
{"owner":"owner_${SUFFIX}","name":"policy-${SUFFIX}","max_total_spend":100000,"max_daily_spend":50000,"max_children":3,"replicate_cooldown_sec":1}
EOF
)"
policy_resp="$(curl_json POST "${WEB4_BASE}/web4/policies" "$policy_payload")"
policy_id="$(echo "$policy_resp" | jq -r '.policy.policy_id')"
owner_secret="$(echo "$policy_resp" | jq -r '.owner_secret')"
[[ -n "$policy_id" && "$policy_id" != "null" ]] || { echo "Policy create failed"; exit 1; }
[[ -n "$owner_secret" && "$owner_secret" != "null" ]] || { echo "Policy owner secret missing"; exit 1; }

session_payload='{"capabilities":["identity.create","agent.create","agent.modify","agent.replicate","intent.create","intent.claim","intent.challenge","intent.finalize","ai.vault.create","ai.vault.deposit","ai.vault.admin","ai.job.create","ai.job.commit","ai.job.challenge","ai.job.finalize","ai.payment.charge"],"ttl_sec":900,"max_ops":200,"max_spend":50000}'
session_resp="$(curl_json POST "${WEB4_BASE}/web4/policies/${policy_id}/sessions" "$session_payload" "x-ynx-owner: ${owner_secret}")"
session_token="$(echo "$session_resp" | jq -r '.token')"
[[ -n "$session_token" && "$session_token" != "null" ]] || { echo "Session issue failed"; exit 1; }

wallet_bootstrap_resp="$(curl_json POST "${WEB4_BASE}/web4/wallet/bootstrap" "{\"owner\":\"owner_${SUFFIX}\"}")"
bootstrap_id="$(echo "$wallet_bootstrap_resp" | jq -r '.bootstrap.bootstrap_id')"
[[ -n "$bootstrap_id" && "$bootstrap_id" != "null" ]] || { echo "Wallet bootstrap failed"; exit 1; }
wallet_verify_resp="$(curl_json POST "${WEB4_BASE}/web4/wallet/verify" "{\"bootstrap_id\":\"${bootstrap_id}\",\"signature\":\"sig_${SUFFIX}\"}")"
api_key="$(echo "$wallet_verify_resp" | jq -r '.api_key')"
[[ -n "$api_key" && "$api_key" != "null" ]] || { echo "Wallet verify failed"; exit 1; }

if [[ "$SMOKE_ENFORCE_POLICY" == "1" ]]; then
  should_fail="$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "content-type: application/json" --data "{\"address\":\"ynx1guard${RAND}${RAND}\"}" "${WEB4_BASE}/web4/identities")"
  [[ "$should_fail" == "400" ]] || { echo "Policy enforcement expected HTTP 400, got $should_fail"; exit 1; }
fi

ai_job_payload="$(cat <<EOF
{"creator":"ynx_creator_${SUFFIX}","worker":"","reward":"1000","stake":"100","input_uri":"ipfs://input/${SUFFIX}"}
EOF
)"
vault_resp="$(curl_json POST "${AI_BASE}/ai/vaults" "{\"owner\":\"owner_${SUFFIX}\",\"balance\":10000,\"max_daily_spend\":9000,\"max_per_payment\":5000,\"policy_id\":\"${policy_id}\"}" "x-ynx-session: ${session_token}")"
vault_id="$(echo "$vault_resp" | jq -r '.vault.vault_id')"
[[ -n "$vault_id" && "$vault_id" != "null" ]] || { echo "Vault create failed"; exit 1; }

ai_job_resp="$(curl_json POST "${AI_BASE}/ai/jobs" "{\"creator\":\"ynx_creator_${SUFFIX}\",\"worker\":\"\",\"reward\":\"1000\",\"stake\":\"100\",\"input_uri\":\"ipfs://input/${SUFFIX}\",\"vault_id\":\"${vault_id}\"}" "x-ynx-session: ${session_token}")"
ai_job_id="$(echo "$ai_job_resp" | jq -r '.job.job_id')"
[[ -n "$ai_job_id" && "$ai_job_id" != "null" ]] || { echo "AI job create failed"; exit 1; }

commit_payload="$(cat <<EOF
{"worker":"ynx_worker_${SUFFIX}","result_hash":"0x${RAND}${RAND}${RAND}${RAND}","attestation_uri":"ipfs://att/${SUFFIX}"}
EOF
)"
curl_json POST "${AI_BASE}/ai/jobs/${ai_job_id}/commit" "$commit_payload" "x-ynx-session: ${session_token}" >/dev/null
curl_json POST "${AI_BASE}/ai/jobs/${ai_job_id}/finalize" '{"status":"finalized"}' "x-ynx-session: ${session_token}" >/dev/null
ai_job_final="$(curl_json GET "${AI_BASE}/ai/jobs/${ai_job_id}")"
ai_status="$(echo "$ai_job_final" | jq -r '.job.status')"
[[ "$ai_status" == "finalized" ]] || { echo "AI job status invalid: $ai_status"; exit 1; }
ai_payout_id="$(echo "$ai_job_final" | jq -r '.job.payout_payment_id')"
[[ -n "$ai_payout_id" && "$ai_payout_id" != "null" ]] || { echo "AI payout missing"; exit 1; }

direct_charge_resp="$(curl_json POST "${AI_BASE}/ai/payments/charge" "{\"vault_id\":\"${vault_id}\",\"amount\":25,\"resource\":\"smoke\",\"reason\":\"smoke\"}" "x-ynx-session: ${session_token}")"
direct_payment_id="$(echo "$direct_charge_resp" | jq -r '.payment.payment_id')"
[[ -n "$direct_payment_id" && "$direct_payment_id" != "null" ]] || { echo "Direct charge failed"; exit 1; }

x402_code="$(curl -s -o /dev/null -w "%{http_code}" "${AI_BASE}/x402/resource?resource=smoke&units=1")"
[[ "$x402_code" == "402" ]] || { echo "x402 expected 402, got $x402_code"; exit 1; }
x402_ok="$(curl_json GET "${AI_BASE}/x402/resource?resource=smoke&units=1" "" "x-ynx-payment: ${direct_payment_id}")"
x402_status="$(echo "$x402_ok" | jq -r '.ok')"
[[ "$x402_status" == "true" ]] || { echo "x402 settle failed"; exit 1; }

identity_payload="$(cat <<EOF
{"policy_id":"${policy_id}","address":"ynx1web4${RAND}${RAND}","did":"did:ynx:${SUFFIX}","profile_uri":"ipfs://profile/${SUFFIX}","tags":["web4","ai"]}
EOF
)"
identity_resp="$(curl_json POST "${WEB4_BASE}/web4/identities" "$identity_payload" "x-ynx-session: ${session_token}")"
identity_id="$(echo "$identity_resp" | jq -r '.identity.identity_id')"
[[ -n "$identity_id" && "$identity_id" != "null" ]] || { echo "Identity create failed"; exit 1; }

agent_payload="$(cat <<EOF
{"policy_id":"${policy_id}","owner":"ynx_owner_${SUFFIX}","name":"agent-${SUFFIX}","model":"ynx-ai-v2","endpoint":"https://agent.example/${SUFFIX}","capabilities":["inference","planning"],"stake":"500"}
EOF
)"
agent_resp="$(curl_json POST "${WEB4_BASE}/web4/agents" "$agent_payload" "x-ynx-session: ${session_token}")"
agent_id="$(echo "$agent_resp" | jq -r '.agent.agent_id')"
[[ -n "$agent_id" && "$agent_id" != "null" ]] || { echo "Agent create failed"; exit 1; }

self_update_payload='{"patch":{"model":"ynx-ai-v2.1","endpoint":"https://agent.example/v2","capabilities":["inference","planning","audit"]}}'
agent_updated_resp="$(curl_json POST "${WEB4_BASE}/web4/agents/${agent_id}/self-update" "$self_update_payload" "x-ynx-session: ${session_token}")"
agent_model="$(echo "$agent_updated_resp" | jq -r '.agent.model')"
[[ "$agent_model" == "ynx-ai-v2.1" ]] || { echo "Agent self-update failed"; exit 1; }

replicate_payload="$(cat <<EOF
{"policy_id":"${policy_id}","owner":"ynx_owner_${SUFFIX}","name":"agent-${SUFFIX}-child","stake":"150"}
EOF
)"
replicate_resp="$(curl_json POST "${WEB4_BASE}/web4/agents/${agent_id}/replicate" "$replicate_payload" "x-ynx-session: ${session_token}")"
child_agent_id="$(echo "$replicate_resp" | jq -r '.child.agent_id')"
[[ -n "$child_agent_id" && "$child_agent_id" != "null" ]] || { echo "Agent replication failed"; exit 1; }

intent_payload="$(cat <<EOF
{"policy_id":"${policy_id}","creator":"ynx_creator_${SUFFIX}","target_agent_id":"${agent_id}","payload_uri":"ipfs://intent/${SUFFIX}","constraints":{"latency_ms":800},"budget":"900"}
EOF
)"
intent_resp="$(curl_json POST "${WEB4_BASE}/web4/intents" "$intent_payload" "x-ynx-session: ${session_token}")"
intent_id="$(echo "$intent_resp" | jq -r '.intent.intent_id')"
[[ -n "$intent_id" && "$intent_id" != "null" ]] || { echo "Intent create failed"; exit 1; }

claim_payload="$(cat <<EOF
{"policy_id":"${policy_id}","agent_id":"${agent_id}","result_hash":"0x${RAND}${RAND}${RAND}abcd","proof_uri":"ipfs://proof/${SUFFIX}","metadata":{"source":"smoke"}}
EOF
)"
curl_json POST "${WEB4_BASE}/web4/intents/${intent_id}/claim" "$claim_payload" "x-ynx-session: ${session_token}" >/dev/null
curl_json POST "${WEB4_BASE}/web4/intents/${intent_id}/challenge" "{\"policy_id\":\"${policy_id}\"}" "x-ynx-session: ${session_token}" >/dev/null
curl_json POST "${WEB4_BASE}/web4/intents/${intent_id}/finalize" "{\"policy_id\":\"${policy_id}\",\"status\":\"failed\"}" "x-ynx-session: ${session_token}" >/dev/null

intent_final="$(curl_json GET "${WEB4_BASE}/web4/intents/${intent_id}")"
intent_status="$(echo "$intent_final" | jq -r '.intent.status')"
[[ "$intent_status" == "failed" ]] || { echo "Intent status invalid: $intent_status"; exit 1; }

policy_pause_resp="$(curl_json POST "${WEB4_BASE}/web4/policies/${policy_id}/pause" '{}' "x-ynx-owner: ${owner_secret}")"
policy_pause_status="$(echo "$policy_pause_resp" | jq -r '.policy.status')"
[[ "$policy_pause_status" == "paused" ]] || { echo "Policy pause failed"; exit 1; }

policy_resume_resp="$(curl_json POST "${WEB4_BASE}/web4/policies/${policy_id}/resume" '{}' "x-ynx-owner: ${owner_secret}")"
policy_resume_status="$(echo "$policy_resume_resp" | jq -r '.policy.status')"
[[ "$policy_resume_status" == "active" ]] || { echo "Policy resume failed"; exit 1; }

echo
echo "PASS"
echo "policy_id=${policy_id}"
echo "ai_job_id=${ai_job_id}"
echo "vault_id=${vault_id}"
echo "direct_payment_id=${direct_payment_id}"
echo "identity_id=${identity_id}"
echo "agent_id=${agent_id}"
echo "child_agent_id=${child_agent_id}"
echo "intent_id=${intent_id}"
