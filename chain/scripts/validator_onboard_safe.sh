#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: validator_onboard_safe.sh [--no-create-key]

Safely onboard a validator by enforcing:
1) local node must fully sync first
2) validator account must be funded
3) create-validator tx is sent only after 1 and 2 pass

Environment:
  YNX_HOME               Node home (default: ~/.ynx-testnet)
  YNX_CHAIN_ID           Chain ID (default: ynx_9002-1)
  YNX_DENOM              Denom (default: anyxt)
  YNX_KEY_NAME           Key name (default: validator)
  YNX_KEYRING            Keyring backend (default: test)
  YNX_KEY_TYPE           Key type (default: eth_secp256k1)
  YNX_MONIKER            Validator moniker (default: ynx-validator)
  YNX_NODE_RPC           Coordinator RPC for tx/query (default: http://43.134.23.58:26657)
  YNX_LOCAL_RPC          Local RPC for sync check (default: http://127.0.0.1:26657)
  YNX_SELF_DELEGATION    Self delegation in base denom (default: 1000000000000000000)
  YNX_MIN_BALANCE        Minimum required balance in base denom (default: 1000000000000000000)
  YNX_GAS_PRICES         Gas prices (default: 0.000001anyxt)
  YNX_GAS_ADJUSTMENT     Gas adjustment (default: 1.3)
  YNX_SYNC_TIMEOUT_SEC   Max wait for local sync (default: 7200)
  YNX_BONDED_TIMEOUT_SEC Max wait for BONDED status (default: 1800)
  YNX_POLL_INTERVAL_SEC  Poll interval (default: 10)
  YNX_VALIDATOR_JSON     Output validator.json path (default: /tmp/ynx_validator.json)

Examples:
  YNX_HOME=/root/.ynx-testnet2 YNX_KEY_NAME=validator2 ./scripts/validator_onboard_safe.sh
  YNX_KEYRING=os YNX_NODE_RPC=http://127.0.0.1:26657 ./scripts/validator_onboard_safe.sh --no-create-key
EOF
}

NO_CREATE_KEY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-create-key)
      NO_CREATE_KEY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

ge_bigint() {
  local a="${1#0}"
  local b="${2#0}"
  [[ -z "$a" ]] && a="0"
  [[ -z "$b" ]] && b="0"
  if (( ${#a} > ${#b} )); then
    return 0
  fi
  if (( ${#a} < ${#b} )); then
    return 1
  fi
  [[ "$a" > "$b" || "$a" == "$b" ]]
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT_DIR/ynxd"
HOME_DIR="${YNX_HOME:-$HOME/.ynx-testnet}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9002-1}"
DENOM="${YNX_DENOM:-anyxt}"
KEY_NAME="${YNX_KEY_NAME:-validator}"
KEYRING="${YNX_KEYRING:-test}"
KEY_TYPE="${YNX_KEY_TYPE:-eth_secp256k1}"
MONIKER="${YNX_MONIKER:-ynx-validator}"
NODE_RPC="${YNX_NODE_RPC:-http://43.134.23.58:26657}"
LOCAL_RPC="${YNX_LOCAL_RPC:-http://127.0.0.1:26657}"
SELF_DELEGATION="${YNX_SELF_DELEGATION:-1000000000000000000}"
MIN_BALANCE="${YNX_MIN_BALANCE:-1000000000000000000}"
GAS_PRICES="${YNX_GAS_PRICES:-0.000001anyxt}"
GAS_ADJUSTMENT="${YNX_GAS_ADJUSTMENT:-1.3}"
SYNC_TIMEOUT_SEC="${YNX_SYNC_TIMEOUT_SEC:-7200}"
BONDED_TIMEOUT_SEC="${YNX_BONDED_TIMEOUT_SEC:-1800}"
POLL_INTERVAL_SEC="${YNX_POLL_INTERVAL_SEC:-10}"
VALIDATOR_JSON="${YNX_VALIDATOR_JSON:-/tmp/ynx_validator.json}"

require_cmd jq
require_cmd curl

if [[ ! -x "$BIN" ]]; then
  echo "ynxd not found at: $BIN" >&2
  exit 1
fi

echo "[1/6] Checking local sync status..."
start_ts="$(date +%s)"
while true; do
  status_json="$(curl -s "$LOCAL_RPC/status" || true)"
  catching_up="$(echo "$status_json" | jq -r '.result.sync_info.catching_up // "true"' 2>/dev/null || echo "true")"
  height="$(echo "$status_json" | jq -r '.result.sync_info.latest_block_height // "0"' 2>/dev/null || echo "0")"
  echo "local_height=$height catching_up=$catching_up"

  if [[ "$catching_up" == "false" && "$height" != "0" ]]; then
    break
  fi

  now_ts="$(date +%s)"
  if (( now_ts - start_ts > SYNC_TIMEOUT_SEC )); then
    echo "Timeout: local node not fully synced within ${SYNC_TIMEOUT_SEC}s" >&2
    exit 1
  fi
  sleep "$POLL_INTERVAL_SEC"
done

echo "[2/6] Ensuring validator key exists..."
if ! "$BIN" keys show "$KEY_NAME" --keyring-backend "$KEYRING" --home "$HOME_DIR" >/dev/null 2>&1; then
  if [[ "$NO_CREATE_KEY" -eq 1 ]]; then
    echo "Key missing: $KEY_NAME (and --no-create-key was set)" >&2
    exit 1
  fi
  "$BIN" keys add "$KEY_NAME" --keyring-backend "$KEYRING" --key-type "$KEY_TYPE" --home "$HOME_DIR"
fi

VAL_ACC="$("$BIN" keys show "$KEY_NAME" --keyring-backend "$KEYRING" --home "$HOME_DIR" --bech acc -a)"
VAL_OPER="$("$BIN" keys show "$KEY_NAME" --keyring-backend "$KEYRING" --home "$HOME_DIR" --bech val -a)"
CONS_PUB="$("$BIN" comet show-validator --home "$HOME_DIR")"

echo "[3/6] Checking account balance on coordinator RPC..."
balance="$("$BIN" query bank balances "$VAL_ACC" --node "$NODE_RPC" -o json | jq -r --arg d "$DENOM" '.balances[]? | select(.denom==$d) | .amount' | head -n1)"
[[ -z "$balance" ]] && balance="0"
echo "balance_${DENOM}=$balance required_min=$MIN_BALANCE"
if ! ge_bigint "$balance" "$MIN_BALANCE"; then
  echo "Insufficient balance. Fund $VAL_ACC first, then rerun." >&2
  exit 1
fi

echo "[4/6] Building validator tx json..."
cat >"$VALIDATOR_JSON" <<EOF
{
  "pubkey": $CONS_PUB,
  "amount": "${SELF_DELEGATION}${DENOM}",
  "moniker": "${MONIKER}",
  "identity": "",
  "website": "",
  "security": "",
  "details": "YNX validator onboarded via safe flow",
  "commission-rate": "0.10",
  "commission-max-rate": "0.20",
  "commission-max-change-rate": "0.01",
  "min-self-delegation": "1"
}
EOF

echo "[5/6] Sending create-validator tx..."
tx_out="$("$BIN" tx staking create-validator "$VALIDATOR_JSON" \
  --chain-id "$CHAIN_ID" \
  --node "$NODE_RPC" \
  --from "$KEY_NAME" \
  --home "$HOME_DIR" \
  --keyring-backend "$KEYRING" \
  --gas auto \
  --gas-adjustment "$GAS_ADJUSTMENT" \
  --gas-prices "$GAS_PRICES" \
  --yes \
  --output json)"
echo "$tx_out" | jq -r '.txhash, .code, .raw_log'

echo "[6/6] Waiting validator to become BONDED..."
start_ts="$(date +%s)"
while true; do
  v_json="$("$BIN" query staking validator "$VAL_OPER" --node "$NODE_RPC" -o json 2>/dev/null || true)"
  status="$(echo "$v_json" | jq -r '.validator.status // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")"
  jailed="$(echo "$v_json" | jq -r '.validator.jailed // false' 2>/dev/null || echo "false")"
  echo "validator_status=$status jailed=$jailed"

  if [[ "$status" == "BOND_STATUS_BONDED" && "$jailed" != "true" ]]; then
    echo "SUCCESS: validator is BONDED."
    exit 0
  fi

  now_ts="$(date +%s)"
  if (( now_ts - start_ts > BONDED_TIMEOUT_SEC )); then
    echo "Timeout: validator did not become BONDED in ${BONDED_TIMEOUT_SEC}s" >&2
    exit 1
  fi
  sleep "$POLL_INTERVAL_SEC"
done
