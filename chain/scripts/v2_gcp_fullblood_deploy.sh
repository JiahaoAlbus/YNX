#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_gcp_fullblood_deploy.sh <ssh_user> <ssh_key_path> [project_id]

Create and deploy a full-blood YNX v2 stack on GCP:
  - bootstrap node (validator + full stack)
  - rpc follower node (full stack, follows bootstrap chain)
  - service follower node (full stack, follows bootstrap chain)

Defaults:
  project_id: ynx-testnet-gcp
  BILLING_ACCOUNT: 01562C-E2CAC9-5704C6
  REGION: asia-east2
  ZONE: asia-east2-b
  MACHINE_TYPE: e2-standard-4
  BOOT_DISK_GB: 80
  BASE_DOMAIN: empty (uses IP endpoints)

Environment:
  BILLING_ACCOUNT
  REGION
  ZONE
  MACHINE_TYPE
  BOOT_DISK_GB
  SKIP_GCLOUD_PROVISION   default: 0 (set 1 to reuse existing VM IPs)
  BOOTSTRAP_IP_OVERRIDE   required when SKIP_GCLOUD_PROVISION=1
  RPC_IP_OVERRIDE         required when SKIP_GCLOUD_PROVISION=1
  SVC_IP_OVERRIDE         required when SKIP_GCLOUD_PROVISION=1
  BASE_DOMAIN
  YNX_CHAIN_ID
  YNX_EVM_CHAIN_ID
  WEB4_INTERNAL_TOKEN
  INSTALL_WATCHDOG        default: 1
  INSTALL_BACKUP          default: 1
  BACKUP_MAX_KEEP         default: 14
  INCLUDE_CHAIN_DATA      default: 0
  ALERT_WEBHOOK_URL       optional
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SSH_USER="${1:-}"
SSH_KEY="${2:-}"
PROJECT_ID="${3:-ynx-testnet-gcp}"

if [[ -z "$SSH_USER" || -z "$SSH_KEY" ]]; then
  usage
  exit 1
fi
if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key not found: $SSH_KEY" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOY_SCRIPT="$ROOT_DIR/chain/scripts/v2_public_testnet_deploy.sh"
VERIFY_SCRIPT="$ROOT_DIR/chain/scripts/v2_public_testnet_verify.sh"
CLUSTER_VERIFY_SCRIPT="$ROOT_DIR/chain/scripts/v2_cluster_sync_verify.sh"

if [[ ! -x "$DEPLOY_SCRIPT" ]]; then
  echo "Missing deploy script: $DEPLOY_SCRIPT" >&2
  exit 1
fi
if [[ ! -x "$CLUSTER_VERIFY_SCRIPT" ]]; then
  chmod +x "$CLUSTER_VERIFY_SCRIPT" >/dev/null 2>&1 || true
fi
if [[ ! -x "$CLUSTER_VERIFY_SCRIPT" ]]; then
  echo "Missing verify script: $CLUSTER_VERIFY_SCRIPT" >&2
  exit 1
fi
if [[ "${SKIP_GCLOUD_PROVISION:-0}" != "1" ]]; then
  if ! command -v gcloud >/dev/null 2>&1 && [[ -x "$HOME/google-cloud-sdk/bin/gcloud" ]]; then
    export PATH="$HOME/google-cloud-sdk/bin:$PATH"
  fi
  if ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud is required but not found in PATH." >&2
    exit 1
  fi
fi
if ! command -v ssh >/dev/null 2>&1 || ! command -v scp >/dev/null 2>&1; then
  echo "ssh/scp are required." >&2
  exit 1
fi

BILLING_ACCOUNT="${BILLING_ACCOUNT:-01562C-E2CAC9-5704C6}"
REGION="${REGION:-asia-east2}"
ZONE="${ZONE:-asia-east2-b}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-4}"
BOOT_DISK_GB="${BOOT_DISK_GB:-80}"
SKIP_GCLOUD_PROVISION="${SKIP_GCLOUD_PROVISION:-0}"
BOOTSTRAP_IP_OVERRIDE="${BOOTSTRAP_IP_OVERRIDE:-}"
RPC_IP_OVERRIDE="${RPC_IP_OVERRIDE:-}"
SVC_IP_OVERRIDE="${SVC_IP_OVERRIDE:-}"
BASE_DOMAIN="${BASE_DOMAIN:-}"
YNX_CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
YNX_EVM_CHAIN_ID="${YNX_EVM_CHAIN_ID:-9102}"
WEB4_INTERNAL_TOKEN="${WEB4_INTERNAL_TOKEN:-ynx-v2-internal}"
INSTALL_WATCHDOG="${INSTALL_WATCHDOG:-1}"
INSTALL_BACKUP="${INSTALL_BACKUP:-1}"
BACKUP_MAX_KEEP="${BACKUP_MAX_KEEP:-14}"
INCLUDE_CHAIN_DATA="${INCLUDE_CHAIN_DATA:-0}"
ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"

BOOTSTRAP_NAME="ynx-v2-bootstrap-1"
RPC_NAME="ynx-v2-rpc-1"
SVC_NAME="ynx-v2-service-1"
FW_RULE="ynx-v2-public"

if [[ "$SKIP_GCLOUD_PROVISION" != "1" ]]; then
  echo "==> Checking gcloud auth..."
  ACTIVE_ACCT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' || true)"
  if [[ -z "$ACTIVE_ACCT" ]]; then
    echo "No active gcloud account. Run: gcloud auth login" >&2
    exit 1
  fi
  echo "Active account: $ACTIVE_ACCT"

  echo "==> Ensuring project exists: $PROJECT_ID"
  if ! gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    gcloud projects create "$PROJECT_ID"
  fi
  gcloud config set project "$PROJECT_ID" >/dev/null
  gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT" >/dev/null

  echo "==> Enabling required APIs..."
  gcloud services enable \
    compute.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    logging.googleapis.com \
    monitoring.googleapis.com >/dev/null

  echo "==> Ensuring firewall rule..."
  if ! gcloud compute firewall-rules describe "$FW_RULE" --project "$PROJECT_ID" >/dev/null 2>&1; then
    gcloud compute firewall-rules create "$FW_RULE" \
      --project "$PROJECT_ID" \
      --network default \
      --allow tcp:22,tcp:36656,tcp:36657,tcp:31317,tcp:39090,tcp:38545,tcp:38546,tcp:38080,tcp:38081,tcp:38082,tcp:38090,tcp:38091 \
      --source-ranges 0.0.0.0/0 >/dev/null
  fi
fi

ensure_instance() {
  local name="$1"
  local tag="$2"
  if gcloud compute instances describe "$name" --zone "$ZONE" --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Instance exists: $name"
    return 0
  fi
  echo "Creating instance: $name"
  gcloud compute instances create "$name" \
    --project "$PROJECT_ID" \
    --zone "$ZONE" \
    --machine-type "$MACHINE_TYPE" \
    --create-disk "auto-delete=yes,boot=yes,device-name=${name},image-family=ubuntu-2204-lts,image-project=ubuntu-os-cloud,size=${BOOT_DISK_GB},type=pd-standard" \
    --tags "$tag" \
    --metadata-from-file ssh-keys=<(printf '%s:%s\n' "$SSH_USER" "$(cat "${SSH_KEY}.pub" 2>/dev/null || true)") \
    --scopes cloud-platform >/dev/null
}

if [[ ! -f "${SSH_KEY}.pub" ]]; then
  echo "Missing public key: ${SSH_KEY}.pub" >&2
  echo "Generate it with: ssh-keygen -y -f $SSH_KEY > ${SSH_KEY}.pub" >&2
  exit 1
fi

if [[ "$SKIP_GCLOUD_PROVISION" == "1" ]]; then
  if [[ -z "$BOOTSTRAP_IP_OVERRIDE" || -z "$RPC_IP_OVERRIDE" || -z "$SVC_IP_OVERRIDE" ]]; then
    echo "When SKIP_GCLOUD_PROVISION=1, BOOTSTRAP_IP_OVERRIDE/RPC_IP_OVERRIDE/SVC_IP_OVERRIDE are required." >&2
    exit 1
  fi
  BOOTSTRAP_IP="$BOOTSTRAP_IP_OVERRIDE"
  RPC_IP="$RPC_IP_OVERRIDE"
  SVC_IP="$SVC_IP_OVERRIDE"
else
  ensure_instance "$BOOTSTRAP_NAME" "ynx-v2"
  ensure_instance "$RPC_NAME" "ynx-v2"
  ensure_instance "$SVC_NAME" "ynx-v2"

  BOOTSTRAP_IP="$(gcloud compute instances describe "$BOOTSTRAP_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
  RPC_IP="$(gcloud compute instances describe "$RPC_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
  SVC_IP="$(gcloud compute instances describe "$SVC_NAME" --zone "$ZONE" --project "$PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')"
fi

echo "Bootstrap IP: $BOOTSTRAP_IP"
echo "RPC IP:       $RPC_IP"
echo "Service IP:   $SVC_IP"

run_deploy() {
  local host_ip="$1"
  local seeds_override="${2:-}"
  local peers_override="${3:-$seeds_override}"
  echo "Deploying full stack to $host_ip ..."
  local -a deploy_env=(
    "YNX_CHAIN_ID=$YNX_CHAIN_ID"
    "YNX_EVM_CHAIN_ID=$YNX_EVM_CHAIN_ID"
    "WEB4_INTERNAL_TOKEN=$WEB4_INTERNAL_TOKEN"
  )
  if [[ -n "$seeds_override" ]]; then
    deploy_env+=("YNX_SEEDS_OVERRIDE=$seeds_override")
  fi
  if [[ -n "$peers_override" ]]; then
    deploy_env+=("YNX_PERSISTENT_PEERS_OVERRIDE=$peers_override")
  fi
  env "${deploy_env[@]}" \
    "$DEPLOY_SCRIPT" "${SSH_USER}@${host_ip}" "$SSH_KEY" --reset --smoke-write --from-remote-git
}

install_ops_services() {
  local host_ip="$1"
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${host_ip}" "bash -s" <<EOF
set -euo pipefail
if [[ "${INSTALL_WATCHDOG}" == "1" ]]; then
  YNX_REPO_DIR=~/YNX \
  USER_NAME="${SSH_USER}" \
  RPC_URL="http://127.0.0.1:36657" \
  INDEXER_URL="http://127.0.0.1:38081" \
  ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL}" \
  bash ~/YNX/chain/scripts/install_v2_watchdog_systemd.sh
fi
if [[ "${INSTALL_BACKUP}" == "1" ]]; then
  YNX_REPO_DIR=~/YNX \
  USER_NAME="${SSH_USER}" \
  YNX_HOME=~/.ynx-v2 \
  BACKUP_MAX_KEEP="${BACKUP_MAX_KEEP}" \
  INCLUDE_CHAIN_DATA="${INCLUDE_CHAIN_DATA}" \
  bash ~/YNX/chain/scripts/install_v2_backup_systemd.sh
fi
EOF
}

echo "==> Deploy bootstrap node..."
run_deploy "$BOOTSTRAP_IP"

echo "==> Reading bootstrap node info..."
BOOTSTRAP_NODE_ID="$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${BOOTSTRAP_IP}" '~/YNX/chain/ynxd comet show-node-id --home ~/.ynx-v2' | tr -d '\r\n')"
BOOTSTRAP_SEED="${BOOTSTRAP_NODE_ID}@${BOOTSTRAP_IP}:36656"

TMP_GENESIS="$(mktemp)"
scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${BOOTSTRAP_IP}:~/\.ynx-v2/config/genesis.json" "$TMP_GENESIS"

join_follower() {
  local host_ip="$1"
  echo "Deploy follower stack to $host_ip ..."
  run_deploy "$host_ip" "$BOOTSTRAP_SEED" "$BOOTSTRAP_SEED"

  echo "Syncing follower $host_ip to bootstrap chain..."
  scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$TMP_GENESIS" "${SSH_USER}@${host_ip}:~/genesis.json"

  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${host_ip}" "bash -s" <<EOF
set -euo pipefail
sudo systemctl stop ynx-v2-node.service || true
cp ~/genesis.json ~/.ynx-v2/config/genesis.json
~/YNX/chain/ynxd comet unsafe-reset-all --home ~/.ynx-v2 --keep-addr-book >/dev/null
sed -i.bak 's#^seeds = .*#seeds = "${BOOTSTRAP_SEED}"#' ~/.ynx-v2/config/config.toml
sed -i.bak 's#^persistent_peers = .*#persistent_peers = "${BOOTSTRAP_SEED}"#' ~/.ynx-v2/config/config.toml
if grep -q '^YNX_SEEDS=' /etc/ynx-v2/env; then
  sudo sed -i 's#^YNX_SEEDS=.*#YNX_SEEDS=${BOOTSTRAP_SEED}#' /etc/ynx-v2/env
else
  echo 'YNX_SEEDS=${BOOTSTRAP_SEED}' | sudo tee -a /etc/ynx-v2/env >/dev/null
fi
if grep -q '^YNX_PERSISTENT_PEERS=' /etc/ynx-v2/env; then
  sudo sed -i 's#^YNX_PERSISTENT_PEERS=.*#YNX_PERSISTENT_PEERS=${BOOTSTRAP_SEED}#' /etc/ynx-v2/env
else
  echo 'YNX_PERSISTENT_PEERS=${BOOTSTRAP_SEED}' | sudo tee -a /etc/ynx-v2/env >/dev/null
fi
sudo systemctl daemon-reload
sudo systemctl restart ynx-v2-node.service
EOF
}

echo "==> Deploy follower nodes..."
join_follower "$RPC_IP"
join_follower "$SVC_IP"

rm -f "$TMP_GENESIS"

echo "==> Installing watchdog/backup services..."
install_ops_services "$BOOTSTRAP_IP"
install_ops_services "$RPC_IP"
install_ops_services "$SVC_IP"

echo "==> Verifying cluster sync..."
"$CLUSTER_VERIFY_SCRIPT" "$BOOTSTRAP_IP" "$RPC_IP" "$SVC_IP"

echo "==> Verifying public stack on bootstrap/rpc/service..."
for host in "$BOOTSTRAP_IP" "$RPC_IP" "$SVC_IP"; do
  YNX_PUBLIC_HOST="$host" \
  YNX_CHAIN_ID="$YNX_CHAIN_ID" \
  YNX_RPC_PORT="36657" \
  YNX_EVM_PORT="38545" \
  YNX_REST_PORT="31317" \
  YNX_FAUCET_PORT="38080" \
  YNX_INDEXER_PORT="38081" \
  YNX_EXPLORER_PORT="38082" \
  YNX_AI_GATEWAY_PORT="38090" \
  YNX_WEB4_PORT="38091" \
  YNX_SMOKE_WRITE="1" \
  "$VERIFY_SCRIPT"
done

echo
echo "=== GCP Full-blood testnet is up ==="
echo "Project:     $PROJECT_ID"
echo "Bootstrap:   $BOOTSTRAP_IP"
echo "RPC:         $RPC_IP"
echo "Service:     $SVC_IP"
echo
if [[ -n "$BASE_DOMAIN" ]]; then
  echo "Set DNS A records:"
  echo "  rpc.${BASE_DOMAIN}      -> ${RPC_IP}"
  echo "  evm.${BASE_DOMAIN}      -> ${RPC_IP}"
  echo "  evm-ws.${BASE_DOMAIN}   -> ${RPC_IP}"
  echo "  rest.${BASE_DOMAIN}     -> ${SVC_IP}"
  echo "  faucet.${BASE_DOMAIN}   -> ${SVC_IP}"
  echo "  indexer.${BASE_DOMAIN}  -> ${SVC_IP}"
  echo "  explorer.${BASE_DOMAIN} -> ${SVC_IP}"
  echo "  ai.${BASE_DOMAIN}       -> ${SVC_IP}"
  echo "  web4.${BASE_DOMAIN}     -> ${SVC_IP}"
fi
