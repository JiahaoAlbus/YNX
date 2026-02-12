#!/usr/bin/env bash

set -euo pipefail

RESET=0
FINALIZE=0
START=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
      ;;
    --finalize)
      FINALIZE=1
      shift
      ;;
    --start)
      START=1
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--reset] [--finalize] [--start]

Coordinator helper for multi-validator testnet genesis.

Options:
  --reset    Delete existing home dir before init
  --finalize Collect gentxs + validate genesis
  --start    Start the node after finalize

Environment:
  YNX_ENV_FILE             Path to .env (default: repo/.env or chain/.env)
  YNX_HOME                 Home directory (default: chain/.testnet)
  YNX_CHAIN_ID             Cosmos chain id (default: ynx_9002-1)
  YNX_EVM_CHAIN_ID         EVM chain id (EIP-155). Default: parsed from chain id or 9002
  YNX_DENOM                Gas denom (default: anyxt)
  YNX_MONIKER              Node moniker (default: ynx-testnet)
  YNX_KEYRING              Keyring backend (default: os)
  YNX_KEYALGO              Key algo (default: eth_secp256k1)
  YNX_DEPLOYER_KEY         Deployer key name (default: deployer)
  YNX_DEPLOYER_ADDRESS     Optional deployer address (0x hex or bech32). If set, no key is created.

  YNX_FOUNDER_ADDRESS      REQUIRED founder fee recipient (bech32)
  YNX_TEAM_BENEFICIARY     REQUIRED team vesting beneficiary (bech32 or 0x hex)
  YNX_COMMUNITY_RECIPIENT  REQUIRED community recipient (bech32 or 0x hex)
  YNX_TREASURY_ADDRESS     Optional treasury recipient (bech32)

  YNX_VALIDATOR_ACCOUNTS   Comma-separated list of addr:amount for validator accounts
  YNX_EXTRA_GENESIS_ACCOUNTS Comma-separated list of addr:amount to fund extra accounts
  YNX_PROMETHEUS           Enable CometBFT Prometheus metrics (default: 1)
  YNX_TELEMETRY            Enable Cosmos SDK telemetry (default: 1)
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

KEYRING="${YNX_KEYRING:-os}"
KEYALGO="${YNX_KEYALGO:-eth_secp256k1}"
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

require_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    echo "Missing required env: $name" >&2
    exit 1
  fi
}

require_env "YNX_FOUNDER_ADDRESS"
require_env "YNX_TEAM_BENEFICIARY"
require_env "YNX_COMMUNITY_RECIPIENT"

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

if [[ "$FINALIZE" -eq 0 ]]; then
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

  if [[ "${YNX_FAST_BLOCKS:-1}" == "1" ]]; then
    echo "Tuning CometBFT timeouts (target ~1s blocks)..."
    sed -i.bak 's/timeout_propose = "3s"/timeout_propose = "1s"/' "$CONFIG_TOML"
    sed -i.bak 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/' "$CONFIG_TOML"
    if grep -q '^timeout_vote = ' "$CONFIG_TOML"; then
      sed -i.bak 's/timeout_vote = "1s"/timeout_vote = "500ms"/' "$CONFIG_TOML"
      sed -i.bak 's/timeout_vote_delta = "500ms"/timeout_vote_delta = "200ms"/' "$CONFIG_TOML"
    else
      sed -i.bak 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/' "$CONFIG_TOML"
      sed -i.bak 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/' "$CONFIG_TOML"
      sed -i.bak 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/' "$CONFIG_TOML"
      sed -i.bak 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/' "$CONFIG_TOML"
    fi
    sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "1s"/' "$CONFIG_TOML"
  fi

  if [[ -n "${YNX_DEPLOYER_ADDRESS:-}" ]]; then
    DEPLOYER_ADDR="$YNX_DEPLOYER_ADDRESS"
  else
    if ! "$BIN" keys show "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
      echo "Creating deployer key: $DEPLOYER_KEY"
      "$BIN" keys add "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$HOME_DIR" >/dev/null
    fi
    DEPLOYER_ADDR="$("$BIN" keys show "$DEPLOYER_KEY" -a --keyring-backend "$KEYRING" --home "$HOME_DIR")"
  fi

  echo "Configuring YNX module genesis (system contracts + splits)..."
  GENESIS_ARGS=(
    genesis ynx set
    --home "$HOME_DIR"
    --ynx.system.enabled
    --ynx.system.deployer "$DEPLOYER_ADDR"
    --ynx.system.team-beneficiary "$YNX_TEAM_BENEFICIARY"
    --ynx.system.community-recipient "$YNX_COMMUNITY_RECIPIENT"
    --ynx.params.founder "$YNX_FOUNDER_ADDRESS"
  )
  if [[ -n "${YNX_TREASURY_ADDRESS:-}" ]]; then
    GENESIS_ARGS+=(--ynx.params.treasury "$YNX_TREASURY_ADDRESS")
  fi
  "$BIN" "${GENESIS_ARGS[@]}" >/dev/null

  echo "Base genesis prepared at: $HOME_DIR/config/genesis.json"
  echo "Next: gather validator gentx files, then run:"
  echo "  $0 --finalize"
  exit 0
fi

echo "Finalizing genesis..."

add_accounts_list() {
  local list="$1"
  [[ -z "$list" ]] && return 0
  IFS=',' read -ra entries <<< "$list"
  for entry in "${entries[@]}"; do
    entry="$(echo "$entry" | xargs)"
    [[ -z "$entry" ]] && continue
    if [[ "$entry" != *:* ]]; then
      echo "Invalid account entry (expected addr:amount): $entry" >&2
      exit 1
    fi
    local addr="${entry%%:*}"
    local amount="${entry#*:}"
    "$BIN" genesis add-genesis-account "$addr" "$amount" --home "$HOME_DIR" >/dev/null
  done
}

add_accounts_list "${YNX_VALIDATOR_ACCOUNTS:-}"
add_accounts_list "${YNX_EXTRA_GENESIS_ACCOUNTS:-}"

GENTX_DIR="${YNX_GENTX_DIR:-$HOME_DIR/config/gentx}"
echo "Collecting gentxs from: $GENTX_DIR"
"$BIN" genesis collect-gentxs --home "$HOME_DIR" --gentx-dir "$GENTX_DIR" >/dev/null

echo "Validating genesis..."
"$BIN" genesis validate --home "$HOME_DIR" >/dev/null

if command -v shasum >/dev/null 2>&1; then
  echo "Genesis SHA256:"
  shasum -a 256 "$HOME_DIR/config/genesis.json"
fi

if [[ "$START" -eq 1 ]]; then
  echo "Starting node..."
  exec "$BIN" start --home "$HOME_DIR" --minimum-gas-prices "0$DENOM"
fi

echo "Genesis finalized:"
echo "  $HOME_DIR/config/genesis.json"
