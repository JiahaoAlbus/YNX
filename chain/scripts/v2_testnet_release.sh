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
  YNX_BIN             default: chain/ynxd
  YNX_DENOM           default: anyxt
  YNX_MIN_GAS_PRICES  default: 0.000000007anyxt
  YNX_P2P_HOST        default: host parsed from YNX_RPC or 127.0.0.1
  YNX_P2P_PORT        default: 36656
  YNX_GRPC            default: http://127.0.0.1:39090
  YNX_EVM_WS          default: ws://127.0.0.1:38546
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
DENOM="${YNX_DENOM:-anyxt}"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${YNX_OUT_DIR:-$ROOT_DIR/.release-v2/ynx_v2_${STAMP}}"
BIN="${YNX_BIN:-$ROOT_DIR/ynxd}"

RPC="${YNX_RPC:-http://127.0.0.1:36657}"
EVM_RPC="${YNX_EVM_RPC:-http://127.0.0.1:38545}"
EVM_WS="${YNX_EVM_WS:-ws://127.0.0.1:38546}"
REST="${YNX_REST:-http://127.0.0.1:31317}"
GRPC="${YNX_GRPC:-http://127.0.0.1:39090}"
FAUCET="${YNX_FAUCET:-http://127.0.0.1:38080}"
INDEXER="${YNX_INDEXER:-http://127.0.0.1:38081}"
EXPLORER="${YNX_EXPLORER:-http://127.0.0.1:38082}"
AI_GATEWAY="${YNX_AI_GATEWAY:-http://127.0.0.1:38090}"
WEB4_HUB="${YNX_WEB4_HUB:-http://127.0.0.1:38091}"
P2P_PORT="${YNX_P2P_PORT:-36656}"
MIN_GAS_PRICES="${YNX_MIN_GAS_PRICES:-0.000000007${DENOM}}"

rpc_host="$(echo "$RPC" | sed -E 's#^https?://([^/:]+).*$#\1#')"
P2P_HOST="${YNX_P2P_HOST:-$rpc_host}"

for required in "$HOME_DIR/config/genesis.json" "$HOME_DIR/config/config.toml" "$HOME_DIR/config/app.toml"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required file: $required" >&2
    exit 1
  fi
done

if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (cd "$ROOT_DIR" && CGO_ENABLED=0 go build -buildvcs=false -o "$BIN" ./cmd/ynxd)
fi

mkdir -p "$OUT_DIR"
cp "$HOME_DIR/config/genesis.json" "$OUT_DIR/genesis.json"
cp "$HOME_DIR/config/config.toml" "$OUT_DIR/config.toml"
cp "$HOME_DIR/config/app.toml" "$OUT_DIR/app.toml"
cp "$BIN" "$OUT_DIR/ynxd"
chmod +x "$OUT_DIR/ynxd"

mkdir -p "$OUT_DIR/bootstrap" "$OUT_DIR/roles"
cp "$ROOT_DIR/scripts/v2_validator_bootstrap.sh" "$OUT_DIR/bootstrap/"
cp "$ROOT_DIR/scripts/v2_role_apply.sh" "$OUT_DIR/bootstrap/"

node_id="$("$BIN" comet show-node-id --home "$HOME_DIR" 2>/dev/null || true)"
seed_entry=""
if [[ -n "$node_id" && -n "$P2P_HOST" ]]; then
  seed_entry="${node_id}@${P2P_HOST}:${P2P_PORT}"
fi
seeds="${YNX_SEEDS:-$seed_entry}"
persistent_peers="${YNX_PERSISTENT_PEERS:-$seed_entry}"

cat >"$OUT_DIR/endpoints.json" <<EOF
{
  "chain_id": "$CHAIN_ID",
  "rpc": "$RPC",
  "evm_rpc": "$EVM_RPC",
  "evm_ws": "$EVM_WS",
  "grpc": "$GRPC",
  "rest": "$REST",
  "faucet": "$FAUCET",
  "indexer": "$INDEXER",
  "explorer": "$EXPLORER",
  "ai_gateway": "$AI_GATEWAY",
  "web4_hub": "$WEB4_HUB",
  "p2p_host": "$P2P_HOST",
  "p2p_port": $P2P_PORT,
  "seeds": "$seeds",
  "persistent_peers": "$persistent_peers"
}
EOF

status_json="$(curl -fsS --max-time 8 "$RPC/status" || true)"
overview_json="$(curl -fsS --max-time 8 "$INDEXER/ynx/overview" || true)"
ai_health="$(curl -fsS --max-time 8 "$AI_GATEWAY/health" || true)"
web4_health="$(curl -fsS --max-time 8 "$WEB4_HUB/health" || true)"
ynxd_sha="$(shasum -a 256 "$OUT_DIR/ynxd" | awk '{print $1}')"
genesis_sha="$(shasum -a 256 "$OUT_DIR/genesis.json" | awk '{print $1}')"

cat >"$OUT_DIR/network.json" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "chain_id": "$CHAIN_ID",
  "denom": "$DENOM",
  "minimum_gas_prices": "$MIN_GAS_PRICES",
  "binary": {
    "name": "ynxd",
    "sha256": "$ynxd_sha"
  },
  "genesis": {
    "sha256": "$genesis_sha"
  },
  "rpc_status": ${status_json:-{}},
  "overview": ${overview_json:-{}},
  "ai_health": ${ai_health:-{}},
  "web4_health": ${web4_health:-{}}
}
EOF

cat >"$OUT_DIR/descriptor.json" <<EOF
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "track": "v2-web4",
  "chain_id": "$CHAIN_ID",
  "denom": "$DENOM",
  "minimum_gas_prices": "$MIN_GAS_PRICES",
  "recommended_profile": "web4-global-stable",
  "recommended_role": "validator",
  "binary": {
    "name": "ynxd",
    "relative_path": "ynxd",
    "sha256": "$ynxd_sha"
  },
  "genesis": {
    "relative_path": "genesis.json",
    "sha256": "$genesis_sha"
  },
  "bootstrap": {
    "script": "bootstrap/v2_validator_bootstrap.sh",
    "role_script": "bootstrap/v2_role_apply.sh"
  },
  "network": {
    "p2p_port": $P2P_PORT,
    "rpc": "$RPC",
    "evm_rpc": "$EVM_RPC",
    "evm_ws": "$EVM_WS",
    "grpc": "$GRPC",
    "rest": "$REST",
    "faucet": "$FAUCET",
    "indexer": "$INDEXER",
    "explorer": "$EXPLORER",
    "ai_gateway": "$AI_GATEWAY",
    "web4_hub": "$WEB4_HUB",
    "seeds": "$seeds",
    "persistent_peers": "$persistent_peers"
  },
  "roles": {
    "validator": {
      "public_rpc": false,
      "public_rest": false,
      "public_evm": false
    },
    "full-node": {
      "public_rpc": false,
      "public_rest": false,
      "public_evm": false
    },
    "public-rpc": {
      "public_rpc": true,
      "public_rest": true,
      "public_evm": true
    }
  }
}
EOF

cat >"$OUT_DIR/roles/validator.env" <<EOF
YNX_NODE_ROLE=validator
YNX_RPC_PORT=36657
YNX_REST_PORT=31317
YNX_EVM_PORT=38545
YNX_EVM_WS_PORT=38546
EOF

cat >"$OUT_DIR/roles/full-node.env" <<EOF
YNX_NODE_ROLE=full-node
YNX_RPC_PORT=36657
YNX_REST_PORT=31317
YNX_EVM_PORT=38545
YNX_EVM_WS_PORT=38546
EOF

cat >"$OUT_DIR/roles/public-rpc.env" <<EOF
YNX_NODE_ROLE=public-rpc
YNX_RPC_PORT=36657
YNX_REST_PORT=31317
YNX_EVM_PORT=38545
YNX_EVM_WS_PORT=38546
EOF

cat >"$OUT_DIR/README_OPERATOR.md" <<EOF
# YNX v2 Operator Bundle

- Chain ID: \`$CHAIN_ID\`
- Denom: \`$DENOM\`
- Min Gas Prices: \`$MIN_GAS_PRICES\`
- RPC: \`$RPC\`
- P2P: \`$P2P_HOST:$P2P_PORT\`
- Seeds: \`$seeds\`
- Persistent Peers: \`$persistent_peers\`

Recommended bootstrap:

\`\`\`bash
./bootstrap/v2_validator_bootstrap.sh \\
  --bundle . \\
  --role validator \\
  --home ~/.ynx-v2-validator \\
  --moniker <YOUR_MONIKER> \\
  --reset
\`\`\`
EOF

(cd "$OUT_DIR" && shasum -a 256 genesis.json config.toml app.toml ynxd endpoints.json network.json descriptor.json README_OPERATOR.md bootstrap/v2_validator_bootstrap.sh bootstrap/v2_role_apply.sh roles/*.env > checksums.sha256)

if command -v gtar >/dev/null 2>&1; then
  COPYFILE_DISABLE=1 gtar --no-xattrs --no-acls --warning=no-unknown-keyword -czf "${OUT_DIR}.tar.gz" -C "$OUT_DIR" .
else
  COPYFILE_DISABLE=1 tar -czf "${OUT_DIR}.tar.gz" -C "$OUT_DIR" .
fi
shasum -a 256 "${OUT_DIR}.tar.gz" > "${OUT_DIR}.tar.gz.sha256"

echo "DONE"
echo "OUT_DIR=$OUT_DIR"
echo "ARCHIVE=${OUT_DIR}.tar.gz"
echo "SHA256=${OUT_DIR}.tar.gz.sha256"
