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

Validator helper for generating a gentx for the YNX testnet.

Options:
  --reset   Delete existing home dir before init

Environment:
  YNX_HOME          Home directory (default: chain/.validator)
  YNX_CHAIN_ID      Cosmos chain id (required)
  YNX_DENOM         Gas denom (default: anyxt)
  YNX_MONIKER       Node moniker (default: ynx-validator)
  YNX_KEY_NAME      Key name (default: validator)
  YNX_KEYRING       Keyring backend (default: os)
  YNX_KEYALGO       Key algo (default: eth_secp256k1)
  YNX_SELF_DELEGATION Amount for gentx (default: 1000000000000000000000)
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
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.validator}"
CHAIN_ID="${YNX_CHAIN_ID:-}"
DENOM="${YNX_DENOM:-anyxt}"
MONIKER="${YNX_MONIKER:-ynx-validator}"
KEY_NAME="${YNX_KEY_NAME:-validator}"
KEYRING="${YNX_KEYRING:-os}"
KEYALGO="${YNX_KEYALGO:-eth_secp256k1}"
SELF_DELEGATION="${YNX_SELF_DELEGATION:-1000000000000000000000}"

if [[ -z "$CHAIN_ID" ]]; then
  echo "Missing YNX_CHAIN_ID" >&2
  exit 1
fi

BIN="$ROOT_DIR/ynxd"
if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (
    cd "$ROOT_DIR"
    CGO_ENABLED="${YNX_CGO_ENABLED:-0}" go build -o "$BIN" ./cmd/ynxd
  )
fi

if [[ "$RESET" -eq 1 ]]; then
  echo "Resetting home dir: $HOME_DIR"
  rm -rf "$HOME_DIR"
fi

echo "Initializing node..."
"$BIN" init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null

echo "Configuring client defaults..."
"$BIN" config set client chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null
"$BIN" config set client keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null

if ! "$BIN" keys show "$KEY_NAME" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  echo "Creating validator key: $KEY_NAME"
  "$BIN" keys add "$KEY_NAME" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
fi

VAL_ADDR="$("$BIN" keys show "$KEY_NAME" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"
VALOPER_ADDR="$("$BIN" keys show "$KEY_NAME" -a --bech val --keyring-backend "$KEYRING" --home "$HOME_DIR")"

echo "Generating gentx..."
"$BIN" genesis gentx "$KEY_NAME" "${SELF_DELEGATION}${DENOM}" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend "$KEYRING" \
  --home "$HOME_DIR" >/dev/null

GENTX_PATHS=("$HOME_DIR"/config/gentx/gentx-*.json)

echo
echo "Validator info:"
echo "  Account:  $VAL_ADDR"
echo "  Valoper:  $VALOPER_ADDR"
echo "  Gentx:    ${GENTX_PATHS[*]}"

if node_id="$("$BIN" comet show-node-id --home "$HOME_DIR" 2>/dev/null)"; then
  echo "  Node ID:  $node_id"
  echo "  P2P:      ${node_id}@<ip>:26656"
fi

echo
echo "Send the gentx file + node-id to the testnet coordinator."
