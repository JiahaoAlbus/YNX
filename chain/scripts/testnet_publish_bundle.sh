#!/usr/bin/env bash

set -euo pipefail

IN_DIR=""
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --in)
      IN_DIR="${2:-}"
      shift 2
      ;;
    --out)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--in DIR] [--out DIR]

Packages a public testnet release bundle and generates publish-ready metadata.

Options:
  --in DIR   Input release directory (default: chain/.release/current)
  --out DIR  Output directory for archive (default: chain/.release)
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
IN_DIR="${IN_DIR:-$ROOT_DIR/.release/current}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/.release}"

if [[ ! -d "$IN_DIR" ]]; then
  echo "Missing release input directory: $IN_DIR" >&2
  exit 1
fi

for required in genesis.json config.toml app.toml network.json endpoints.json; do
  if [[ ! -f "$IN_DIR/$required" ]]; then
    echo "Missing required file: $IN_DIR/$required" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required by this script." >&2
  exit 1
fi

chain_id="$(jq -r '.chain_id // empty' "$IN_DIR/network.json")"
evm_chain_id="$(jq -r '.evm_chain_id // empty' "$IN_DIR/network.json")"
denom="$(jq -r '.denom // empty' "$IN_DIR/network.json")"
rpc="$(jq -r '.rpc // empty' "$IN_DIR/endpoints.json")"
jsonrpc="$(jq -r '.jsonrpc // empty' "$IN_DIR/endpoints.json")"
grpc="$(jq -r '.grpc // empty' "$IN_DIR/endpoints.json")"
rest="$(jq -r '.rest // empty' "$IN_DIR/endpoints.json")"
seeds="$(jq -r '.seeds // empty' "$IN_DIR/endpoints.json")"
peers="$(jq -r '.persistent_peers // empty' "$IN_DIR/endpoints.json")"
faucet_url="$(jq -r '.faucet.url // empty' "$IN_DIR/endpoints.json")"
faucet_address="$(jq -r '.faucet.address // empty' "$IN_DIR/endpoints.json")"
explorer_url="$(jq -r '.explorer_url // empty' "$IN_DIR/endpoints.json")"
indexer_url="$(jq -r '.indexer_url // empty' "$IN_DIR/endpoints.json")"

if [[ -z "$chain_id" ]]; then
  echo "Invalid network.json: chain_id is empty" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
base="ynx_testnet_${chain_id}_${stamp}"
archive="$OUT_DIR/${base}.tar.gz"
archive_sha="$OUT_DIR/${base}.sha256"
announcement="$OUT_DIR/${base}_ANNOUNCEMENT.md"

tar -czf "$archive" -C "$IN_DIR" .
shasum -a 256 "$archive" > "$archive_sha"

cat > "$announcement" <<EOF
# YNX Public Testnet Announcement

Generated at: \`$(date -u +"%Y-%m-%dT%H:%M:%SZ")\`

## Network
- Chain ID: \`${chain_id}\`
- EVM Chain ID: \`${evm_chain_id}\`
- Denom: \`${denom}\`

## Endpoints
- RPC: \`${rpc}\`
- JSON-RPC: \`${jsonrpc}\`
- gRPC: \`${grpc}\`
- REST: \`${rest}\`
- Explorer: \`${explorer_url}\`
- Indexer: \`${indexer_url}\`

## P2P
- Seeds: \`${seeds}\`
- Persistent Peers: \`${peers}\`

## Faucet
- URL: \`${faucet_url}\`
- Address: \`${faucet_address}\`

## Artifacts
- Bundle: \`$(basename "$archive")\`
- SHA256: \`$(basename "$archive_sha")\`

## Join
\`\`\`bash
tar -xzf $(basename "$archive")
shasum -a 256 -c $(basename "$archive_sha")
\`\`\`
EOF

echo "Publish artifacts generated:"
echo "  Bundle:       $archive"
echo "  Bundle SHA:   $archive_sha"
echo "  Announcement: $announcement"
