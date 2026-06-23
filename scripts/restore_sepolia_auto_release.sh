#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/restore_sepolia_auto_release.sh --server ubuntu@HOST --key /path/to/pem --owner-key 0x...

What it does:
  1. Writes BRIDGE_SOURCE_EVM_PRIVATE_KEY into /etc/ynx-v2/env
  2. Restarts bridge + indexer
  3. Verifies public bridge health now sees the signer

Notes:
  - This script does NOT deploy the BSC lockbox.
  - The owner key must be the Sepolia source lockbox owner:
    0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5
EOF
}

SERVER=""
PEM=""
OWNER_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server) SERVER="${2:-}"; shift 2 ;;
    --key) PEM="${2:-}"; shift 2 ;;
    --owner-key) OWNER_KEY="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "${SERVER}" ]] || { usage; exit 1; }
[[ -n "${PEM}" ]] || { usage; exit 1; }
[[ -n "${OWNER_KEY}" ]] || { usage; exit 1; }

command -v ssh >/dev/null 2>&1 || { echo "ssh not found" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }

ssh -i "${PEM}" "${SERVER}" "sudo bash -lc '
set -euo pipefail
cp /etc/ynx-v2/env /etc/ynx-v2/env.bak.\$(date +%Y%m%d%H%M%S)
python3 - <<PY
from pathlib import Path
p=Path(\"/etc/ynx-v2/env\")
text=p.read_text()
key=\"${OWNER_KEY}\"
lines=text.splitlines()
seen=False
out=[]
for line in lines:
    if \"=\" in line and not line.lstrip().startswith(\"#\") and line.split(\"=\",1)[0] == \"BRIDGE_SOURCE_EVM_PRIVATE_KEY\":
        out.append(f\"BRIDGE_SOURCE_EVM_PRIVATE_KEY={key}\")
        seen=True
    else:
        out.append(line)
if not seen:
    out.append(f\"BRIDGE_SOURCE_EVM_PRIVATE_KEY={key}\")
p.write_text(\"\\n\".join(out)+\"\\n\")
PY
systemctl restart ynx-v2-bridge-service.service ynx-v2-indexer.service
sleep 5
curl -s http://127.0.0.1:8080/bridge/health | jq \"{sepolia:(.route_readiness.items[] | select(.routeId==\\\"eth-sepolia-eth\\\") | {recommended_action, signer_diagnostics, release_status:.evidence.release_adapter_status})}\"
'"

echo "Remote update finished. Verifying public endpoint..."

curl --http1.1 -fsSL "https://rpc.ynxweb4.com/bridge/health" | jq \
  '{sepolia:(.route_readiness.items[] | select(.routeId=="eth-sepolia-eth") | {recommended_action, signer_diagnostics, release_status:.evidence.release_adapter_status})}'
