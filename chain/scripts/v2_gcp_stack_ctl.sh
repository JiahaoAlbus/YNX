#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_gcp_stack_ctl.sh status
  v2_gcp_stack_ctl.sh start
  v2_gcp_stack_ctl.sh stop
  v2_gcp_stack_ctl.sh restart
  v2_gcp_stack_ctl.sh mode <economy|balanced|extreme>
  v2_gcp_stack_ctl.sh rightsize <machine-type> [instance...]

Environment:
  PROJECT_ID            default: ynx-testnet-gcp
  ZONE                  default: asia-east2-b
  INSTANCES             default: ynx-v2-bootstrap-1,ynx-v2-rpc-1,ynx-v2-service-1
  GCLOUD_CMD            default: chain/scripts/gcloud_ipv4.sh
  STACK_READY_TIMEOUT   default: 240 seconds

Notes:
  - Stopping instances does NOT require redeploy. Data stays on persistent disks.
  - On start, services auto-recover because systemd units are enabled.
  - "mode extreme" targets highest sustained throughput (higher cost).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "$#" -lt 1 ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ID="${PROJECT_ID:-ynx-testnet-gcp}"
ZONE="${ZONE:-asia-east2-b}"
GCLOUD_CMD="${GCLOUD_CMD:-${SCRIPT_DIR}/gcloud_ipv4.sh}"
STACK_READY_TIMEOUT="${STACK_READY_TIMEOUT:-240}"
INSTANCE_CSV="${INSTANCES:-ynx-v2-bootstrap-1,ynx-v2-rpc-1,ynx-v2-service-1}"

IFS=',' read -r -a DEFAULT_INSTANCES <<< "${INSTANCE_CSV}"

if [[ ! -x "${GCLOUD_CMD}" ]]; then
  echo "gcloud wrapper not executable: ${GCLOUD_CMD}" >&2
  exit 1
fi

gcloud_cmd() {
  "${GCLOUD_CMD}" "$@"
}

get_running_instances() {
  gcloud_cmd compute instances list \
    --project "${PROJECT_ID}" \
    --filter "zone:(${ZONE}) AND (name~'^ynx-v2-(bootstrap|rpc|service)-1$')" \
    --format "value(name,status)" \
    | awk '$2=="RUNNING"{print $1}'
}

wait_http_ok() {
  local url="$1"
  local seconds="${2:-120}"
  local start_ts now
  start_ts="$(date +%s)"
  while true; do
    if curl -fsS --max-time 5 "${url}" >/dev/null 2>&1; then
      return 0
    fi
    now="$(date +%s)"
    if (( now - start_ts >= seconds )); then
      echo "Timeout waiting for ${url}" >&2
      return 1
    fi
    sleep 3
  done
}

check_endpoint_ok() {
  local url="$1"
  if [[ "${url}" == "https://evm.ynxweb4.com" ]]; then
    curl -fsS --max-time 5 \
      -H "content-type: application/json" \
      --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
      "${url}" >/dev/null 2>&1
    return $?
  fi
  curl -fsS --max-time 5 "${url}" >/dev/null 2>&1
}

wait_stack_ready() {
  local timeout="${1:-${STACK_READY_TIMEOUT}}"
  wait_http_ok "https://rpc.ynxweb4.com/status" "${timeout}"
  local start_ts now
  start_ts="$(date +%s)"
  while true; do
    if check_endpoint_ok "https://evm.ynxweb4.com"; then
      break
    fi
    now="$(date +%s)"
    if (( now - start_ts >= timeout )); then
      echo "Timeout waiting for https://evm.ynxweb4.com" >&2
      return 1
    fi
    sleep 3
  done
  wait_http_ok "https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info" "${timeout}"
  wait_http_ok "https://faucet.ynxweb4.com/health" "${timeout}"
  wait_http_ok "https://indexer.ynxweb4.com/health" "${timeout}"
  wait_http_ok "https://ai.ynxweb4.com/ready" "${timeout}"
  wait_http_ok "https://web4.ynxweb4.com/ready" "${timeout}"
}

status_cmd() {
  gcloud_cmd compute instances list \
    --project "${PROJECT_ID}" \
    --filter "zone:(${ZONE}) AND (name~'^ynx-v2-(bootstrap|rpc|service)-1$')" \
    --format "table(name,machineType.basename(),status,networkInterfaces[0].networkIP,networkInterfaces[0].accessConfigs[0].natIP)"
  echo
  echo "Public endpoints:"
  for u in \
    "https://rpc.ynxweb4.com/status" \
    "https://evm.ynxweb4.com" \
    "https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info" \
    "https://faucet.ynxweb4.com/health" \
    "https://indexer.ynxweb4.com/health" \
    "https://ai.ynxweb4.com/ready" \
    "https://web4.ynxweb4.com/ready"; do
    if check_endpoint_ok "${u}"; then
      echo "  OK   ${u}"
    else
      echo "  FAIL ${u}"
    fi
  done
}

start_cmd() {
  gcloud_cmd compute instances start "${DEFAULT_INSTANCES[@]}" \
    --project "${PROJECT_ID}" \
    --zone "${ZONE}"
  wait_stack_ready "${STACK_READY_TIMEOUT}"
  echo "Stack is ready."
}

stop_cmd() {
  gcloud_cmd compute instances stop "${DEFAULT_INSTANCES[@]}" \
    --project "${PROJECT_ID}" \
    --zone "${ZONE}"
  echo "Instances stopped."
}

restart_cmd() {
  stop_cmd
  start_cmd
}

rightsize_cmd() {
  local machine_type="${1:-}"
  shift || true
  if [[ -z "${machine_type}" ]]; then
    echo "Missing machine type." >&2
    usage
    exit 1
  fi

  local targets=()
  if [[ "$#" -gt 0 ]]; then
    targets=("$@")
  else
    targets=("${DEFAULT_INSTANCES[@]}")
  fi

  for inst in "${targets[@]}"; do
    local st
    st="$(gcloud_cmd compute instances describe "${inst}" --project "${PROJECT_ID}" --zone "${ZONE}" --format 'value(status)')"
    if [[ "${st}" == "RUNNING" ]]; then
      gcloud_cmd compute instances stop "${inst}" --project "${PROJECT_ID}" --zone "${ZONE}"
    fi
    gcloud_cmd compute instances set-machine-type "${inst}" \
      --project "${PROJECT_ID}" \
      --zone "${ZONE}" \
      --machine-type "${machine_type}"
    gcloud_cmd compute instances start "${inst}" --project "${PROJECT_ID}" --zone "${ZONE}"
  done

  wait_stack_ready "${STACK_READY_TIMEOUT}"
  echo "Resizing complete. New type: ${machine_type}"
}

mode_cmd() {
  local mode="${1:-}"
  if [[ -z "${mode}" ]]; then
    echo "Missing mode." >&2
    usage
    exit 1
  fi

  local bootstrap_type=""
  local rpc_type=""
  local service_type=""

  case "${mode}" in
    economy)
      bootstrap_type="${YNX_MODE_ECON_BOOTSTRAP:-e2-standard-2}"
      rpc_type="${YNX_MODE_ECON_RPC:-e2-standard-2}"
      service_type="${YNX_MODE_ECON_SERVICE:-e2-standard-2}"
      ;;
    balanced)
      bootstrap_type="${YNX_MODE_BAL_BOOTSTRAP:-e2-standard-4}"
      rpc_type="${YNX_MODE_BAL_RPC:-e2-standard-4}"
      service_type="${YNX_MODE_BAL_SERVICE:-e2-standard-4}"
      ;;
    extreme)
      bootstrap_type="${YNX_MODE_EXT_BOOTSTRAP:-e2-standard-8}"
      rpc_type="${YNX_MODE_EXT_RPC:-e2-standard-16}"
      service_type="${YNX_MODE_EXT_SERVICE:-e2-standard-16}"
      ;;
    *)
      echo "Unknown mode: ${mode}" >&2
      usage
      exit 1
      ;;
  esac

  echo "Applying mode '${mode}'"
  echo "  bootstrap=${bootstrap_type}"
  echo "  rpc=${rpc_type}"
  echo "  service=${service_type}"

  rightsize_cmd "${bootstrap_type}" "ynx-v2-bootstrap-1"
  rightsize_cmd "${rpc_type}" "ynx-v2-rpc-1"
  rightsize_cmd "${service_type}" "ynx-v2-service-1"

  echo "Mode '${mode}' applied."
}

cmd="${1}"
shift || true

case "${cmd}" in
  status) status_cmd ;;
  start) start_cmd ;;
  stop) stop_cmd ;;
  restart) restart_cmd ;;
  mode) mode_cmd "$@" ;;
  rightsize) rightsize_cmd "$@" ;;
  *)
    echo "Unknown command: ${cmd}" >&2
    usage
    exit 1
    ;;
esac
