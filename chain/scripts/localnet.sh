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
CGO_ENABLED_VALUE="${YNX_CGO_ENABLED:-0}"

KEYRING="${YNX_KEYRING:-test}"
KEYALGO="${YNX_KEYALGO:-eth_secp256k1}"
VAL_KEY="${YNX_VAL_KEY:-validator}"
DEPLOYER_KEY="${YNX_DEPLOYER_KEY:-deployer}"
MONIKER="${YNX_MONIKER:-localtestnet}"
MNEMONIC="${YNX_MNEMONIC:-test test test test test test test test test test test junk}"

DEV_FAST_GOV="${YNX_DEV_FAST_GOV:-0}"
DEV_VOTING_DELAY_BLOCKS="${YNX_DEV_VOTING_DELAY_BLOCKS:-1}"
DEV_VOTING_PERIOD_BLOCKS="${YNX_DEV_VOTING_PERIOD_BLOCKS:-60}"
DEV_TIMELOCK_DELAY_SECONDS="${YNX_DEV_TIMELOCK_DELAY_SECONDS:-30}"
DEV_PROPOSAL_THRESHOLD="${YNX_DEV_PROPOSAL_THRESHOLD:-1000000000000000000}" # 1 NYXT (1e18)
DEV_PROPOSAL_DEPOSIT="${YNX_DEV_PROPOSAL_DEPOSIT:-1000000000000000000}"     # 1 NYXT (1e18)
DEV_QUORUM_PERCENT="${YNX_DEV_QUORUM_PERCENT:-1}"

BIN="$ROOT_DIR/ynxd"

mkdir -p "$ROOT_DIR"

echo "Building ynxd..."
(
  cd "$ROOT_DIR"
  CGO_ENABLED="$CGO_ENABLED_VALUE" go build -o "$BIN" ./cmd/ynxd
)

if [[ "$RESET" -eq 1 ]]; then
  echo "Resetting home dir: $HOME_DIR"
  rm -rf "$HOME_DIR"
fi

echo "Initializing chain..."
"$BIN" init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

echo "Tuning CometBFT for fast local blocks..."
# Target ~1s blocks. These settings are for local development only.
sed -i.bak 's/timeout_propose = "3s"/timeout_propose = "1s"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "1s"/' "$CONFIG_TOML"
sed -i.bak 's/skip_timeout_commit = false/skip_timeout_commit = true/' "$CONFIG_TOML"

echo "Enabling app-side EVM mempool..."
sed -i.bak 's/^max-txs = -1$/max-txs = 0/' "$APP_TOML"

echo "Configuring client defaults..."
"$BIN" config set client chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null
"$BIN" config set client keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null

if ! "$BIN" keys show "$VAL_KEY" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  echo "Creating validator key: $VAL_KEY"
  echo "Using mnemonic:"
  echo "  $MNEMONIC"
  echo "$MNEMONIC" | "$BIN" keys add "$VAL_KEY" --recover --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
fi

if ! "$BIN" keys show "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  echo "Creating deployer key: $DEPLOYER_KEY"
  "$BIN" keys add "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
fi

VAL_ADDR="$("$BIN" keys show "$VAL_KEY" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"
DEPLOYER_ADDR="$("$BIN" keys show "$DEPLOYER_KEY" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"

PRECONFIRM_KEY_PATH="$HOME_DIR/config/ynx_preconfirm.key"
if [[ ! -f "$PRECONFIRM_KEY_PATH" ]]; then
  echo "Generating preconfirm signer key..."
  "$BIN" preconfirm keygen --home "$HOME_DIR" --out "$PRECONFIRM_KEY_PATH" >/dev/null
fi

echo "Configuring YNX module genesis..."
FAST_GOV_FLAGS=()
if [[ "$DEV_FAST_GOV" == "1" ]]; then
  echo "Enabling fast governance mode (dev-only)..."
  FAST_GOV_FLAGS+=(
    --ynx.system.voting-delay-blocks "$DEV_VOTING_DELAY_BLOCKS"
    --ynx.system.voting-period-blocks "$DEV_VOTING_PERIOD_BLOCKS"
    --ynx.system.proposal-threshold "$DEV_PROPOSAL_THRESHOLD"
    --ynx.system.proposal-deposit "$DEV_PROPOSAL_DEPOSIT"
    --ynx.system.quorum-percent "$DEV_QUORUM_PERCENT"
    --ynx.system.timelock-delay-seconds "$DEV_TIMELOCK_DELAY_SECONDS"
  )
fi
"$BIN" genesis ynx set \
  --home "$HOME_DIR" \
  --ynx.system.enabled \
  --ynx.system.deployer "$DEPLOYER_ADDR" \
  --ynx.system.team-beneficiary "$VAL_ADDR" \
  --ynx.system.community-recipient "$VAL_ADDR" \
  "${FAST_GOV_FLAGS[@]}" \
  --ynx.params.founder "$VAL_ADDR" >/dev/null

echo "Funding validator account..."
"$BIN" genesis add-genesis-account "$VAL_ADDR" "1000000000000000000000000$DENOM" --home "$HOME_DIR" >/dev/null

echo "Funding deployer account..."
"$BIN" genesis add-genesis-account "$DEPLOYER_ADDR" "1000000000000000000000000$DENOM" --home "$HOME_DIR" >/dev/null

echo "Generating gentx..."
"$BIN" genesis gentx "$VAL_KEY" "1000000000000000000000$DENOM" --chain-id "$CHAIN_ID" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null

echo "Collecting gentxs..."
"$BIN" genesis collect-gentxs --home "$HOME_DIR" >/dev/null

echo "Starting node..."
echo "  JSON-RPC: http://127.0.0.1:8545"
echo "  Home:     $HOME_DIR"
echo "  Chain ID: $CHAIN_ID"

YNX_PRECONFIRM_ENABLED=1 \
YNX_PRECONFIRM_KEY_PATH="$PRECONFIRM_KEY_PATH" \
"$BIN" start \
  --home "$HOME_DIR" \
  --minimum-gas-prices "0$DENOM" \
  --json-rpc.enable \
  --json-rpc.api "eth,net,web3,ynx" \
  --json-rpc.enable-indexer
