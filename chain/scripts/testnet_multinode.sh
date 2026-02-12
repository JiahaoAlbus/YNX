#!/usr/bin/env bash

set -euo pipefail

RESET=0
START=0
AUTO=0
VALIDATOR_COUNT="${YNX_VALIDATOR_COUNT:-4}"
VALIDATOR_COUNT_SET=0
if [[ -n "${YNX_VALIDATOR_COUNT+x}" ]]; then
  VALIDATOR_COUNT_SET=1
fi
JSONRPC_NODE="${YNX_JSONRPC_NODE:-0}"

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
    --validators|-n)
      VALIDATOR_COUNT="${2:-}"
      VALIDATOR_COUNT_SET=1
      shift 2
      ;;
    --max|--auto)
      AUTO=1
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--reset] [--start] [--validators N]

Bootstraps a single-machine multi-validator YNX testnet.

Options:
  --reset        Delete existing home dir before init
  --start        Start all validators after init
  --validators   Number of validators (default: 4)
  --max          Auto-calc max validators for this machine

Environment:
  YNX_ENV_FILE             Path to .env (default: repo/.env or chain/.env)
  YNX_HOME_BASE            Base home directory (default: chain/.testnet-multi)
  YNX_CHAIN_ID             Cosmos chain id (default: ynx_9002-1)
  YNX_EVM_CHAIN_ID         EVM chain id (EIP-155). Default: parsed from chain id or 9002
  YNX_DENOM                Gas denom (default: anyxt)
  YNX_MONIKER_PREFIX       Moniker prefix (default: ynx-testnet)
  YNX_KEYRING              Keyring backend (default: test)
  YNX_KEYALGO              Key algo (default: eth_secp256k1)
  YNX_DEPLOYER_KEY         Deployer key name (default: deployer)
  YNX_DEPLOYER_ADDRESS     Optional deployer address (0x... or bech32). If set, no key is created.

  YNX_FOUNDER_ADDRESS      Optional founder fee recipient (bech32). Defaults to node0 validator address.
  YNX_TEAM_BENEFICIARY     Optional team beneficiary (bech32 or 0x). Defaults to node0 validator address.
  YNX_COMMUNITY_RECIPIENT  Optional community recipient (bech32 or 0x). Defaults to node0 validator address.
  YNX_TREASURY_ADDRESS     Optional treasury recipient (bech32)

  YNX_GENESIS_BALANCE      Per-account genesis balance (default: 1000000000000000000000000)
  YNX_SELF_DELEGATION      Validator self-delegation (default: 1000000000000000000000)

  YNX_FAST_BLOCKS          Tune CometBFT timeouts for fast blocks (default: 1)
  YNX_JSONRPC_NODE         Index of the node that runs JSON-RPC (default: 0)
  YNX_DISABLE_NON_RPC      Disable API/gRPC/JSON-RPC on non-JSON nodes (default: 1)

Autoscale tuning (used with --max):
  YNX_PER_NODE_MB          Estimated RAM per node (default: 600)
  YNX_RESERVED_MB          Reserved RAM for OS/other (default: 1500)
  YNX_CPU_FACTOR           Validators per CPU core (default: 4)
  YNX_FD_PER_NODE          File descriptors per node (default: 256)
  YNX_MAX_VALIDATORS_CAP   Optional hard cap on validators

Port bases (overridable):
  YNX_P2P_PORT_BASE        (default: 26656)
  YNX_RPC_PORT_BASE        (default: 26657)
  YNX_APP_PORT_BASE        (default: 26658)
  YNX_PROM_PORT_BASE       (default: 26660)
  YNX_PPROF_PORT_BASE      (default: 6060)
  YNX_API_PORT_BASE        (default: 1317)
  YNX_GRPC_PORT_BASE       (default: 9090)
  YNX_GRPC_WEB_PORT_BASE   (default: 9091)
  YNX_JSONRPC_PORT_BASE    (default: 8545)
  YNX_JSONRPC_WS_PORT_BASE (default: 8546)
  YNX_PORT_OFFSET          (default: 10)

Notes:
  - This is a local simulation of multi-validator consensus.
  - It is NOT equivalent to real decentralization across machines.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! [[ "$VALIDATOR_COUNT" =~ ^[0-9]+$ ]] || [[ "$VALIDATOR_COUNT" -lt 1 ]]; then
  echo "Invalid validator count: $VALIDATOR_COUNT" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_BASE="${YNX_HOME_BASE:-$ROOT_DIR/.testnet-multi}"
CHAIN_ID="${YNX_CHAIN_ID:-ynx_9002-1}"
DENOM="${YNX_DENOM:-anyxt}"

KEYRING="${YNX_KEYRING:-test}"
KEYALGO="${YNX_KEYALGO:-eth_secp256k1}"
DEPLOYER_KEY="${YNX_DEPLOYER_KEY:-deployer}"
MONIKER_PREFIX="${YNX_MONIKER_PREFIX:-ynx-testnet}"

GENESIS_BALANCE="${YNX_GENESIS_BALANCE:-1000000000000000000000000}"
SELF_DELEGATION="${YNX_SELF_DELEGATION:-1000000000000000000000}"

P2P_PORT_BASE="${YNX_P2P_PORT_BASE:-26656}"
RPC_PORT_BASE="${YNX_RPC_PORT_BASE:-26657}"
APP_PORT_BASE="${YNX_APP_PORT_BASE:-26658}"
PROM_PORT_BASE="${YNX_PROM_PORT_BASE:-26660}"
PPROF_PORT_BASE="${YNX_PPROF_PORT_BASE:-6060}"
API_PORT_BASE="${YNX_API_PORT_BASE:-1317}"
GRPC_PORT_BASE="${YNX_GRPC_PORT_BASE:-9090}"
GRPC_WEB_PORT_BASE="${YNX_GRPC_WEB_PORT_BASE:-9091}"
JSONRPC_PORT_BASE="${YNX_JSONRPC_PORT_BASE:-8545}"
JSONRPC_WS_PORT_BASE="${YNX_JSONRPC_WS_PORT_BASE:-8546}"
PORT_OFFSET="${YNX_PORT_OFFSET:-10}"
DISABLE_NON_RPC="${YNX_DISABLE_NON_RPC:-1}"

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

auto_scale() {
  local cores mem_bytes mem_mb reserved_mb per_node_mb cpu_factor fd_limit fd_per_node max_by_mem max_by_cpu max_by_fd max
  cores="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
  mem_bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
  mem_mb=$((mem_bytes / 1024 / 1024))
  reserved_mb="${YNX_RESERVED_MB:-1500}"
  per_node_mb="${YNX_PER_NODE_MB:-600}"
  cpu_factor="${YNX_CPU_FACTOR:-4}"
  fd_limit="$(ulimit -n 2>/dev/null || echo 1024)"
  fd_per_node="${YNX_FD_PER_NODE:-256}"

  if [[ "$mem_mb" -le 0 ]]; then
    max_by_mem=1
  else
    local available_mb=$((mem_mb - reserved_mb))
    if [[ "$available_mb" -le 0 ]]; then
      available_mb="$mem_mb"
    fi
    max_by_mem=$((available_mb / per_node_mb))
  fi

  max_by_cpu=$((cores * cpu_factor))
  max_by_fd=$(((fd_limit - 1024) / fd_per_node))

  if [[ "$max_by_fd" -le 0 ]]; then
    max_by_fd=1
  fi

  max="$max_by_mem"
  if [[ "$max_by_cpu" -lt "$max" ]]; then
    max="$max_by_cpu"
  fi
  if [[ "$max_by_fd" -lt "$max" ]]; then
    max="$max_by_fd"
  fi
  if [[ "$max" -lt 1 ]]; then
    max=1
  fi

  if [[ -n "${YNX_MAX_VALIDATORS_CAP:-}" && "$YNX_MAX_VALIDATORS_CAP" -gt 0 ]]; then
    if [[ "$max" -gt "$YNX_MAX_VALIDATORS_CAP" ]]; then
      max="$YNX_MAX_VALIDATORS_CAP"
    fi
  fi

  echo "$max"
}

if [[ "$AUTO" -eq 1 && "$VALIDATOR_COUNT_SET" -eq 0 ]]; then
  VALIDATOR_COUNT="$(auto_scale)"
  echo "Auto-scaled validator count: $VALIDATOR_COUNT"
fi

if ! [[ "$VALIDATOR_COUNT" =~ ^[0-9]+$ ]] || [[ "$VALIDATOR_COUNT" -lt 1 ]]; then
  echo "Invalid validator count: $VALIDATOR_COUNT" >&2
  exit 1
fi

check_ports() {
  local base="$1"
  local max_port=$((base + (VALIDATOR_COUNT - 1) * PORT_OFFSET))
  if [[ "$max_port" -gt 65535 ]]; then
    echo "Port range exceeds 65535 (base $base, offset $PORT_OFFSET, count $VALIDATOR_COUNT)" >&2
    exit 1
  fi
}

check_ports "$P2P_PORT_BASE"
check_ports "$RPC_PORT_BASE"
check_ports "$APP_PORT_BASE"
check_ports "$PROM_PORT_BASE"
check_ports "$PPROF_PORT_BASE"
check_ports "$API_PORT_BASE"
check_ports "$GRPC_PORT_BASE"
check_ports "$GRPC_WEB_PORT_BASE"
check_ports "$JSONRPC_PORT_BASE"
check_ports "$JSONRPC_WS_PORT_BASE"

BIN="$ROOT_DIR/ynxd"
if [[ ! -x "$BIN" ]]; then
  echo "Building ynxd..."
  (
    cd "$ROOT_DIR"
    CGO_ENABLED="${YNX_CGO_ENABLED:-0}" go build -o "$BIN" ./cmd/ynxd
  )
fi

if [[ "$RESET" -eq 1 ]]; then
  echo "Resetting home base: $HOME_BASE"
  rm -rf "$HOME_BASE"
fi

mkdir -p "$HOME_BASE"

set_ports() {
  local home="$1"
  local index="$2"
  local offset=$((index * PORT_OFFSET))
  local p2p_port=$((P2P_PORT_BASE + offset))
  local rpc_port=$((RPC_PORT_BASE + offset))
  local app_port=$((APP_PORT_BASE + offset))
  local prom_port=$((PROM_PORT_BASE + offset))
  local pprof_port=$((PPROF_PORT_BASE + offset))
  local api_port=$((API_PORT_BASE + offset))
  local grpc_port=$((GRPC_PORT_BASE + offset))
  local grpc_web_port=$((GRPC_WEB_PORT_BASE + offset))
  local jsonrpc_port=$((JSONRPC_PORT_BASE + offset))
  local jsonrpc_ws_port=$((JSONRPC_WS_PORT_BASE + offset))

  local config="$home/config/config.toml"
  local app="$home/config/app.toml"

  sed -i.bak -E "s|^proxy_app = \"tcp://127.0.0.1:[0-9]+\"|proxy_app = \"tcp://127.0.0.1:${app_port}\"|" "$config"
  sed -i.bak -E "s|^laddr = \"tcp://127.0.0.1:[0-9]+\"|laddr = \"tcp://127.0.0.1:${rpc_port}\"|" "$config"
  sed -i.bak -E "s|^laddr = \"tcp://0.0.0.0:[0-9]+\"|laddr = \"tcp://0.0.0.0:${p2p_port}\"|" "$config"
  sed -i.bak -E "s|^pprof_laddr = \"localhost:[0-9]+\"|pprof_laddr = \"localhost:${pprof_port}\"|" "$config" || true
  sed -i.bak -E "s|^prometheus_listen_addr = \":?[0-9]+\"|prometheus_listen_addr = \":${prom_port}\"|" "$config" || true

  sed -i.bak -E "s#^address = \"tcp://(0.0.0.0|127.0.0.1|localhost):1317\"#address = \"tcp://0.0.0.0:${api_port}\"#" "$app" || true
  sed -i.bak -E "s#^address = \"(0.0.0.0|127.0.0.1|localhost):9090\"#address = \"0.0.0.0:${grpc_port}\"#" "$app" || true
  sed -i.bak -E "s#^address = \"(0.0.0.0|127.0.0.1|localhost):9091\"#address = \"0.0.0.0:${grpc_web_port}\"#" "$app" || true
  sed -i.bak -E "s#^address = \"(0.0.0.0|127.0.0.1|localhost):8545\"#address = \"0.0.0.0:${jsonrpc_port}\"#" "$app" || true
  sed -i.bak -E "s#^ws-address = \"(0.0.0.0|127.0.0.1|localhost):8546\"#ws-address = \"0.0.0.0:${jsonrpc_ws_port}\"#" "$app" || true
}

disable_non_rpc_services() {
  local app="$1"
  sed -i.bak -E '/^\[api\]$/,/^\[/ s/^enable = .*/enable = false/' "$app" || true
  sed -i.bak -E '/^\[grpc\]$/,/^\[/ s/^enable = .*/enable = false/' "$app" || true
  sed -i.bak -E '/^\[grpc-web\]$/,/^\[/ s/^enable = .*/enable = false/' "$app" || true
  sed -i.bak -E '/^\[json-rpc\]$/,/^\[/ s/^enable = .*/enable = false/' "$app" || true
}

tune_timeouts() {
  local config="$1"
  echo "Tuning CometBFT timeouts (target ~1s blocks)..."
  sed -i.bak 's/timeout_propose = "3s"/timeout_propose = "1s"/' "$config"
  sed -i.bak 's/timeout_propose_delta = "500ms"/timeout_propose_delta = "200ms"/' "$config"
  if grep -q '^timeout_vote = ' "$config"; then
    sed -i.bak 's/timeout_vote = "1s"/timeout_vote = "500ms"/' "$config"
    sed -i.bak 's/timeout_vote_delta = "500ms"/timeout_vote_delta = "200ms"/' "$config"
  else
    sed -i.bak 's/timeout_prevote = "1s"/timeout_prevote = "500ms"/' "$config"
    sed -i.bak 's/timeout_prevote_delta = "500ms"/timeout_prevote_delta = "200ms"/' "$config"
    sed -i.bak 's/timeout_precommit = "1s"/timeout_precommit = "500ms"/' "$config"
    sed -i.bak 's/timeout_precommit_delta = "500ms"/timeout_precommit_delta = "200ms"/' "$config"
  fi
  sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "1s"/' "$config"
}

configure_local_p2p() {
  local config="$1"
  sed -i.bak 's/^allow_duplicate_ip = .*/allow_duplicate_ip = true/' "$config" || true
  sed -i.bak 's/^addr_book_strict = .*/addr_book_strict = false/' "$config" || true
  sed -i.bak 's/^pex = .*/pex = false/' "$config" || true
}

declare -a NODE_HOME=()
declare -a VAL_ADDR=()
declare -a VALOPER_ADDR=()
declare -a NODE_ID=()

for ((i=0; i<VALIDATOR_COUNT; i++)); do
  home="$HOME_BASE/node${i}"
  moniker="${MONIKER_PREFIX}-${i}"
  NODE_HOME+=("$home")

  echo "Initializing node $i..."
  "$BIN" init "$moniker" --chain-id "$CHAIN_ID" --home "$home" >/dev/null 2>&1

  "$BIN" config set client chain-id "$CHAIN_ID" --home "$home" >/dev/null 2>&1
  "$BIN" config set client keyring-backend "$KEYRING" --home "$home" >/dev/null 2>&1

  sed -i.bak -E "s/^evm-chain-id = .*/evm-chain-id = ${EVM_CHAIN_ID}/" "$home/config/app.toml"

  if [[ "${YNX_FAST_BLOCKS:-1}" == "1" ]]; then
    tune_timeouts "$home/config/config.toml"
  fi

  configure_local_p2p "$home/config/config.toml"

  set_ports "$home" "$i"

  if [[ "$DISABLE_NON_RPC" == "1" && "$i" -ne "$JSONRPC_NODE" ]]; then
    disable_non_rpc_services "$home/config/app.toml"
  fi

  if ! "$BIN" keys show validator --keyring-backend "$KEYRING" --home "$home" >/dev/null 2>&1; then
    "$BIN" keys add validator --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "$home" >/dev/null 2>&1
  fi

  VAL_ADDR+=("$("$BIN" keys show validator -a --keyring-backend "$KEYRING" --home "$home")")
  VALOPER_ADDR+=("$("$BIN" keys show validator -a --bech val --keyring-backend "$KEYRING" --home "$home")")
done

DEPLOYER_ADDR=""
if [[ -n "${YNX_DEPLOYER_ADDRESS:-}" ]]; then
  DEPLOYER_ADDR="$YNX_DEPLOYER_ADDRESS"
else
  if ! "$BIN" keys show "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --home "${NODE_HOME[0]}" >/dev/null 2>&1; then
    "$BIN" keys add "$DEPLOYER_KEY" --keyring-backend "$KEYRING" --algo "$KEYALGO" --home "${NODE_HOME[0]}" >/dev/null 2>&1
  fi
  DEPLOYER_ADDR="$("$BIN" keys show "$DEPLOYER_KEY" -a --keyring-backend "$KEYRING" --home "${NODE_HOME[0]}")"
fi

FOUNDER_ADDR="${YNX_FOUNDER_ADDRESS:-${VAL_ADDR[0]}}"
TEAM_BENEFICIARY_ADDR="${YNX_TEAM_BENEFICIARY:-${VAL_ADDR[0]}}"
COMMUNITY_RECIPIENT_ADDR="${YNX_COMMUNITY_RECIPIENT:-${VAL_ADDR[0]}}"
TREASURY_ADDR="${YNX_TREASURY_ADDRESS:-}"

echo "Configuring YNX module genesis..."
GENESIS_ARGS=(
  genesis ynx set
  --home "${NODE_HOME[0]}"
  --ynx.system.enabled
  --ynx.system.deployer "$DEPLOYER_ADDR"
  --ynx.system.team-beneficiary "$TEAM_BENEFICIARY_ADDR"
  --ynx.system.community-recipient "$COMMUNITY_RECIPIENT_ADDR"
  --ynx.params.founder "$FOUNDER_ADDR"
)
if [[ -n "$TREASURY_ADDR" ]]; then
  GENESIS_ARGS+=(--ynx.params.treasury "$TREASURY_ADDR")
fi
"$BIN" "${GENESIS_ARGS[@]}" >/dev/null 2>&1

echo "Funding accounts..."
for addr in "${VAL_ADDR[@]}"; do
  "$BIN" genesis add-genesis-account "$addr" "${GENESIS_BALANCE}${DENOM}" --home "${NODE_HOME[0]}" >/dev/null 2>&1
done

for extra in "$DEPLOYER_ADDR" "$FOUNDER_ADDR" "$TEAM_BENEFICIARY_ADDR" "$COMMUNITY_RECIPIENT_ADDR" "$TREASURY_ADDR"; do
  [[ -z "$extra" ]] && continue
  if ! printf '%s\n' "${VAL_ADDR[@]}" | grep -qx "$extra"; then
    "$BIN" genesis add-genesis-account "$extra" "${GENESIS_BALANCE}${DENOM}" --home "${NODE_HOME[0]}" >/dev/null 2>&1
  fi
done

echo "Copying base genesis to all nodes..."
for ((i=1; i<VALIDATOR_COUNT; i++)); do
  cp "${NODE_HOME[0]}/config/genesis.json" "${NODE_HOME[$i]}/config/genesis.json"
done

echo "Generating gentx files..."
for ((i=0; i<VALIDATOR_COUNT; i++)); do
  "$BIN" genesis gentx validator "${SELF_DELEGATION}${DENOM}" \
    --chain-id "$CHAIN_ID" \
    --keyring-backend "$KEYRING" \
    --home "${NODE_HOME[$i]}" >/dev/null 2>&1
  if [[ "$i" -ne 0 ]]; then
    for gentx in "${NODE_HOME[$i]}"/config/gentx/gentx-*.json; do
      cp "$gentx" "${NODE_HOME[0]}/config/gentx/"
    done
  fi
done

echo "Collecting gentxs..."
"$BIN" genesis collect-gentxs --home "${NODE_HOME[0]}" >/dev/null 2>&1

echo "Validating genesis..."
"$BIN" genesis validate --home "${NODE_HOME[0]}" >/dev/null 2>&1

echo "Distributing finalized genesis..."
for ((i=1; i<VALIDATOR_COUNT; i++)); do
  cp "${NODE_HOME[0]}/config/genesis.json" "${NODE_HOME[$i]}/config/genesis.json"
done

echo "Configuring persistent peers..."
for ((i=0; i<VALIDATOR_COUNT; i++)); do
  NODE_ID[$i]="$("$BIN" comet show-node-id --home "${NODE_HOME[$i]}")"
done

for ((i=0; i<VALIDATOR_COUNT; i++)); do
  peers=()
  for ((j=0; j<VALIDATOR_COUNT; j++)); do
    [[ "$i" -eq "$j" ]] && continue
    p2p_port=$((P2P_PORT_BASE + (j * PORT_OFFSET)))
    peers+=("${NODE_ID[$j]}@127.0.0.1:${p2p_port}")
  done
  peer_csv="$(IFS=,; echo "${peers[*]}")"
  sed -i.bak -E "s|^persistent_peers = \".*\"|persistent_peers = \"${peer_csv}\"|" "${NODE_HOME[$i]}/config/config.toml"
done

echo
echo "Multi-node bootstrap complete:"
echo "  Home base: $HOME_BASE"
echo "  Chain ID:  $CHAIN_ID"
echo "  EVM ID:    $EVM_CHAIN_ID"
echo "  Validators: $VALIDATOR_COUNT"
echo "  JSON-RPC:  http://127.0.0.1:$((JSONRPC_PORT_BASE + (JSONRPC_NODE * PORT_OFFSET)))"

if [[ "$START" -eq 1 ]]; then
  echo
  echo "Starting validators..."
  for ((i=0; i<VALIDATOR_COUNT; i++)); do
    log_path="${NODE_HOME[$i]}/ynxd.log"
    if [[ "$i" -eq "$JSONRPC_NODE" ]]; then
      "$BIN" start \
        --home "${NODE_HOME[$i]}" \
        --minimum-gas-prices "0$DENOM" \
        --json-rpc.enable \
        --json-rpc.api "eth,net,web3,ynx" \
        --json-rpc.enable-indexer \
        >"$log_path" 2>&1 &
    else
      "$BIN" start \
        --home "${NODE_HOME[$i]}" \
        --minimum-gas-prices "0$DENOM" \
        >"$log_path" 2>&1 &
    fi
  done
  echo "Logs:"
  for ((i=0; i<VALIDATOR_COUNT; i++)); do
    echo "  ${NODE_HOME[$i]}/ynxd.log"
  done
fi
