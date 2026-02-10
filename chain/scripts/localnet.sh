#!/usr/bin/env bash

set -euo pipefail

RESET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--reset]

Runs a single-node local devnet.

Options:
  --reset   Delete existing localnet home before init
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
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.localnet}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9001-1}"
DENOM="${YNX_DENOM:-anyxt}"

KEYRING="${YNX_KEYRING:-test}"
KEYALGO="${YNX_KEYALGO:-eth_secp256k1}"
VAL_KEY="${YNX_VAL_KEY:-validator}"
MONIKER="${YNX_MONIKER:-localtestnet}"

BIN="$ROOT_DIR/ynxd"

mkdir -p "$ROOT_DIR"

echo "Building ynxd..."
(
  cd "$ROOT_DIR"
  go build -o "$BIN" ./cmd/ynxd
)

if [[ "$RESET" -eq 1 ]]; then
  echo "Resetting home dir: $HOME_DIR"
  rm -rf "$HOME_DIR"
fi

echo "Initializing chain..."
"$BIN" init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null

echo "Configuring client defaults..."
"$BIN" config set client chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null
"$BIN" config set client keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null

if ! "$BIN" keys show "$VAL_KEY" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  echo "Creating validator key: $VAL_KEY"
  "$BIN" keys add "$VAL_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
fi

VAL_ADDR="$("$BIN" keys show "$VAL_KEY" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"

echo "Funding validator account..."
"$BIN" genesis add-genesis-account "$VAL_ADDR" "1000000000000000000000000$DENOM" --home "$HOME_DIR" >/dev/null

echo "Generating gentx..."
"$BIN" genesis gentx "$VAL_KEY" "1000000000000000000000$DENOM" --chain-id "$CHAIN_ID" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null

echo "Collecting gentxs..."
"$BIN" genesis collect-gentxs --home "$HOME_DIR" >/dev/null

echo "Starting node..."
echo "  JSON-RPC: http://127.0.0.1:8545"
echo "  Home:     $HOME_DIR"
echo "  Chain ID: $CHAIN_ID"

"$BIN" start --home "$HOME_DIR" --minimum-gas-prices "0$DENOM"

