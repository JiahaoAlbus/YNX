#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ynx_ui.sh"
ynx_ui_init

usage() {
  cat <<'USAGE'
Usage:
  v2_join_and_verify.sh [options]

One-command join + verify for YNX v2 network.
Default target is a normal full node.

Options:
  --role <validator|full-node|public-rpc>  default: full-node
  --moniker <name>                         default: <hostname>-ynx
  --home <path>                            default: ~/.ynx-v2-join
  --rpc <url>                              default: https://rpc.ynxweb4.com
  --chain-id <id>                          default: ynx_9102-1
  --persistent-peers <list>                default: built-in canonical peers
  --minimum-gas-prices <value>             default: 0.000000007anyxt
  --statesync                              enable state sync bootstrap (default: on for public testnet)
  --no-statesync                           force disable state sync bootstrap
  --lag-max <blocks>                       default: 20
  --port-offset <n>                        default: auto(0 or 100 if 36657 busy)
  --sync-timeout <seconds>                 default: 1800
  --peer-wait <seconds>                    default: 600
  --rpc-wait <seconds>                     default: 300
  --plan-only                              print resolved flow and exit
  --reset                                  wipe home and re-bootstrap
  --create-validator                       create validator tx after sync (validator role)
  --self-delegation <amount>               default: 100000000000000000000anyxt
  --key-name <name>                        default: validator
  --website <url>                          default: https://ynxweb4.com
  --security-contact <email>               default: founder@ynxweb4.com
  --details <text>                         default: YNX validator
  -h, --help                               show help

Examples:
  ./scripts/v2_join_and_verify.sh --moniker my-node
  ./scripts/v2_join_and_verify.sh --role validator --moniker my-val --create-validator
USAGE
}

ROLE="full-node"
MONIKER="$(hostname)-ynx"
HOME_DIR="${HOME}/.ynx-v2-join"
RPC_URL="https://rpc.ynxweb4.com"
CHAIN_ID="ynx_9102-1"
PERSISTENT_PEERS_DEFAULT="c97ce9fdf76d2634651e4cb9cbb12dbad8327037@43.153.202.237:36656"
PERSISTENT_PEERS="$PERSISTENT_PEERS_DEFAULT"
MIN_GAS_PRICES="0.000000007anyxt"
ENABLE_STATESYNC=1
LAG_MAX=20
PORT_OFFSET=""
SYNC_TIMEOUT=1800
PEER_WAIT=600
RPC_WAIT=300
RESET=0
PLAN_ONLY=0
CREATE_VALIDATOR=0
SELF_DELEGATION="100000000000000000000anyxt"
KEY_NAME="validator"
WEBSITE="https://ynxweb4.com"
SECURITY_CONTACT="founder@ynxweb4.com"
DETAILS="YNX validator"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role)
      ROLE="${2:-}"
      shift 2
      ;;
    --moniker)
      MONIKER="${2:-}"
      shift 2
      ;;
    --home)
      HOME_DIR="${2:-}"
      shift 2
      ;;
    --rpc)
      RPC_URL="${2:-}"
      shift 2
      ;;
    --chain-id)
      CHAIN_ID="${2:-}"
      shift 2
      ;;
    --persistent-peers)
      PERSISTENT_PEERS="${2:-}"
      shift 2
      ;;
    --minimum-gas-prices)
      MIN_GAS_PRICES="${2:-}"
      shift 2
      ;;
    --statesync)
      ENABLE_STATESYNC=1
      shift
      ;;
    --no-statesync)
      ENABLE_STATESYNC=0
      shift
      ;;
    --lag-max)
      LAG_MAX="${2:-}"
      shift 2
      ;;
    --port-offset)
      PORT_OFFSET="${2:-}"
      shift 2
      ;;
    --sync-timeout)
      SYNC_TIMEOUT="${2:-}"
      shift 2
      ;;
    --peer-wait)
      PEER_WAIT="${2:-}"
      shift 2
      ;;
    --rpc-wait)
      RPC_WAIT="${2:-}"
      shift 2
      ;;
    --plan-only)
      PLAN_ONLY=1
      shift
      ;;
    --reset)
      RESET=1
      shift
      ;;
    --create-validator)
      CREATE_VALIDATOR=1
      shift
      ;;
    --self-delegation)
      SELF_DELEGATION="${2:-}"
      shift 2
      ;;
    --key-name)
      KEY_NAME="${2:-}"
      shift 2
      ;;
    --website)
      WEBSITE="${2:-}"
      shift 2
      ;;
    --security-contact)
      SECURITY_CONTACT="${2:-}"
      shift 2
      ;;
    --details)
      DETAILS="${2:-}"
      shift 2
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

case "$ROLE" in
  validator|full-node|public-rpc) ;;
  *)
    echo "Invalid role: $ROLE" >&2
    exit 1
    ;;
esac

if [[ "$CREATE_VALIDATOR" -eq 1 && "$ROLE" != "validator" ]]; then
  echo "--create-validator requires --role validator" >&2
  exit 1
fi

if ! [[ "$LAG_MAX" =~ ^[0-9]+$ ]]; then
  echo "--lag-max must be integer" >&2
  exit 1
fi
if [[ -n "$PORT_OFFSET" ]] && ! [[ "$PORT_OFFSET" =~ ^[0-9]+$ ]]; then
  echo "--port-offset must be integer >= 0" >&2
  exit 1
fi
if ! [[ "$SYNC_TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "--sync-timeout must be integer" >&2
  exit 1
fi
if ! [[ "$PEER_WAIT" =~ ^[0-9]+$ ]]; then
  echo "--peer-wait must be integer" >&2
  exit 1
fi
if ! [[ "$RPC_WAIT" =~ ^[0-9]+$ ]]; then
  echo "--rpc-wait must be integer" >&2
  exit 1
fi

for bin in curl jq awk mktemp sed grep pgrep; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_SCRIPT="$ROOT_DIR/scripts/v2_validator_bootstrap.sh"
if [[ ! -x "$BOOTSTRAP_SCRIPT" ]]; then
  echo "Missing bootstrap script: $BOOTSTRAP_SCRIPT" >&2
  exit 1
fi

OS_RAW="$(uname -s 2>/dev/null || echo unknown)"
OS_NAME="$(echo "$OS_RAW" | tr '[:upper:]' '[:lower:]')"

STEP=0
TOTAL_STEPS=7
step() {
  STEP=$((STEP + 1))
  if [[ "${YNX_UI_GLOBAL_MODE:-0}" -eq 1 ]]; then
    local pct=0
    local detail=""
    case "$STEP" in
      1) pct=72; detail="write node home, config.toml, app.toml, and genesis.json" ;;
      2) pct=76; detail="launch ynxd with explicit P2P, RPC, and ABCI ports" ;;
      3) pct=80; detail="probe local RPC until status is reachable and chain-id matches" ;;
      4) pct=82; detail="wait for peer handshake or first local block movement" ;;
      5) pct=90; detail="compare local height with the reference RPC until lag is acceptable" ;;
      6) pct=98; detail="run final verification and summarize the node result" ;;
      7) pct=100; detail="join and verification pipeline completed" ;;
      *) pct=100 ;;
    esac
    ynx_ui_progress_reset_metrics
    ynx_ui_progress "$pct" "$*" "$detail"
  else
    ynx_ui_step "$STEP" "$TOTAL_STEPS" "$*"
  fi
}

if [[ "$OS_NAME" == *darwin* ]] && [[ "$ROLE" != "full-node" ]]; then
  echo "WARNING: validator/public-rpc is strongly recommended on Linux servers." >&2
fi

if [[ -z "${YNX_BIN:-}" ]]; then
  if [[ -x "$ROOT_DIR/ynxd" ]]; then
    export YNX_BIN="$ROOT_DIR/ynxd"
  elif command -v ynxd >/dev/null 2>&1; then
    export YNX_BIN="$(command -v ynxd)"
  fi
fi

NODE_BIN="${YNX_BIN:-$ROOT_DIR/ynxd}"
if [[ ! -x "$NODE_BIN" ]]; then
  if [[ "$PLAN_ONLY" -eq 1 ]]; then
    NODE_BIN="unresolved(plan-only)"
  elif command -v go >/dev/null 2>&1; then
    step "build ynxd binary"
    DEFAULT_GOPROXY="https://goproxy.cn,https://proxy.golang.org,direct"
    (cd "$ROOT_DIR" && GOPROXY="${GOPROXY:-$DEFAULT_GOPROXY}" CGO_ENABLED=0 go build -buildvcs=false -o "$ROOT_DIR/ynxd" ./cmd/ynxd)
    NODE_BIN="$ROOT_DIR/ynxd"
  else
    echo "No ynxd binary found and go is missing." >&2
    echo "Set YNX_BIN=<path-to-ynxd> or install Go and rerun." >&2
    exit 1
  fi
fi

normalize_rpc() {
  local url="$1"
  if [[ "$url" =~ /$ ]]; then
    echo "${url%/}"
  else
    echo "$url"
  fi
}

RPC_URL="$(normalize_rpc "$RPC_URL")"

port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn "( sport = :$p )" 2>/dev/null | awk 'NR>1 {print $4}' | grep -q ":$p$"
    return $?
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -lnt 2>/dev/null | awk '{print $4}' | grep -q "[.:]$p$"
    return $?
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  return 1
}

if [[ -z "$PORT_OFFSET" ]]; then
  if port_in_use 36657; then
    PORT_OFFSET=100
    ynx_ui_note "[YNX-JOIN] detected port 36657 in use, auto apply --port-offset=${PORT_OFFSET}" warn
  else
    PORT_OFFSET=0
  fi
fi

LOCAL_RPC_PORT=$((36657 + PORT_OFFSET))
LOCAL_P2P_PORT=$((36656 + PORT_OFFSET))
LOCAL_ABCI_PORT=$((36658 + PORT_OFFSET))
LOCAL_RPC="http://127.0.0.1:${LOCAL_RPC_PORT}"

if [[ "${YNX_UI_SUPPRESS_HEADER:-0}" -ne 1 ]]; then
  ynx_ui_banner "Join + verify pipeline" "This stage bootstraps the node home, starts ynxd, waits for RPC, waits for peers, then verifies block sync."
  ynx_ui_plan "Join pipeline order" \
    "Normalize configuration and choose ports" \
    "Bootstrap chain home and write config/genesis" \
    "Start the node with explicit RPC, P2P, and ABCI ports" \
    "Wait for the local RPC to become reachable" \
    "Observe peer formation or first block movement" \
    "Compare sync height against the reference RPC" \
    "Optionally create the validator transaction after sync"
  ynx_ui_kv "role" "$ROLE"
  ynx_ui_kv "moniker" "$MONIKER"
  ynx_ui_kv "home" "$HOME_DIR"
  ynx_ui_kv "rpc_ref" "$RPC_URL"
  ynx_ui_kv "chain_id" "$CHAIN_ID"
  ynx_ui_kv "node_bin" "$NODE_BIN"
  ynx_ui_kv "port_offset" "$PORT_OFFSET"
  ynx_ui_kv "local_p2p" "$LOCAL_P2P_PORT"
  ynx_ui_kv "local_rpc" "$LOCAL_RPC"
  ynx_ui_kv "statesync" "$ENABLE_STATESYNC"
  ynx_ui_kv "plan_only" "$PLAN_ONLY"
  echo
fi

if [[ "$PLAN_ONLY" -eq 1 ]]; then
  ynx_ui_note "Plan-only mode: no chain home created, no process started, and no network verification executed."
  exit 0
fi

curl_get_retry() {
  local url="$1"
  local attempts="${2:-60}"
  local sleep_sec="${3:-2}"
  local out=""
  for _ in $(seq 1 "$attempts"); do
    out="$(curl -fsS --max-time 8 "$url" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      echo "$out"
      return 0
    fi
    sleep "$sleep_sec"
  done
  return 1
}

log() {
  ynx_ui_stdout "[YNX-JOIN] $*"
}

summarize_peer_failures() {
  local log_file="$HOME_DIR/node.out.log"
  echo
  echo "---- P2P diagnostics ----" >&2
  echo "local_rpc=$LOCAL_RPC p2p_port=$LOCAL_P2P_PORT home=$HOME_DIR" >&2

  if [[ -f "$HOME_DIR/config/config.toml" ]]; then
    local peer_cfg
    peer_cfg="$(
      awk '
        $1=="seeds" ||
        $1=="persistent_peers" ||
        $1=="addr_book_strict" ||
        $1=="private_peer_ids" ||
        $1=="allow_duplicate_ip" ||
        $1=="external_address" {print}
      ' "$HOME_DIR/config/config.toml" | sed -n '1,8p'
    )"
    if [[ -n "$peer_cfg" ]]; then
      echo "$peer_cfg" >&2
    fi
  fi

  local net_raw
  net_raw="$(curl -fsS --max-time 6 "$LOCAL_RPC/net_info" 2>/dev/null || true)"
  if [[ -n "$net_raw" ]]; then
    local n_peers
    n_peers="$(echo "$net_raw" | jq -r '.result.n_peers // empty' 2>/dev/null || true)"
    if [[ -n "$n_peers" ]]; then
      echo "local_net_info.n_peers=$n_peers" >&2
    else
      echo "local_net_info.error=$(echo "$net_raw" | tr '\n' ' ' | cut -c1-220)" >&2
    fi
  else
    echo "local_net_info.error=unreachable" >&2
  fi

  if [[ -f "$log_file" ]]; then
    local eof_cnt closed_cnt auth_cnt
    eof_cnt="$(grep -c 'Connection error.*EOF' "$log_file" 2>/dev/null || true)"
    closed_cnt="$(grep -c 'Connection is closed @ recvRoutine' "$log_file" 2>/dev/null || true)"
    auth_cnt="$(grep -ci 'auth\|secret connection\|handshake' "$log_file" 2>/dev/null || true)"
    echo "node_log_counts: eof=${eof_cnt:-0} closed_by_remote=${closed_cnt:-0} auth_or_handshake=${auth_cnt:-0}" >&2
    echo "recent_p2p_log:" >&2
    grep -E 'Connection error|recvRoutine|handshake|secret connection|unauth|auth' "$log_file" 2>/dev/null | tail -n 12 >&2 || true
  else
    echo "node_log.missing=$log_file" >&2
  fi
  echo "---- end diagnostics ----" >&2
}

descriptor_peers() {
  local indexer_url descriptor_url json peers
  indexer_url="$(echo "$RPC_URL" | sed -E 's#://rpc\.#://indexer.#')"
  descriptor_url="${indexer_url}/ynx/network-descriptor"
  json="$(curl -fsS --max-time 8 "$descriptor_url" 2>/dev/null || true)"
  peers="$(echo "$json" | jq -r '.network.persistent_peers // empty' 2>/dev/null || true)"
  if [[ -n "$peers" && "$peers" != "null" ]]; then
    echo "$peers"
  fi
}

merge_peers() {
  local base="$1"
  local extra="$2"
  awk -F',' '
    {
      for (i=1; i<=NF; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
        if ($i != "" && !seen[$i]++) out[++n]=$i
      }
    }
    END {
      for (i=1; i<=n; i++) {
        printf "%s%s", out[i], (i<n ? "," : "")
      }
    }
  ' <<<"${base},${extra}"
}

if [[ "$PERSISTENT_PEERS" == "$PERSISTENT_PEERS_DEFAULT" ]]; then
  discovered_peers="$(descriptor_peers || true)"
  if [[ -n "${discovered_peers:-}" ]]; then
    PERSISTENT_PEERS="$(merge_peers "$PERSISTENT_PEERS_DEFAULT" "$discovered_peers")"
  fi
fi

step "bootstrap chain home"
log "bootstrap role=$ROLE moniker=$MONIKER home=$HOME_DIR rpc=$RPC_URL"
BOOTSTRAP_ARGS=(
  --rpc "$RPC_URL"
  --home "$HOME_DIR"
  --chain-id "$CHAIN_ID"
  --moniker "$MONIKER"
  --role "$ROLE"
  --port-offset "$PORT_OFFSET"
  --persistent-peers "$PERSISTENT_PEERS"
  --minimum-gas-prices "$MIN_GAS_PRICES"
)
if [[ "$ENABLE_STATESYNC" -eq 0 ]]; then
  BOOTSTRAP_ARGS+=(--no-statesync)
fi
if [[ "$RESET" -eq 1 ]]; then
  BOOTSTRAP_ARGS+=(--reset)
fi
YNX_UI_EMBEDDED=1 \
YNX_UI_SUPPRESS_HEADER=1 \
"$BOOTSTRAP_SCRIPT" "${BOOTSTRAP_ARGS[@]}"

if ! jq -e '.chain_id != null and .app_state != null' "$HOME_DIR/config/genesis.json" >/dev/null 2>&1; then
  echo "Invalid genesis file after bootstrap: $HOME_DIR/config/genesis.json" >&2
  exit 1
fi

# Keep public join nodes protocol-compatible with the live YNX public testnet.
# The canonical public peers run with CometBFT PEX disabled; enabling PEX adds
# channel 0x00 and can cause peers to close the handshake.
if [[ -f "$HOME_DIR/config/config.toml" ]]; then
  awk '
    BEGIN { section = "" }
    /^\[/ { section = $0 }
    section == "[p2p]" && $1 == "pex" { print "pex = false"; next }
    { print }
  ' "$HOME_DIR/config/config.toml" >"$HOME_DIR/config/config.toml.tmp"
  mv "$HOME_DIR/config/config.toml.tmp" "$HOME_DIR/config/config.toml"
fi

step "start local node"
log "start local node process"
if pgrep -f "${NODE_BIN} start --home ${HOME_DIR}" >/dev/null 2>&1; then
  log "existing node process found, reusing"
else
  nohup "$NODE_BIN" start \
    --home "$HOME_DIR" \
    --chain-id "$CHAIN_ID" \
    --minimum-gas-prices "$MIN_GAS_PRICES" \
    --rpc.laddr "tcp://127.0.0.1:${LOCAL_RPC_PORT}" \
    --p2p.laddr "tcp://0.0.0.0:${LOCAL_P2P_PORT}" \
    --proxy_app "tcp://127.0.0.1:${LOCAL_ABCI_PORT}" \
    >"$HOME_DIR/node.out.log" 2>&1 &
  sleep 1
fi

step "wait local RPC"
log "wait local RPC"
rpc_attempts=$((RPC_WAIT / 2))
if (( rpc_attempts < 1 )); then
  rpc_attempts=1
fi
local_status="$(curl_get_retry "$LOCAL_RPC/status" "$rpc_attempts" 2)" || {
  echo "Local RPC not reachable at $LOCAL_RPC/status" >&2
  echo "Check log: $HOME_DIR/node.out.log" >&2
  exit 1
}

local_chain_id="$(echo "$local_status" | jq -r '.result.node_info.network')"
[[ "$local_chain_id" == "$CHAIN_ID" ]] || {
  echo "Local chain-id mismatch: got=$local_chain_id expected=$CHAIN_ID" >&2
  exit 1
}

ref_status="$(curl_get_retry "$RPC_URL/status" 30 2)" || {
  echo "Reference RPC not reachable: $RPC_URL/status" >&2
  exit 1
}
ref_chain_id="$(echo "$ref_status" | jq -r '.result.node_info.network')"
[[ "$ref_chain_id" == "$CHAIN_ID" ]] || {
  echo "Reference chain-id mismatch: got=$ref_chain_id expected=$CHAIN_ID" >&2
  exit 1
}

step "wait P2P peers"
get_local_peers() {
  local n
  n="$(curl -fsS --max-time 5 "$LOCAL_RPC/net_info" 2>/dev/null | jq -r '.result.n_peers // 0' 2>/dev/null || echo 0)"
  if [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "$n"
  else
    echo 0
  fi
}

log "wait peer connection: timeout=${PEER_WAIT}s"
peer_start_ts="$(date +%s)"
max_peers_seen=0
max_height_seen=0
last_peer_print=0
while true; do
  now_ts="$(date +%s)"
  peer_elapsed=$((now_ts - peer_start_ts))
  peers_now="$(get_local_peers)"
  if (( peers_now > max_peers_seen )); then
    max_peers_seen="$peers_now"
  fi

  local_status_now="$(curl -fsS --max-time 5 "$LOCAL_RPC/status" 2>/dev/null || true)"
  local_height_now="$(echo "$local_status_now" | jq -r '.result.sync_info.latest_block_height // 0' 2>/dev/null || echo 0)"
  if [[ "$local_height_now" =~ ^[0-9]+$ ]] && (( local_height_now > max_height_seen )); then
    max_height_seen="$local_height_now"
  fi

  if (( peer_elapsed - last_peer_print >= 3 )); then
    log "peer-probe elapsed=${peer_elapsed}s peers_now=${peers_now} max_peers=${max_peers_seen} local_height=${local_height_now}"
    if [[ "${YNX_UI_GLOBAL_MODE:-0}" -eq 1 ]]; then
      peer_pct=$((82 + (peer_elapsed * 8 / (PEER_WAIT > 0 ? PEER_WAIT : 1))))
      if (( peer_pct > 90 )); then
        peer_pct=90
      fi
      ynx_ui_progress_wait "$peer_pct" "wait P2P peers" "peer handshake | elapsed ${peer_elapsed}s | peers ${peers_now} | max ${max_peers_seen} | height ${local_height_now}" "$peer_elapsed" "$PEER_WAIT" "probe every 3s"
    fi
    last_peer_print="$peer_elapsed"
  fi

  if (( max_peers_seen > 0 || max_height_seen > 0 )); then
    break
  fi
  if (( peer_elapsed > PEER_WAIT )); then
    ynx_ui_stderr "WARN: no stable peer/height observation after ${PEER_WAIT}s; continuing to sync phase."
    ynx_ui_stderr "If sync later times out, check: $HOME_DIR/node.out.log"
    break
  fi
  sleep 3
done

step "sync and verify blocks"
log "wait sync: timeout=${SYNC_TIMEOUT}s lag<=${LAG_MAX}"
start_ts="$(date +%s)"
last_progress_print=0
sync_base_height=0
while true; do
  now_ts="$(date +%s)"
  elapsed=$((now_ts - start_ts))
  if (( elapsed > SYNC_TIMEOUT )); then
    ynx_ui_stderr "Sync timeout after ${SYNC_TIMEOUT}s"
    ynx_ui_stderr "Check log: $HOME_DIR/node.out.log"
    summarize_peer_failures
    exit 1
  fi

  local_status="$(curl -fsS --max-time 8 "$LOCAL_RPC/status" 2>/dev/null || true)"
  ref_status="$(curl -fsS --max-time 8 "$RPC_URL/status" 2>/dev/null || true)"
  if [[ -z "$local_status" || -z "$ref_status" ]]; then
    sleep 3
    continue
  fi

  local_height="$(echo "$local_status" | jq -r '.result.sync_info.latest_block_height')"
  local_catching_up="$(echo "$local_status" | jq -r '.result.sync_info.catching_up')"
  ref_height="$(echo "$ref_status" | jq -r '.result.sync_info.latest_block_height')"

  if ! [[ "$local_height" =~ ^[0-9]+$ && "$ref_height" =~ ^[0-9]+$ ]]; then
    sleep 3
    continue
  fi

  lag=$((ref_height - local_height))
  if (( lag < 0 )); then
    lag=0
  fi

  if (( sync_base_height == 0 )); then
    sync_base_height="$local_height"
  fi

  if (( elapsed - last_progress_print >= 3 )); then
    log "sync-progress elapsed=${elapsed}s local_height=${local_height} ref_height=${ref_height} lag=${lag} catching_up=${local_catching_up}"
    if [[ "${YNX_UI_GLOBAL_MODE:-0}" -eq 1 ]]; then
      target_delta=$((ref_height - sync_base_height))
      caught_delta=$((local_height - sync_base_height))
      if (( target_delta > 0 )); then
        if (( caught_delta < 0 )); then
          caught_delta=0
        fi
        if (( caught_delta > target_delta )); then
          caught_delta="$target_delta"
        fi
        sync_pct=$((90 + (caught_delta * 8 / target_delta)))
      else
        sync_pct=90
      fi
      if (( sync_pct > 98 )); then
        sync_pct=98
      fi
      ynx_ui_progress_metric "$sync_pct" "sync and verify blocks" "catch up blocks | height ${local_height}/${ref_height} | lag ${lag} | catching_up ${local_catching_up}" "sync-height" "$local_height" "$ref_height" "blk"
    fi
    last_progress_print="$elapsed"
  fi

  if [[ "$local_catching_up" == "false" && "$lag" -le "$LAG_MAX" ]]; then
    break
  fi

  sleep 3
done

final_local_status="$(curl_get_retry "$LOCAL_RPC/status" 10 1)"
final_ref_status="$(curl_get_retry "$RPC_URL/status" 10 1)"
final_local_height="$(echo "$final_local_status" | jq -r '.result.sync_info.latest_block_height')"
final_ref_height="$(echo "$final_ref_status" | jq -r '.result.sync_info.latest_block_height')"
final_lag=$((final_ref_height - final_local_height))
final_peers="$(get_local_peers)"
if (( final_lag < 0 )); then
  final_lag=0
fi

if (( final_peers == 0 )); then
  ynx_ui_note "WARN: final peer count is 0; network ingress may be blocked or boot peers are rejecting connections." warn >&2
  summarize_peer_failures
fi

check_height="$final_local_height"
if (( check_height > final_ref_height )); then
  check_height="$final_ref_height"
fi
if (( check_height < 2 )); then
  check_height=1
fi

ref_check_hash="$(curl_get_retry "$RPC_URL/block?height=$check_height" 20 1 | jq -r '.result.block_id.hash')"
local_check_hash="$(curl_get_retry "$LOCAL_RPC/block?height=$check_height" 20 1 | jq -r '.result.block_id.hash')"
[[ "$ref_check_hash" == "$local_check_hash" ]] || {
  echo "Block hash mismatch at height=$check_height" >&2
  echo "local=$local_check_hash" >&2
  echo "ref=$ref_check_hash" >&2
  exit 1
}

if [[ "$CREATE_VALIDATOR" -eq 1 ]]; then
  log "create validator requested"

  if ! "$NODE_BIN" keys show "$KEY_NAME" --home "$HOME_DIR" --keyring-backend test -a >/dev/null 2>&1; then
    "$NODE_BIN" keys add "$KEY_NAME" --home "$HOME_DIR" --keyring-backend test --key-type eth_secp256k1 >/dev/null
  fi

  val_addr="$($NODE_BIN keys show "$KEY_NAME" --home "$HOME_DIR" --keyring-backend test -a)"
  val_pub="$($NODE_BIN comet show-validator --home "$HOME_DIR")"

  bal_json="$($NODE_BIN query bank balances "$val_addr" --home "$HOME_DIR" --node "$LOCAL_RPC" --output json)"
  bal_anyxt="$(echo "$bal_json" | jq -r '.balances[]? | select(.denom=="anyxt") | .amount' | head -n1)"
  if [[ -z "$bal_anyxt" ]]; then
    bal_anyxt="0"
  fi

  required="${SELF_DELEGATION%anyxt}"
  if ! [[ "$required" =~ ^[0-9]+$ ]]; then
    echo "--self-delegation must be like 100000000000000000000anyxt" >&2
    exit 1
  fi

  if (( bal_anyxt < required )); then
    echo "Insufficient balance for self-delegation" >&2
    echo "address=$val_addr balance_anyxt=$bal_anyxt required=$required" >&2
    echo "Use faucet or transfer funds first, then run create-validator manually." >&2
    exit 1
  fi

  tmp_json="$(mktemp)"
  cat >"$tmp_json" <<JSON
{
  "pubkey": $val_pub,
  "amount": "$SELF_DELEGATION",
  "moniker": "$MONIKER",
  "identity": "",
  "website": "$WEBSITE",
  "security": "$SECURITY_CONTACT",
  "details": "$DETAILS",
  "commission-rate": "0.10",
  "commission-max-rate": "0.20",
  "commission-max-change-rate": "0.01",
  "min-self-delegation": "1"
}
JSON

  create_tx="$($NODE_BIN tx staking create-validator "$tmp_json" \
    --from "$KEY_NAME" \
    --home "$HOME_DIR" \
    --keyring-backend test \
    --chain-id "$CHAIN_ID" \
    --node "$LOCAL_RPC" \
    --gas 500000 \
    --gas-prices "$MIN_GAS_PRICES" \
    --yes \
    --broadcast-mode sync \
    --output json)"
  rm -f "$tmp_json"

  create_code="$(echo "$create_tx" | jq -r '.code')"
  create_hash="$(echo "$create_tx" | jq -r '.txhash')"
  if [[ "$create_code" != "0" ]]; then
    echo "create-validator failed code=$create_code tx=$create_hash" >&2
    echo "$(echo "$create_tx" | jq -r '.raw_log // .logs // .info // ""')" >&2
    exit 1
  fi

  log "create-validator tx accepted txhash=$create_hash"
fi

step "finalize"
echo
ynx_ui_note "PASS"
ynx_ui_kv "role" "$ROLE"
ynx_ui_kv "home" "$HOME_DIR"
ynx_ui_kv "rpc_ref" "$RPC_URL"
ynx_ui_kv "local_rpc" "$LOCAL_RPC"
ynx_ui_kv "chain_id" "$CHAIN_ID"
ynx_ui_kv "port_offset" "$PORT_OFFSET"
ynx_ui_kv "local_height" "$final_local_height"
ynx_ui_kv "ref_height" "$final_ref_height"
ynx_ui_kv "lag" "$final_lag"
ynx_ui_kv "peers" "$final_peers"
ynx_ui_kv "check_height" "$check_height"
ynx_ui_kv "check_hash" "$local_check_hash"
ynx_ui_kv "node_log" "$HOME_DIR/node.out.log"

if [[ "$ROLE" == "validator" && "$CREATE_VALIDATOR" -eq 0 ]]; then
  echo
  echo "Validator next-step (manual):"
  echo "$NODE_BIN keys add $KEY_NAME --home $HOME_DIR --keyring-backend test --key-type eth_secp256k1"
  echo "$NODE_BIN query bank balances \$($NODE_BIN keys show $KEY_NAME --home $HOME_DIR --keyring-backend test -a) --home $HOME_DIR --node $LOCAL_RPC"
fi
