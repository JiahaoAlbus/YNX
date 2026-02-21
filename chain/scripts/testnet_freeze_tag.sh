#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  testnet_freeze_tag.sh

Freeze current public testnet state into a report and optionally create/push a git tag.

Environment:
  YNX_ROOT              default: repo root inferred from script path
  CHAIN_ID              default: ynx_9002-1
  PUBLIC_RPC            default: http://43.134.23.58:26657
  PUBLIC_INDEXER        default: http://43.134.23.58:8081
  OUT_DIR               default: $YNX_ROOT/ops-logs/freeze
  CREATE_TAG            default: 1 (1=create tag, 0=skip)
  TAG_PREFIX            default: testnet-freeze
  PUSH_TAG              default: 0 (1=push tag to origin)

Example:
  ./scripts/testnet_freeze_tag.sh
  PUSH_TAG=1 ./scripts/testnet_freeze_tag.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YNX_ROOT="${YNX_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
CHAIN_ID="${CHAIN_ID:-ynx_9002-1}"
PUBLIC_RPC="${PUBLIC_RPC:-http://43.134.23.58:26657}"
PUBLIC_INDEXER="${PUBLIC_INDEXER:-http://43.134.23.58:8081}"
OUT_DIR="${OUT_DIR:-$YNX_ROOT/ops-logs/freeze}"
CREATE_TAG="${CREATE_TAG:-1}"
TAG_PREFIX="${TAG_PREFIX:-testnet-freeze}"
PUSH_TAG="${PUSH_TAG:-0}"

mkdir -p "$OUT_DIR"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
tag="${TAG_PREFIX}-${CHAIN_ID}-${timestamp}"
report="$OUT_DIR/${tag}.md"

cd "$YNX_ROOT"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $YNX_ROOT" >&2
  exit 1
fi

head_sha="$(git rev-parse HEAD)"
branch_name="$(git rev-parse --abbrev-ref HEAD)"

fetch_json() {
  local url="$1"
  local attempts=0
  local max_attempts=3
  while (( attempts < max_attempts )); do
    attempts=$((attempts + 1))
    if body="$(curl -fsSL --connect-timeout 8 --max-time 20 "$url" 2>/dev/null)"; then
      printf '%s' "$body"
      return 0
    fi
    sleep 2
  done
  return 1
}

rpc_status="$(fetch_json "$PUBLIC_RPC/status" || true)"
if [[ -z "$rpc_status" ]]; then
  echo "Failed to fetch RPC status after retries: $PUBLIC_RPC/status" >&2
  exit 1
fi
rpc_chain_id="$(echo "$rpc_status" | jq -r '.result.node_info.network')"
rpc_height="$(echo "$rpc_status" | jq -r '.result.sync_info.latest_block_height')"
rpc_catching_up="$(echo "$rpc_status" | jq -r '.result.sync_info.catching_up')"
validators_json="$(fetch_json "$PUBLIC_RPC/validators?per_page=100" || true)"
if [[ -z "$validators_json" ]]; then
  echo "Failed to fetch validator set after retries: $PUBLIC_RPC/validators?per_page=100" >&2
  exit 1
fi
validators_total="$(echo "$validators_json" | jq -r '.result.total')"
ynx_overview="$(fetch_json "$PUBLIC_INDEXER/ynx/overview" || true)"

cat >"$report" <<EOF
# YNX Public Testnet Freeze Report

- Timestamp (UTC): ${timestamp}
- Chain ID: ${CHAIN_ID}
- Public RPC: ${PUBLIC_RPC}
- Public Indexer: ${PUBLIC_INDEXER}
- Git branch: ${branch_name}
- Git commit: ${head_sha}

## Runtime Snapshot

- RPC reported chain_id: ${rpc_chain_id}
- Latest block height: ${rpc_height}
- Catching up: ${rpc_catching_up}
- Validator count (CometBFT set): ${validators_total}

## Validators (staking)

\`\`\`bash
./ynxd query staking validators --node ${PUBLIC_RPC} -o json | jq -r '.validators[] | [.description.moniker,.status,.jailed] | @tsv'
\`\`\`

\`\`\`text
$(./chain/ynxd query staking validators --node "$PUBLIC_RPC" -o json 2>/dev/null | jq -r '.validators[] | [.description.moniker,.status,.jailed] | @tsv' || echo "Run command on an environment with ./chain/ynxd binary.")
\`\`\`

## Indexer Overview

\`\`\`json
${ynx_overview:-{}}
\`\`\`

## Next Gate

- Keep both validators \`BOND_STATUS_BONDED\` and non-jailed for continuous operation.
- Continue validator onboarding with \`./chain/scripts/validator_onboard_safe.sh\`.
- Keep monitoring with \`./chain/scripts/testnet_watchdog.sh\`.
EOF

echo "Freeze report: $report"

if [[ "$CREATE_TAG" == "1" ]]; then
  if git rev-parse "$tag" >/dev/null 2>&1; then
    echo "Tag already exists locally: $tag"
  else
    git tag -a "$tag" -m "YNX public testnet freeze ${timestamp}"
    echo "Created tag: $tag"
  fi
  if [[ "$PUSH_TAG" == "1" ]]; then
    git push origin "$tag"
    echo "Pushed tag: $tag"
  fi
fi

echo "DONE"
