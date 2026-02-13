#!/usr/bin/env bash

set -euo pipefail

RESET=0
START=0
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
    -h|--help)
      cat <<EOF
Usage: $0 [--reset] [--start]

Bootstraps a single-validator YNX testnet home directory.

Options:
  --reset   Delete existing home dir before init
  --start   Start the node after init

Environment:
  YNX_HOME                 Home directory (default: chain/.testnet)
  YNX_CHAIN_ID             Cosmos chain id (default: ynx_9002-1)
  YNX_EVM_CHAIN_ID         EVM chain id (EIP-155) (default: parsed from YNX_CHAIN_ID, else 9002)
  YNX_DENOM                Gas denom (default: anyxt)
  YNX_MONIKER              Node moniker (default: ynx-testnet)
  YNX_KEYRING              Keyring backend (default: test)
  YNX_KEYALGO              Key algo (default: eth_secp256k1)
  YNX_VAL_KEY              Validator key name (default: validator)
  YNX_DEPLOYER_KEY         Deployer key name (default: deployer)
  YNX_COMMUNITY_RECIPIENT  Optional community recipient address (0x hex or bech32)
  YNX_FOUNDER_ADDRESS      Optional founder fee recipient (bech32). Defaults to validator address.
  YNX_TEAM_BENEFICIARY     Optional team beneficiary (bech32 or 0x hex). Defaults to validator address.
  YNX_TREASURY_ADDRESS     Optional treasury recipient (bech32)
  YNX_PROMETHEUS           Enable CometBFT Prometheus metrics (default: 1)
  YNX_TELEMETRY            Enable Cosmos SDK telemetry (default: 1)

Notes:
  - The default keyring backend is "test" for non-interactive bootstrap.
    Do NOT use it for real funds on production networks.
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
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9002-1}"
DENOM="${YNX_DENOM:-anyxt}"

KEYRING="${YNX_KEYRING:-test}"
KEYALGO="${YNX_KEYALGO:-eth_secp256k1}"
VAL_KEY="${YNX_VAL_KEY:-validator}"
DEPLOYER_KEY="${YNX_DEPLOYER_KEY:-deployer}"
MONIKER="${YNX_MONIKER:-ynx-testnet}"
PROMETHEUS_ENABLED="${YNX_PROMETHEUS:-1}"
TELEMETRY_ENABLED="${YNX_TELEMETRY:-1}"

ENV_FILE="${YNX_ENV_FILE:-}"
if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "$ROOT_DIR/../.env" ]]; then
    ENV_FILE="$ROOT_DIR/../.env"
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

EVM_CHAIN_ID="${YNX_EVM_CHAIN_ID:-}"
if [[ -z "$EVM_CHAIN_ID" ]]; then
  if [[ "$CHAIN_ID" =~ ^ynx_([0-9]+)- ]]; then
    EVM_CHAIN_ID="${BASH_REMATCH[1]}"
  else
    EVM_CHAIN_ID="9002"
  fi
fi

BIN="$ROOT_DIR/ynxd"

mkdir -p "$ROOT_DIR"

echo "Building ynxd..."
(
  cd "$ROOT_DIR"
  CGO_ENABLED="${YNX_CGO_ENABLED:-0}" go build -o "$BIN" ./cmd/ynxd
)

if [[ "$RESET" -eq 1 ]]; then
  echo "Resetting home dir: $HOME_DIR"
  rm -rf "$HOME_DIR"
fi

echo "Initializing chain..."
"$BIN" init "$MONIKER" --chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

echo "Configuring client defaults..."
"$BIN" config set client chain-id "$CHAIN_ID" --home "$HOME_DIR" >/dev/null
"$BIN" config set client keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null

echo "Setting EVM chain id: $EVM_CHAIN_ID"
sed -i.bak -E "s/^evm-chain-id = .*/evm-chain-id = ${EVM_CHAIN_ID}/" "$APP_TOML"

if [[ "$PROMETHEUS_ENABLED" == "1" ]]; then
  sed -i.bak -E "s/^prometheus = .*/prometheus = true/" "$CONFIG_TOML" || true
else
  sed -i.bak -E "s/^prometheus = .*/prometheus = false/" "$CONFIG_TOML" || true
fi
sed -i.bak -E "s/^prometheus_listen_addr = .*/prometheus_listen_addr = \":26660\"/" "$CONFIG_TOML" || true

if [[ "$TELEMETRY_ENABLED" == "1" ]]; then
  sed -i.bak -E '/^\[telemetry\]$/,/^\[/ s/^enabled = .*/enabled = true/' "$APP_TOML" || true
else
  sed -i.bak -E '/^\[telemetry\]$/,/^\[/ s/^enabled = .*/enabled = false/' "$APP_TOML" || true
fi

sed -i.bak -E '/^\[json-rpc\]$/,/^\[/ s/^enable = .*/enable = true/' "$APP_TOML" || true
sed -i.bak -E "s#^address = \"127.0.0.1:8545\"#address = \"0.0.0.0:8545\"#" "$APP_TOML" || true
sed -i.bak -E "s#^ws-address = \"127.0.0.1:8546\"#ws-address = \"0.0.0.0:8546\"#" "$APP_TOML" || true

echo "Tuning CometBFT timeouts (target ~1s blocks)..."
sed -i.bak 's/timeout_propose = "3s"/timeout_propose = "1s"/' "$CONFIG_TOML"
sed -i.bak 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/' "$CONFIG_TOML"
if grep -q '^timeout_vote = ' "$CONFIG_TOML"; then
  # CometBFT v2.x
  sed -i.bak 's/timeout_vote = "1s"/timeout_vote = "500ms"/' "$CONFIG_TOML"
  sed -i.bak 's/timeout_vote_delta = "500ms"/timeout_vote_delta = "200ms"/' "$CONFIG_TOML"
else
  # CometBFT v0.38.x
  sed -i.bak 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/' "$CONFIG_TOML"
  sed -i.bak 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/' "$CONFIG_TOML"
  sed -i.bak 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/' "$CONFIG_TOML"
  sed -i.bak 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/' "$CONFIG_TOML"
fi
sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "1s"/' "$CONFIG_TOML"

echo "Creating keys (if missing)..."
if ! "$BIN" keys show "$VAL_KEY" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  "$BIN" keys add "$VAL_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
fi
if ! "$BIN" keys show "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  "$BIN" keys add "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
fi

VAL_ADDR="$("$BIN" keys show "$VAL_KEY" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"
DEPLOYER_ADDR="$("$BIN" keys show "$DEPLOYER_KEY" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"
FOUNDER_ADDR="${YNX_FOUNDER_ADDRESS:-$VAL_ADDR}"
TEAM_BENEFICIARY_ADDR="${YNX_TEAM_BENEFICIARY:-$VAL_ADDR}"
COMMUNITY_RECIPIENT="${YNX_COMMUNITY_RECIPIENT:-}"
TREASURY_ADDR="${YNX_TREASURY_ADDRESS:-}"

echo "Configuring YNX module genesis (system contracts + splits)..."
GENESIS_ARGS=(
  genesis ynx set
  --home "$HOME_DIR"
  --ynx.system.enabled
  --ynx.system.deployer "$DEPLOYER_ADDR"
  --ynx.system.team-beneficiary "$TEAM_BENEFICIARY_ADDR"
  --ynx.params.founder "$FOUNDER_ADDR"
)
if [[ -n "$COMMUNITY_RECIPIENT" ]]; then
  GENESIS_ARGS+=(--ynx.system.community-recipient "$COMMUNITY_RECIPIENT")
fi
if [[ -n "$TREASURY_ADDR" ]]; then
  GENESIS_ARGS+=(--ynx.params.treasury "$TREASURY_ADDR")
fi
"$BIN" "${GENESIS_ARGS[@]}" >/dev/null

echo "Funding accounts..."
"$BIN" genesis add-genesis-account "$VAL_ADDR" "1000000000000000000000000$DENOM" --home "$HOME_DIR" >/dev/null
"$BIN" genesis add-genesis-account "$DEPLOYER_ADDR" "1000000000000000000000000$DENOM" --home "$HOME_DIR" >/dev/null
if [[ "$FOUNDER_ADDR" != "$VAL_ADDR" && "$FOUNDER_ADDR" != "$DEPLOYER_ADDR" ]]; then
  "$BIN" genesis add-genesis-account "$FOUNDER_ADDR" "1000000000000000000000000$DENOM" --home "$HOME_DIR" >/dev/null
fi

echo "Generating gentx..."
"$BIN" genesis gentx "$VAL_KEY" "1000000000000000000000$DENOM" \
  --chain-id "$CHAIN_ID" \
  --keyring-backend "$KEYRING" \
  --home "$HOME_DIR" >/dev/null

echo "Collecting gentxs..."
"$BIN" genesis collect-gentxs --home "$HOME_DIR" >/dev/null

echo "Validating genesis..."
"$BIN" genesis validate --home "$HOME_DIR" >/dev/null

echo
echo "Bootstrap complete:"
echo "  Home:     $HOME_DIR"
echo "  Chain ID: $CHAIN_ID"
echo "  EVM ID:   $EVM_CHAIN_ID"
echo "  Val:      $VAL_ADDR"
echo "  Deployer: $DEPLOYER_ADDR"
echo "  Founder:  $FOUNDER_ADDR"
echo
echo "Next steps:"
echo "  - Configure seeds/persistent peers in:"
echo "      $CONFIG_TOML"
echo "  - Start the node:"
echo "      $BIN start --home \"$HOME_DIR\" --minimum-gas-prices \"0$DENOM\""

if [[ "$START" -eq 1 ]]; then
  echo
  echo "Starting node..."
  exec "$BIN" start --home "$HOME_DIR" --minimum-gas-prices "0$DENOM"
fi
