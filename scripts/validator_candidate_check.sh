#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/validator_candidate_check.sh --p2p <node_id@host:port> [--rpc <url>] [--valoper <ynxvaloper...>]

Read-only coordinator check for an external validator candidate.

Checks:
  - P2P endpoint shape
  - TCP reachability for the advertised P2P host/port
  - optional RPC /status network and node id
  - optional validator operator status through public REST

Environment:
  EXPECTED_CHAIN_ID       default: ynx_9102-1
  REST_BASE_URL           default: https://rest.ynxweb4.com
  CONNECT_TIMEOUT_SEC     default: 8
EOF
}

P2P=""
RPC=""
VALOPER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --p2p)
      P2P="${2:-}"
      shift 2
      ;;
    --rpc)
      RPC="${2:-}"
      shift 2
      ;;
    --valoper)
      VALOPER="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$P2P" ]]; then
  echo "--p2p is required" >&2
  usage >&2
  exit 1
fi

for bin in curl jq nc; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

EXPECTED_CHAIN_ID="${EXPECTED_CHAIN_ID:-ynx_9102-1}"
REST_BASE_URL="${REST_BASE_URL:-https://rest.ynxweb4.com}"
CONNECT_TIMEOUT_SEC="${CONNECT_TIMEOUT_SEC:-8}"

if [[ ! "$P2P" =~ ^[0-9a-fA-F]{40}@[A-Za-z0-9._:-]+:[0-9]+$ ]]; then
  echo "FAIL p2p_format endpoint must look like node_id@host:port"
  exit 1
fi

node_id="${P2P%@*}"
host_port="${P2P#*@}"
host="${host_port%:*}"
port="${host_port##*:}"

fail=0
echo "Candidate P2P: $P2P"

if nc -G "$CONNECT_TIMEOUT_SEC" -z "$host" "$port" >/dev/null 2>&1 || nc -w "$CONNECT_TIMEOUT_SEC" -z "$host" "$port" >/dev/null 2>&1; then
  echo "PASS p2p_tcp host=${host} port=${port}"
else
  echo "FAIL p2p_tcp host=${host} port=${port}"
  fail=$((fail + 1))
fi

if [[ -n "$RPC" ]]; then
  status_json="$(curl -fsS --max-time "$CONNECT_TIMEOUT_SEC" "${RPC%/}/status" 2>/dev/null || true)"
  if [[ -z "$status_json" ]]; then
    echo "FAIL rpc_status ${RPC%/}/status"
    fail=$((fail + 1))
  else
    rpc_chain="$(echo "$status_json" | jq -r '.result.node_info.network // ""')"
    rpc_node_id="$(echo "$status_json" | jq -r '.result.node_info.id // ""')"
    catching_up="$(echo "$status_json" | jq -r '.result.sync_info.catching_up // true')"
    [[ "$rpc_chain" == "$EXPECTED_CHAIN_ID" ]] && echo "PASS rpc_chain_id $rpc_chain" || { echo "FAIL rpc_chain_id got=${rpc_chain} expected=${EXPECTED_CHAIN_ID}"; fail=$((fail + 1)); }
    [[ "$rpc_node_id" == "$node_id" ]] && echo "PASS rpc_node_id $rpc_node_id" || echo "WARN rpc_node_id got=${rpc_node_id} advertised=${node_id}"
    [[ "$catching_up" == "false" ]] && echo "PASS rpc_catching_up false" || echo "WARN rpc_catching_up $catching_up"
  fi
fi

if [[ -n "$VALOPER" ]]; then
  val_json="$(curl -fsS --max-time "$CONNECT_TIMEOUT_SEC" "${REST_BASE_URL%/}/cosmos/staking/v1beta1/validators/${VALOPER}" 2>/dev/null || true)"
  if [[ -z "$val_json" ]]; then
    echo "WARN validator_not_bonded_or_not_found $VALOPER"
  else
    status="$(echo "$val_json" | jq -r '.validator.status // ""')"
    jailed="$(echo "$val_json" | jq -r '.validator.jailed // ""')"
    moniker="$(echo "$val_json" | jq -r '.validator.description.moniker // ""')"
    echo "INFO validator moniker=${moniker} status=${status} jailed=${jailed}"
    [[ "$status" == "BOND_STATUS_BONDED" && "$jailed" == "false" ]] && echo "PASS validator_bonded_unjailed" || echo "WARN validator_not_active status=${status} jailed=${jailed}"
  fi
fi

if [[ "$fail" -gt 0 ]]; then
  echo "Result: FAIL failures=${fail}"
  exit 1
fi

echo "Result: PASS"
