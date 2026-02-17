#!/usr/bin/env bash

set -euo pipefail

RESET=0
SNAPSHOT=0
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
      ;;
    --snapshot)
      SNAPSHOT=1
      shift
      ;;
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--reset] [--snapshot] [--out DIR]

Creates a release bundle for a public YNX testnet.

Options:
  --reset      Clear the output directory before writing
  --snapshot   Create a data snapshot tarball (requires YNX_RPC)
  --out DIR    Output directory (default: chain/.release/<chain-id>-<date>)

Environment:
  YNX_HOME           Node home (default: chain/.testnet)
  YNX_CHAIN_ID       Override chain id (optional)
  YNX_DENOM          Gas denom (default: anyxt)
  YNX_RPC            CometBFT RPC for snapshot height (e.g., http://127.0.0.1:26657)
  YNX_RPC_ENDPOINT   Public CometBFT RPC endpoint (default: YNX_RPC or local)
  YNX_JSONRPC_ENDPOINT Public EVM JSON-RPC endpoint (default: http://127.0.0.1:8545)
  YNX_GRPC_ENDPOINT  Public gRPC endpoint (optional)
  YNX_REST_ENDPOINT  Public REST endpoint (optional)
  YNX_FAUCET_URL     Public faucet base URL (optional)
  YNX_FAUCET_ADDRESS Faucet funding account bech32 address (optional)
  YNX_EXPLORER_URL   Public explorer URL (optional)
  YNX_INDEXER_URL    Public indexer URL (optional)
  YNX_SEEDS          Comma-separated seed list (nodeid@ip:port)
  YNX_PERSISTENT_PEERS Comma-separated peer list (nodeid@ip:port)
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet}"
DENOM="${YNX_DENOM:-anyxt}"
BIN="$ROOT_DIR/ynxd"

ENV_FILE="${YNX_ENV_FILE:-}"
if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "$ROOT_DIR/../.env" ]]; then
    ENV_FILE="$ROOT_DIR/../.env"
  elif [[ -f "$ROOT_DIR/.env" ]]; then
    ENV_FILE="$ROOT_DIR/.env"
  fi
fi
if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (
    cd "$ROOT_DIR"
    CGO_ENABLED="${YNX_CGO_ENABLED:-0}" go build -o "$BIN" ./cmd/ynxd
  )
fi

GENESIS="$HOME_DIR/config/genesis.json"
CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

if [[ ! -f "$GENESIS" ]]; then
  echo "Missing genesis: $GENESIS" >&2
  exit 1
fi

chain_id="${YNX_CHAIN_ID:-}"
if [[ -z "$chain_id" && -f "$HOME_DIR/config/client.toml" ]]; then
  chain_id="$(grep -E '^chain-id = ' "$HOME_DIR/config/client.toml" | head -n 1 | sed -E 's/chain-id = "([^"]+)"/\1/')"
fi
if [[ -z "$chain_id" && -f "$GENESIS" ]]; then
  if command -v node >/dev/null 2>&1; then
    chain_id="$(G="$GENESIS" node -e "const fs=require('fs');const g=JSON.parse(fs.readFileSync(process.env.G,'utf8'));console.log(g.chain_id||'')")"
  fi
fi
if [[ -z "$chain_id" && -f "$GENESIS" ]]; then
  chain_id="$(grep -E '\"chain_id\"' "$GENESIS" | head -n 1 | sed -E 's/.*\"chain_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\1/')"
fi
if [[ -z "$chain_id" ]]; then
  echo "Unable to determine chain id. Set YNX_CHAIN_ID." >&2
  exit 1
fi

evm_chain_id="$(grep -E '^evm-chain-id = ' "$APP_TOML" | head -n 1 | sed -E 's/evm-chain-id = ([0-9]+)/\1/')"
if [[ -z "$evm_chain_id" && "$chain_id" =~ ^ynx_([0-9]+)- ]]; then
  evm_chain_id="${BASH_REMATCH[1]}"
fi
if [[ -z "$evm_chain_id" ]]; then
  evm_chain_id="9002"
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$ROOT_DIR/.release/${chain_id}-$(date +%Y%m%d)"
fi

if [[ "$RESET" -eq 1 && -d "$OUT_DIR" ]]; then
  rm -rf "$OUT_DIR"
fi
mkdir -p "$OUT_DIR"

echo "Writing release bundle to: $OUT_DIR"
cp "$GENESIS" "$OUT_DIR/genesis.json"
cp "$CONFIG_TOML" "$OUT_DIR/config.toml"
cp "$APP_TOML" "$OUT_DIR/app.toml"

if [[ -n "${YNX_SEEDS:-}" ]]; then
  echo "$YNX_SEEDS" > "$OUT_DIR/seeds.txt"
fi
if [[ -n "${YNX_PERSISTENT_PEERS:-}" ]]; then
  echo "$YNX_PERSISTENT_PEERS" > "$OUT_DIR/persistent_peers.txt"
fi

rpc_endpoint="${YNX_RPC_ENDPOINT:-${YNX_RPC:-http://127.0.0.1:26657}}"
rpc_scheme="$(echo "$rpc_endpoint" | sed -E 's#^(https?)://.*#\1#')"
rpc_host="$(echo "$rpc_endpoint" | sed -E 's#^https?://([^/:]+).*$#\1#')"
if [[ -z "$rpc_scheme" || "$rpc_scheme" == "$rpc_endpoint" ]]; then
  rpc_scheme="http"
fi
if [[ -z "$rpc_host" || "$rpc_host" == "$rpc_endpoint" ]]; then
  rpc_host="127.0.0.1"
fi

jsonrpc_endpoint="${YNX_JSONRPC_ENDPOINT:-${rpc_scheme}://${rpc_host}:8545}"
grpc_endpoint="${YNX_GRPC_ENDPOINT:-${rpc_host}:9090}"
rest_endpoint="${YNX_REST_ENDPOINT:-${rpc_scheme}://${rpc_host}:1317}"
faucet_url="${YNX_FAUCET_URL:-${rpc_scheme}://${rpc_host}:8080}"
faucet_address="${YNX_FAUCET_ADDRESS:-}"
explorer_url="${YNX_EXPLORER_URL:-${rpc_scheme}://${rpc_host}:8082}"
indexer_url="${YNX_INDEXER_URL:-${rpc_scheme}://${rpc_host}:8081}"

if command -v shasum >/dev/null 2>&1; then
  (
    cd "$OUT_DIR"
    shasum -a 256 genesis.json config.toml app.toml > checksums.txt
  )
fi

cat > "$OUT_DIR/network.json" <<EOF
{
  "chain_id": "${chain_id}",
  "evm_chain_id": "${evm_chain_id}",
  "denom": "${DENOM}",
  "genesis_sha256": "$(shasum -a 256 "$OUT_DIR/genesis.json" | awk '{print $1}')"
}
EOF

cat > "$OUT_DIR/endpoints.json" <<EOF
{
  "generated_at_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "chain_id": "${chain_id}",
  "evm_chain_id": "${evm_chain_id}",
  "rpc": "${rpc_endpoint}",
  "jsonrpc": "${jsonrpc_endpoint}",
  "grpc": "${grpc_endpoint}",
  "rest": "${rest_endpoint}",
  "seeds": "${YNX_SEEDS:-}",
  "persistent_peers": "${YNX_PERSISTENT_PEERS:-}",
  "faucet": {
    "url": "${faucet_url}",
    "address": "${faucet_address}",
    "denom": "${DENOM}"
  },
  "explorer_url": "${explorer_url}",
  "indexer_url": "${indexer_url}"
}
EOF

cat > "$OUT_DIR/PUBLIC_TESTNET.md" <<EOF
# YNX Public Testnet Access

- Chain ID: \`${chain_id}\`
- EVM Chain ID: \`${evm_chain_id}\`
- Denom: \`${DENOM}\`
- RPC: \`${rpc_endpoint}\`
- JSON-RPC: \`${jsonrpc_endpoint}\`
- gRPC: \`${grpc_endpoint}\`
- REST: \`${rest_endpoint}\`
- Seeds: \`${YNX_SEEDS:-}\`
- Persistent Peers: \`${YNX_PERSISTENT_PEERS:-}\`
- Faucet URL: \`${faucet_url}\`
- Faucet Address: \`${faucet_address}\`
- Explorer: \`${explorer_url}\`
- Indexer: \`${indexer_url}\`

Generated at: \`$(date -u +"%Y-%m-%dT%H:%M:%SZ")\`
EOF

if [[ "$SNAPSHOT" -eq 1 ]]; then
  if [[ -z "${YNX_RPC:-}" ]]; then
    echo "YNX_RPC is required to create a snapshot." >&2
    exit 1
  fi
  height="$(curl -s "$YNX_RPC/status" | node -e "const fs=require('fs');const data=fs.readFileSync(0,'utf8');const json=JSON.parse(data);console.log(json.result.sync_info.latest_block_height)")"
  if [[ -z "$height" ]]; then
    echo "Unable to determine height from $YNX_RPC/status" >&2
    exit 1
  fi
  snapshot_name="snapshot_${chain_id}_${height}_$(date +%Y%m%d).tar.gz"
  tar -czf "$OUT_DIR/$snapshot_name" -C "$HOME_DIR" data
  echo "$snapshot_name" > "$OUT_DIR/snapshot.txt"
fi

echo "Release bundle complete."
