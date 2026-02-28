#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_testnet_release.sh

Package YNX v2 public testnet bootstrap bundle.

Environment:
  YNX_HOME            default: chain/.testnet-v2
  YNX_CHAIN_ID        default: ynx_9102-1
  YNX_OUT_DIR         default: chain/.release-v2/ynx_v2_<timestamp>
  YNX_RPC             default: http://127.0.0.1:36657
  YNX_EVM_RPC         default: http://127.0.0.1:38545
  YNX_REST            default: http://127.0.0.1:31317
  YNX_FAUCET          default: http://127.0.0.1:38080
  YNX_INDEXER         default: http://127.0.0.1:38081
  YNX_EXPLORER        default: http://127.0.0.1:38082
  YNX_AI_GATEWAY      default: http://127.0.0.1:38090
  YNX_WEB4_HUB        default: http://127.0.0.1:38091
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${YNX_OUT_DIR:-$ROOT_DIR/.release-v2/ynx_v2_${STAMP}}"

RPC="${YNX_RPC:-http://127.0.0.1:36657}"
EVM_RPC="${YNX_EVM_RPC:-http://127.0.0.1:38545}"
REST="${YNX_REST:-http://127.0.0.1:31317}"
FAUCET="${YNX_FAUCET:-http://127.0.0.1:38080}"
INDEXER="${YNX_INDEXER:-http://127.0.0.1:38081}"
EXPLORER="${YNX_EXPLORER:-http://127.0.0.1:38082}"
AI_GATEWAY="${YNX_AI_GATEWAY:-http://127.0.0.1:38090}"
WEB4_HUB="${YNX_WEB4_HUB:-http://127.0.0.1:38091}"

for required in "$HOME_DIR/config/genesis.json" "$HOME_DIR/config/config.toml" "$HOME_DIR/config/app.toml"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required file: $required" >&2
    exit 1
  fi
done

mkdir -p "$OUT_DIR"
cp "$HOME_DIR/config/genesis.json" "$OUT_DIR/genesis.json"
cp "$HOME_DIR/config/config.toml" "$OUT_DIR/config.toml"
cp "$HOME_DIR/config/app.toml" "$OUT_DIR/app.toml"

cat >"$OUT_DIR/endpoints.json" <<EOF
{
  "chain_id": "$CHAIN_ID",
  "rpc": "$RPC",
  "evm_rpc": "$EVM_RPC",
  "rest": "$REST",
  "faucet": "$FAUCET",
  "indexer": "$INDEXER",
  "explorer": "$EXPLORER",
  "ai_gateway": "$AI_GATEWAY",
  "web4_hub": "$WEB4_HUB"
}
EOF

status_json="$(curl -fsS --max-time 8 "$RPC/status" || true)"
overview_json="$(curl -fsS --max-time 8 "$INDEXER/ynx/overview" || true)"
ai_health="$(curl -fsS --max-time 8 "$AI_GATEWAY/health" || true)"
web4_health="$(curl -fsS --max-time 8 "$WEB4_HUB/health" || true)"

cat >"$OUT_DIR/network.json" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "chain_id": "$CHAIN_ID",
  "rpc_status": ${status_json:-{}},
  "overview": ${overview_json:-{}},
  "ai_health": ${ai_health:-{}},
  "web4_health": ${web4_health:-{}}
}
EOF

(cd "$OUT_DIR" && shasum -a 256 genesis.json config.toml app.toml endpoints.json network.json > checksums.sha256)

tar -czf "${OUT_DIR}.tar.gz" -C "$OUT_DIR" .
shasum -a 256 "${OUT_DIR}.tar.gz" > "${OUT_DIR}.tar.gz.sha256"

echo "DONE"
echo "OUT_DIR=$OUT_DIR"
echo "ARCHIVE=${OUT_DIR}.tar.gz"
echo "SHA256=${OUT_DIR}.tar.gz.sha256"
