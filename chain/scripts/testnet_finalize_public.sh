#!/usr/bin/env bash

set -euo pipefail

OUT_DOC=""
LOCAL_RPC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --doc)
      OUT_DOC="${2:-}"
      shift 2
      ;;
    --local-rpc)
      LOCAL_RPC="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--doc FILE] [--local-rpc URL]

Finalize public testnet artifacts and regenerate the public checklist document.

Options:
  --doc FILE       Output checklist markdown path
  --local-rpc URL  Local RPC for runtime checks (default: http://127.0.0.1:26657)
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
REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"
OUT_DOC="${OUT_DOC:-$REPO_DIR/docs/en/PUBLIC_TESTNET_FINAL_CHECKLIST.md}"
LOCAL_RPC="${LOCAL_RPC:-http://127.0.0.1:26657}"

ENV_FILE="${YNX_ENV_FILE:-}"
if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "$REPO_DIR/.env" ]]; then
    ENV_FILE="$REPO_DIR/.env"
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

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

"$ROOT_DIR/scripts/testnet_release.sh" --reset --out "$ROOT_DIR/.release/current"
"$ROOT_DIR/scripts/testnet_publish_bundle.sh" --in "$ROOT_DIR/.release/current" --out "$ROOT_DIR/.release"

endpoints="$ROOT_DIR/.release/current/endpoints.json"
network="$ROOT_DIR/.release/current/network.json"

chain_id="$(jq -r '.chain_id // empty' "$network")"
evm_chain_id="$(jq -r '.evm_chain_id // empty' "$network")"
denom="$(jq -r '.denom // empty' "$network")"

rpc="$(jq -r '.rpc // empty' "$endpoints")"
jsonrpc="$(jq -r '.jsonrpc // empty' "$endpoints")"
grpc="$(jq -r '.grpc // empty' "$endpoints")"
rest="$(jq -r '.rest // empty' "$endpoints")"
seeds="$(jq -r '.seeds // empty' "$endpoints")"
peers="$(jq -r '.persistent_peers // empty' "$endpoints")"
faucet_url="$(jq -r '.faucet.url // empty' "$endpoints")"
faucet_address="$(jq -r '.faucet.address // empty' "$endpoints")"
explorer_url="$(jq -r '.explorer_url // empty' "$endpoints")"
indexer_url="$(jq -r '.indexer_url // empty' "$endpoints")"

height="$("$ROOT_DIR/ynxd" status --node "$LOCAL_RPC" 2>/dev/null | jq -r '.sync_info.latest_block_height // "unknown"')"
feemarket_json="$("$ROOT_DIR/ynxd" query feemarket params --node "$LOCAL_RPC" --output json 2>/dev/null || echo '{}')"
no_base_fee="$(echo "$feemarket_json" | jq -r '.params.no_base_fee // "unknown"')"

latest_bundle="$(cd "$ROOT_DIR/.release" && ls -1t ynx_testnet_"${chain_id}"_*.tar.gz 2>/dev/null | head -n 1 || true)"
latest_sha="$(cd "$ROOT_DIR/.release" && ls -1t ynx_testnet_"${chain_id}"_*.sha256 2>/dev/null | head -n 1 || true)"
latest_announcement="$(cd "$ROOT_DIR/.release" && ls -1t ynx_testnet_"${chain_id}"_*_ANNOUNCEMENT.md 2>/dev/null | head -n 1 || true)"

mkdir -p "$(dirname "$OUT_DOC")"
cat > "$OUT_DOC" <<EOF
# YNX Public Testnet Final Checklist

Status: Active  
Last updated: $(date -u +%Y-%m-%d)  
Canonical language: English

## 1. Network Snapshot (Current)

- Chain ID: \`${chain_id}\`
- EVM Chain ID: \`${evm_chain_id}\`
- Denom: \`${denom}\`
- Base Fee Mode: \`no_base_fee = ${no_base_fee}\`
- Latest checked height (local observer): \`${height}\`

## 2. Public Endpoints

- RPC: \`${rpc}\`
- JSON-RPC: \`${jsonrpc}\`
- gRPC: \`${grpc}\`
- REST: \`${rest}\`
- Seed: \`${seeds}\`
- Persistent Peer: \`${peers}\`
- Faucet: \`${faucet_url}\`
- Explorer: \`${explorer_url}\`
- Indexer: \`${indexer_url}\`

## 3. Governance and Treasury Addresses

- Founder: \`${YNX_FOUNDER_ADDRESS:-}\`
- Team Beneficiary: \`${YNX_TEAM_BENEFICIARY:-}\`
- Community Recipient: \`${YNX_COMMUNITY_RECIPIENT:-}\`
- Treasury: \`${YNX_TREASURY_ADDRESS:-}\`
- Faucet Funding Address: \`${faucet_address}\`

## 4. Release Artifacts (Generated)

Release directory:
- \`chain/.release/current\`

Publish bundle files:
- \`chain/.release/${latest_bundle}\`
- \`chain/.release/${latest_sha}\`
- \`chain/.release/${latest_announcement}\`

Bundle contents include:
- \`genesis.json\`
- \`config.toml\`
- \`app.toml\`
- \`network.json\`
- \`endpoints.json\`
- \`PUBLIC_TESTNET.md\`
- \`checksums.txt\`

## 5. Download Link Slots (for public posting)

Set these URLs after uploading artifacts (GitHub Releases or object storage):

- Bundle URL: \`<UPLOAD_URL>/${latest_bundle}\`
- SHA256 URL: \`<UPLOAD_URL>/${latest_sha}\`
- Announcement URL: \`<UPLOAD_URL>/${latest_announcement}\`

## 6. Operator Verification Commands

\`\`\`bash
curl -s ${rpc}/status
curl -s -X POST -H "content-type: application/json" \\
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \\
  ${jsonrpc}
curl -s ${faucet_url}/health
curl -s ${indexer_url}/health
\`\`\`

## 7. Public Open Ports (Inbound)

Open these TCP ports on host firewall and cloud security group:

- \`26656\` (P2P)
- \`26657\` (CometBFT RPC)
- \`8545\` (EVM JSON-RPC)
- \`8080\` (Faucet)
- \`8081\` (Indexer API)
- \`8082\` (Explorer)
- \`9090\` (gRPC, optional)
- \`1317\` (REST, optional)

## 8. Publish Sequence

1. Upload the three files from section 4 to a public location.
2. Replace link slots in section 5 with final URLs.
3. Publish the announcement markdown to your official channels.
4. Ask external operators to verify section 6 before joining.
EOF

echo "Checklist updated: $OUT_DOC"
