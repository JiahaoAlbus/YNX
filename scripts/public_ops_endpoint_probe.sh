#!/usr/bin/env bash

set -euo pipefail

INDEXER_URL="${YNX_INDEXER_URL:-https://indexer.ynxweb4.com}"
AI_URL="${YNX_AI_URL:-https://ai.ynxweb4.com}"
BRIDGE_URL="${YNX_BRIDGE_URL:-https://rpc.ynxweb4.com}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"
}

need curl
need jq

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

curl --http1.1 -fsSL "${INDEXER_URL}/ynx/public-operations" > "${tmp_dir}/public_ops.json"
curl --http1.1 -fsSL "${INDEXER_URL}/ynx/overview" > "${tmp_dir}/overview.json"
curl --http1.1 -fsSL "${AI_URL}/health" > "${tmp_dir}/ai_health.json"
curl --http1.1 -fsSL "${BRIDGE_URL}/bridge/health" > "${tmp_dir}/bridge_health.json"

jq -e '.ok == true' "${tmp_dir}/public_ops.json" >/dev/null || fail "public-operations endpoint not ok"
jq -e '.title == "The shortest live proof board"' "${tmp_dir}/public_ops.json" >/dev/null || fail "unexpected public-operations title"
jq -e '.validator.bonded_count >= 4' "${tmp_dir}/public_ops.json" >/dev/null || fail "bonded validator count below 4"
jq -e '.routes.deposit_tested >= 4' "${tmp_dir}/public_ops.json" >/dev/null || fail "deposit-tested routes below 4"
jq -e '.routes.release_observed >= 5' "${tmp_dir}/public_ops.json" >/dev/null || fail "release-observed routes below 5"
jq -e '.routes.deposit_watchers_live >= 4' "${tmp_dir}/public_ops.json" >/dev/null || fail "deposit watcher live routes below 4"
jq -e '.validator.overall_gate_pass == true' "${tmp_dir}/public_ops.json" >/dev/null || fail "validator overall gate not passing"

jq -e '.onchain.ready == true' "${tmp_dir}/ai_health.json" >/dev/null || fail "AI onchain not ready"
jq -e '.headline_metrics.ai_onchain_ready == true' "${tmp_dir}/overview.json" >/dev/null || fail "overview still shows ai_onchain_ready=false"

jq -e '.route_readiness.items[] | select(.routeId=="eth-sepolia-eth") | .signer_diagnostics.lockbox_owner == "0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5"' "${tmp_dir}/bridge_health.json" >/dev/null \
  || fail "sepolia ETH lockbox owner diagnostic missing"
jq -e '.route_readiness.items[] | select(.routeId=="eth-sepolia-usdc") | .signer_diagnostics.lockbox_owner == "0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5"' "${tmp_dir}/bridge_health.json" >/dev/null \
  || fail "sepolia USDC lockbox owner diagnostic missing"

echo "PASS: public operations endpoint, AI onchain readiness, and bridge signer diagnostics are consistent."
