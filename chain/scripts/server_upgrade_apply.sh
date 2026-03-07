#!/usr/bin/env bash

set -euo pipefail

REMOTE_HOST="${1:-}"
SSH_KEY="${2:-}"

if [[ -z "$REMOTE_HOST" || -z "$SSH_KEY" ]]; then
  echo "Usage: $0 <user@host> <ssh_key_path>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_LINUX_BIN="$("$ROOT_DIR/scripts/build_linux_ynxd.sh")"

scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$LOCAL_LINUX_BIN" "$REMOTE_HOST:~/YNX/chain/ynxd"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_HOST" 'bash -s' <<'EOF'
set -euo pipefail

cd ~/YNX
git pull --ff-only

cd ~/YNX/chain
chmod +x ynxd

cd ~/YNX
(cd infra/faucet && npm install --omit=dev >/dev/null)
(cd infra/indexer && npm install --omit=dev >/dev/null)
(cd infra/explorer && npm install --omit=dev >/dev/null)

sudo systemctl restart ynx-node ynx-faucet ynx-indexer ynx-explorer
sleep 3
sudo systemctl --no-pager --full status ynx-node | head -n 12
sudo systemctl --no-pager --full status ynx-indexer | head -n 12

YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh
EOF
