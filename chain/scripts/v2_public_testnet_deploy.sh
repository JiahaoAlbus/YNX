#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_public_testnet_deploy.sh <user@host> <ssh_key_path> [--reset] [--from-local|--from-remote-git] [--smoke-write]

Deploy YNX v2 Web4 public-testnet stack to a Linux server.

Default sync mode:
  --from-local (default) : sync current local repo files to remote before build/deploy
  --from-remote-git      : pull from remote GitHub repo only

Environment:
  YNX_REPO_URL       default: https://github.com/JiahaoAlbus/YNX.git
  YNX_REPO_DIR       default: ~/YNX
  YNX_HOME           default: ~/.ynx-v2
  YNX_CHAIN_ID       default: ynx_9102-1
  YNX_EVM_CHAIN_ID   default: 9102
  YNX_PROFILE        default: web4-global-stable
  YNX_P2P_PORT       default: 36656
  YNX_RPC_PORT       default: 36657
  YNX_REST_PORT      default: 31317
  YNX_EVM_PORT       default: 38545
  YNX_FAUCET_PORT    default: 38080
  YNX_INDEXER_PORT   default: 38081
  YNX_EXPLORER_PORT  default: 38082
  AI_GATEWAY_PORT    default: 38090
  WEB4_PORT          default: 38091
  USER_NAME          default: remote current user
EOF
}

REMOTE_HOST="${1:-}"
SSH_KEY="${2:-}"
RESET=0
SYNC_MODE="local"
SMOKE_WRITE=0

if [[ -z "$REMOTE_HOST" || -z "$SSH_KEY" ]]; then
  usage
  exit 1
fi

shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
      ;;
    --from-local)
      SYNC_MODE="local"
      shift
      ;;
    --from-remote-git)
      SYNC_MODE="remote-git"
      shift
      ;;
    --smoke-write)
      SMOKE_WRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

YNX_REPO_URL="${YNX_REPO_URL:-https://github.com/JiahaoAlbus/YNX.git}"
YNX_REPO_DIR="${YNX_REPO_DIR:-\$HOME/YNX}"
YNX_HOME="${YNX_HOME:-\$HOME/.ynx-v2}"
YNX_CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
YNX_EVM_CHAIN_ID="${YNX_EVM_CHAIN_ID:-9102}"
YNX_PROFILE="${YNX_PROFILE:-web4-global-stable}"
YNX_P2P_PORT="${YNX_P2P_PORT:-36656}"
YNX_RPC_PORT="${YNX_RPC_PORT:-36657}"
YNX_REST_PORT="${YNX_REST_PORT:-31317}"
YNX_EVM_PORT="${YNX_EVM_PORT:-38545}"
YNX_FAUCET_PORT="${YNX_FAUCET_PORT:-38080}"
YNX_INDEXER_PORT="${YNX_INDEXER_PORT:-38081}"
YNX_EXPLORER_PORT="${YNX_EXPLORER_PORT:-38082}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${WEB4_PORT:-38091}"
REMOTE_RESET="$RESET"
REMOTE_SMOKE_WRITE="$SMOKE_WRITE"
LOCAL_REPO_DIR="${LOCAL_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REMOTE_REPO_DIR="${YNX_REPO_DIR:-~/YNX}"
PUBLIC_HOST="${YNX_PUBLIC_HOST_OVERRIDE:-${REMOTE_HOST##*@}}"

if [[ "$SYNC_MODE" == "local" ]]; then
  if [[ ! -d "$LOCAL_REPO_DIR/chain" || ! -f "$LOCAL_REPO_DIR/README.md" ]]; then
    echo "Invalid LOCAL_REPO_DIR: $LOCAL_REPO_DIR" >&2
    exit 1
  fi
  if command -v gtar >/dev/null 2>&1; then
    TAR_BIN="gtar"
    TAR_FLAGS=(--no-xattrs --no-acls --warning=no-unknown-keyword)
  else
    TAR_BIN="tar"
    TAR_FLAGS=()
  fi
  echo "Syncing local repo to remote..."
  COPYFILE_DISABLE=1 "$TAR_BIN" "${TAR_FLAGS[@]}" -C "$LOCAL_REPO_DIR" -czf - \
    --exclude .git \
    --exclude node_modules \
    --exclude .idea \
    --exclude ops-logs \
    --exclude output \
    --exclude chain/.testnet \
    --exclude chain/.testnet-v2 \
    --exclude chain/.release-v2 \
    --exclude "*/data" \
    --exclude "*/data/*" \
    . | ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$REMOTE_HOST" "mkdir -p $REMOTE_REPO_DIR && tar -xzf - -C $REMOTE_REPO_DIR"
fi

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$REMOTE_HOST" "bash -s" <<EOF
set -euo pipefail

REPO_URL="$YNX_REPO_URL"
REPO_DIR=$REMOTE_REPO_DIR
V2_HOME=$YNX_HOME
CHAIN_ID="$YNX_CHAIN_ID"
EVM_CHAIN_ID="$YNX_EVM_CHAIN_ID"
PROFILE="$YNX_PROFILE"
P2P_PORT="$YNX_P2P_PORT"
RPC_PORT="$YNX_RPC_PORT"
REST_PORT="$YNX_REST_PORT"
EVM_PORT="$YNX_EVM_PORT"
FAUCET_PORT="$YNX_FAUCET_PORT"
INDEXER_PORT="$YNX_INDEXER_PORT"
EXPLORER_PORT="$YNX_EXPLORER_PORT"
AI_PORT="$AI_GATEWAY_PORT"
WEB4_PORT="$WEB4_PORT"
RESET_FLAG="$REMOTE_RESET"
SMOKE_WRITE_FLAG="$REMOTE_SMOKE_WRITE"
SYNC_MODE="$SYNC_MODE"

if [[ "\$(id -u)" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "Need root or sudo privileges on remote host" >&2
  exit 1
fi

run_root() {
  if [[ -n "\$SUDO" ]]; then
    \$SUDO "\$@"
  else
    "\$@"
  fi
}

install_base_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -y >/dev/null
    run_root apt-get install -y git curl jq build-essential screen tar >/dev/null
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y git curl jq gcc gcc-c++ make screen tar >/dev/null
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    run_root yum install -y git curl jq gcc gcc-c++ make screen tar >/dev/null
    return
  fi
  echo "Unsupported package manager (need apt-get/dnf/yum)" >&2
  exit 1
}

install_base_deps

if ! command -v node >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | run_root bash - >/dev/null
    run_root apt-get install -y nodejs >/dev/null
  elif command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y nodejs npm >/dev/null
  elif command -v yum >/dev/null 2>&1; then
    run_root yum install -y nodejs npm >/dev/null
  fi
fi

if ! command -v go >/dev/null 2>&1; then
  curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz -o /tmp/go.tar.gz
  run_root rm -rf /usr/local/go
  run_root tar -C /usr/local -xzf /tmp/go.tar.gz
fi
export PATH=/usr/local/go/bin:\$PATH
grep -q '/usr/local/go/bin' ~/.bashrc || echo 'export PATH=/usr/local/go/bin:\$PATH' >> ~/.bashrc

mkdir -p "\$REPO_DIR"
if [[ "\$SYNC_MODE" == "remote-git" ]]; then
  if [[ ! -d "\$REPO_DIR/.git" ]]; then
    git clone "\$REPO_URL" "\$REPO_DIR"
  fi
  cd "\$REPO_DIR"
  git fetch origin
  git checkout main
  git pull --ff-only
fi

cd "\$REPO_DIR/chain"
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd

for svc in faucet indexer explorer ai-gateway web4-hub; do
  (cd "\$REPO_DIR/infra/\$svc" && npm install --omit=dev >/dev/null)
done

for unit in \
  ynx-v2-node.service \
  ynx-v2-faucet.service \
  ynx-v2-indexer.service \
  ynx-v2-explorer.service \
  ynx-v2-ai-gateway.service \
  ynx-v2-web4-hub.service; do
  if systemctl list-unit-files --type=service 2>/dev/null | grep -q "^\${unit}"; then
    run_root systemctl stop "\$unit" || true
  fi
done

BOOTSTRAP_ARGS=()
if [[ "\$RESET_FLAG" == "1" ]]; then
  BOOTSTRAP_ARGS+=(--reset)
fi

if [[ "\$RESET_FLAG" == "1" || ! -f "\$V2_HOME/config/genesis.json" ]]; then
  if [[ "\${#BOOTSTRAP_ARGS[@]}" -gt 0 ]]; then
    YNX_HOME="\$V2_HOME" \
    YNX_CHAIN_ID="\$CHAIN_ID" \
    YNX_EVM_CHAIN_ID="\$EVM_CHAIN_ID" \
    "\$REPO_DIR/chain/scripts/v2_testnet_bootstrap.sh" "\${BOOTSTRAP_ARGS[@]}" --profile "\$PROFILE"
  else
    YNX_HOME="\$V2_HOME" \
    YNX_CHAIN_ID="\$CHAIN_ID" \
    YNX_EVM_CHAIN_ID="\$EVM_CHAIN_ID" \
    "\$REPO_DIR/chain/scripts/v2_testnet_bootstrap.sh" --profile "\$PROFILE"
  fi
else
  echo "Skip bootstrap: existing v2 home detected at \$V2_HOME"
  YNX_HOME="\$V2_HOME" "\$REPO_DIR/chain/scripts/v2_profile_apply.sh" "\$PROFILE"
fi

NODE_ID="\$("\$REPO_DIR/chain/ynxd" comet show-node-id --home "\$V2_HOME" 2>/dev/null || true)"
PUBLIC_SEED=""
if [[ -n "\$NODE_ID" ]]; then
  PUBLIC_SEED="\${NODE_ID}@$PUBLIC_HOST:\${P2P_PORT}"
fi

YNX_REPO_DIR="\$REPO_DIR" \
YNX_HOME="\$V2_HOME" \
YNX_CHAIN_ID="\$CHAIN_ID" \
YNX_P2P_PORT="\$P2P_PORT" \
YNX_RPC_PORT="\$RPC_PORT" \
YNX_REST_PORT="\$REST_PORT" \
YNX_EVM_PORT="\$EVM_PORT" \
FAUCET_PORT="\$FAUCET_PORT" \
INDEXER_PORT="\$INDEXER_PORT" \
EXPLORER_PORT="\$EXPLORER_PORT" \
FAUCET_KEYRING_DIR="\$V2_HOME" \
AI_GATEWAY_PORT="\$AI_PORT" \
WEB4_PORT="\$WEB4_PORT" \
YNX_PUBLIC_RPC="http://$PUBLIC_HOST:\$RPC_PORT" \
YNX_PUBLIC_EVM_RPC="http://$PUBLIC_HOST:\$EVM_PORT" \
YNX_PUBLIC_EVM_WS="ws://$PUBLIC_HOST:${YNX_EVM_WS_PORT:-38546}" \
YNX_PUBLIC_REST="http://$PUBLIC_HOST:\$REST_PORT" \
YNX_PUBLIC_GRPC="http://$PUBLIC_HOST:${YNX_GRPC_PORT:-39090}" \
YNX_PUBLIC_FAUCET="http://$PUBLIC_HOST:\$FAUCET_PORT" \
YNX_PUBLIC_INDEXER="http://$PUBLIC_HOST:\$INDEXER_PORT" \
YNX_PUBLIC_EXPLORER="http://$PUBLIC_HOST:\$EXPLORER_PORT" \
YNX_PUBLIC_AI_GATEWAY="http://$PUBLIC_HOST:\$AI_PORT" \
YNX_PUBLIC_WEB4_HUB="http://$PUBLIC_HOST:\$WEB4_PORT" \
YNX_DESCRIPTOR_URL="http://$PUBLIC_HOST:\$INDEXER_PORT/ynx/network-descriptor" \
YNX_SEEDS="\$PUBLIC_SEED" \
YNX_PERSISTENT_PEERS="\$PUBLIC_SEED" \
"\$REPO_DIR/chain/scripts/install_v2_stack_systemd.sh"

for _ in \$(seq 1 60); do
  rpc_ok=0
  evm_ok=0
  if curl -fsS --max-time 2 "http://127.0.0.1:\$RPC_PORT/status" >/dev/null 2>&1; then
    rpc_ok=1
  fi
  if curl -fsS --max-time 2 -H "content-type: application/json" \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
    "http://127.0.0.1:\$EVM_PORT" >/dev/null 2>&1; then
    evm_ok=1
  fi
  if [[ "\$rpc_ok" -eq 1 && "\$evm_ok" -eq 1 ]]; then
    break
  fi
  sleep 2
done

YNX_PUBLIC_HOST=127.0.0.1 \
YNX_CHAIN_ID="\$CHAIN_ID" \
YNX_RPC_PORT="\$RPC_PORT" \
YNX_EVM_PORT="\$EVM_PORT" \
YNX_REST_PORT="\$REST_PORT" \
YNX_FAUCET_PORT="\$FAUCET_PORT" \
YNX_INDEXER_PORT="\$INDEXER_PORT" \
YNX_EXPLORER_PORT="\$EXPLORER_PORT" \
YNX_AI_GATEWAY_PORT="\$AI_PORT" \
YNX_WEB4_PORT="\$WEB4_PORT" \
YNX_SMOKE_WRITE="\$SMOKE_WRITE_FLAG" \
"\$REPO_DIR/chain/scripts/v2_public_testnet_verify.sh"
EOF
