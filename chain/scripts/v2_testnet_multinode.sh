#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_testnet_multinode.sh [--reset] [--start] [--validators N] [--max]

Bootstrap YNX v2 multi-validator testnet on a single machine.
This is for local scale simulation before public rollout.

It delegates to testnet_multinode.sh with v2-safe defaults.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export YNX_HOME_BASE="${YNX_HOME_BASE:-$ROOT_DIR/.testnet-v2-multi}"
export YNX_CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
export YNX_EVM_CHAIN_ID="${YNX_EVM_CHAIN_ID:-9102}"
export YNX_MONIKER_PREFIX="${YNX_MONIKER_PREFIX:-ynx-v2}"
export YNX_JSONRPC_NODE="${YNX_JSONRPC_NODE:-0}"
export YNX_FAST_BLOCKS="${YNX_FAST_BLOCKS:-1}"
export YNX_DISABLE_NON_RPC="${YNX_DISABLE_NON_RPC:-1}"
export YNX_PROMETHEUS="${YNX_PROMETHEUS:-1}"
export YNX_TELEMETRY="${YNX_TELEMETRY:-1}"

export YNX_P2P_PORT_BASE="${YNX_P2P_PORT_BASE:-36656}"
export YNX_RPC_PORT_BASE="${YNX_RPC_PORT_BASE:-36657}"
export YNX_APP_PORT_BASE="${YNX_APP_PORT_BASE:-36658}"
export YNX_PROM_PORT_BASE="${YNX_PROM_PORT_BASE:-36660}"
export YNX_PPROF_PORT_BASE="${YNX_PPROF_PORT_BASE:-36661}"
export YNX_API_PORT_BASE="${YNX_API_PORT_BASE:-31317}"
export YNX_GRPC_PORT_BASE="${YNX_GRPC_PORT_BASE:-39090}"
export YNX_GRPC_WEB_PORT_BASE="${YNX_GRPC_WEB_PORT_BASE:-39091}"
export YNX_JSONRPC_PORT_BASE="${YNX_JSONRPC_PORT_BASE:-38545}"
export YNX_JSONRPC_WS_PORT_BASE="${YNX_JSONRPC_WS_PORT_BASE:-38546}"
export YNX_PORT_OFFSET="${YNX_PORT_OFFSET:-20}"

exec "$ROOT_DIR/scripts/testnet_multinode.sh" "$@"
