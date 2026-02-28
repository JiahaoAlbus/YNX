#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: v2_testnet_bootstrap.sh [--reset] [--start] [--profile <name>]

Bootstrap YNX v2 local testnet from the existing chain runtime.

Options:
  --reset            Delete existing v2 home before init
  --start            Start node after bootstrap
  --profile <name>   v2 runtime profile (default: web4-fast-regional)
                     values: web4-fast-regional, web4-global-stable

Environment defaults for v2:
  YNX_HOME=.testnet-v2
  YNX_CHAIN_ID=ynx_9102-1
  YNX_EVM_CHAIN_ID=9102
  YNX_MONIKER=ynx-v2-web4
  YNX_TESTNET_NO_BASE_FEE=0
EOF
}

RESET=0
START=0
PROFILE="web4-fast-regional"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
      ;;
    --start)
      START=1
      shift
      ;;
    --profile)
      PROFILE="${2:-}"
      if [[ -z "$PROFILE" ]]; then
        echo "--profile requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
EVM_CHAIN_ID="${YNX_EVM_CHAIN_ID:-9102}"
MONIKER="${YNX_MONIKER:-ynx-v2-web4}"
DENOM="${YNX_DENOM:-anyxt}"
TESTNET_NO_BASE_FEE="${YNX_TESTNET_NO_BASE_FEE:-0}"

BOOTSTRAP_ARGS=()
if [[ "$RESET" -eq 1 ]]; then
  BOOTSTRAP_ARGS+=(--reset)
fi

echo "Bootstrapping YNX v2..."
echo "  Home: $HOME_DIR"
echo "  Chain ID: $CHAIN_ID"
echo "  EVM Chain ID: $EVM_CHAIN_ID"
echo "  Profile: $PROFILE"

if [[ "$RESET" -eq 1 || ! -f "$HOME_DIR/config/genesis.json" ]]; then
  if [[ "${#BOOTSTRAP_ARGS[@]}" -gt 0 ]]; then
    YNX_HOME="$HOME_DIR" \
    YNX_CHAIN_ID="$CHAIN_ID" \
    YNX_EVM_CHAIN_ID="$EVM_CHAIN_ID" \
    YNX_MONIKER="$MONIKER" \
    YNX_TESTNET_NO_BASE_FEE="$TESTNET_NO_BASE_FEE" \
    "$ROOT_DIR/scripts/testnet_bootstrap.sh" "${BOOTSTRAP_ARGS[@]}"
  else
    YNX_HOME="$HOME_DIR" \
    YNX_CHAIN_ID="$CHAIN_ID" \
    YNX_EVM_CHAIN_ID="$EVM_CHAIN_ID" \
    YNX_MONIKER="$MONIKER" \
    YNX_TESTNET_NO_BASE_FEE="$TESTNET_NO_BASE_FEE" \
    "$ROOT_DIR/scripts/testnet_bootstrap.sh"
  fi
else
  echo "Existing v2 home detected, skipping base bootstrap."
fi

echo "Applying v2 runtime profile..."
YNX_HOME="$HOME_DIR" "$ROOT_DIR/scripts/v2_profile_apply.sh" "$PROFILE"

if [[ "$START" -eq 1 ]]; then
  echo "Starting YNX v2 node..."
  exec "$ROOT_DIR/ynxd" start \
    --home "$HOME_DIR" \
    --chain-id "$CHAIN_ID" \
    --minimum-gas-prices "0.000000007${DENOM}" \
    --json-rpc.enable \
    --json-rpc.address 0.0.0.0:8545 \
    --json-rpc.ws-address 0.0.0.0:8546 \
    --json-rpc.api eth,net,web3,txpool,ynx
fi

echo "YNX v2 bootstrap complete."
echo "Start command:"
echo "  $ROOT_DIR/ynxd start --home $HOME_DIR --chain-id $CHAIN_ID --minimum-gas-prices 0.000000007${DENOM}"
