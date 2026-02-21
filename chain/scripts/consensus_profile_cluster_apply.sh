#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  consensus_profile_cluster_apply.sh <profile>

Applies a consensus profile to both validator servers, restarts services,
waits, then runs signing-rate and status checks.

Profiles:
  stable-fast
  cross-continent-safe

Environment (override when needed):
  NODE1_HOST                default: 43.134.23.58
  NODE1_USER                default: ubuntu
  NODE1_KEY                 default: /Users/huangjiahao/Downloads/Huang.pem
  NODE1_CHAIN_DIR           default: ~/YNX/chain
  NODE1_HOME                default: /home/ubuntu/.ynx-testnet
  NODE1_SERVICE             default: ynx-node

  NODE2_HOST                default: 43.162.100.54
  NODE2_USER                default: root
  NODE2_KEY                 default: ~/.ssh/ynx_tmp_key
  NODE2_CHAIN_DIR           default: /root/YNX/chain
  NODE2_HOME                default: /root/.ynx-testnet2
  NODE2_SERVICE             default: ynx-node2

  SG2_CONS_ADDR             default: 18F94411A012D3BB09A89BFBB4DEB2FD8B4EFF16
  SG2_VALOPER               default: ynxvaloper1kxut2r0ym0gwx80f5knlk024dmdu0nrdyfqcun
  WAIT_SECS                 default: 30
  SPEED_SAMPLE_SECS         default: 30
  SIGN_WINDOW               default: 50
  MIN_SIGNED_PERCENT        default: 90

Example:
  ./scripts/consensus_profile_cluster_apply.sh stable-fast
EOF
}

if [[ $# -lt 1 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit $([[ $# -lt 1 ]] && echo 1 || echo 0)
fi

PROFILE="$1"

NODE1_HOST="${NODE1_HOST:-43.134.23.58}"
NODE1_USER="${NODE1_USER:-ubuntu}"
NODE1_KEY="${NODE1_KEY:-/Users/huangjiahao/Downloads/Huang.pem}"
NODE1_CHAIN_DIR="${NODE1_CHAIN_DIR:-~/YNX/chain}"
NODE1_HOME="${NODE1_HOME:-/home/ubuntu/.ynx-testnet}"
NODE1_SERVICE="${NODE1_SERVICE:-ynx-node}"

NODE2_HOST="${NODE2_HOST:-43.162.100.54}"
NODE2_USER="${NODE2_USER:-root}"
NODE2_KEY="${NODE2_KEY:-~/.ssh/ynx_tmp_key}"
NODE2_CHAIN_DIR="${NODE2_CHAIN_DIR:-/root/YNX/chain}"
NODE2_HOME="${NODE2_HOME:-/root/.ynx-testnet2}"
NODE2_SERVICE="${NODE2_SERVICE:-ynx-node2}"

SG2_CONS_ADDR="${SG2_CONS_ADDR:-18F94411A012D3BB09A89BFBB4DEB2FD8B4EFF16}"
SG2_VALOPER="${SG2_VALOPER:-ynxvaloper1kxut2r0ym0gwx80f5knlk024dmdu0nrdyfqcun}"
WAIT_SECS="${WAIT_SECS:-30}"
SPEED_SAMPLE_SECS="${SPEED_SAMPLE_SECS:-30}"
SIGN_WINDOW="${SIGN_WINDOW:-50}"
MIN_SIGNED_PERCENT="${MIN_SIGNED_PERCENT:-90}"

case "$PROFILE" in
  stable-fast|cross-continent-safe) ;;
  *)
    echo "Unknown profile: $PROFILE" >&2
    exit 1
    ;;
esac

echo "[1/4] Apply profile '$PROFILE' on node1: $NODE1_HOST"
ssh -o ConnectTimeout=12 -o StrictHostKeyChecking=no -i "$NODE1_KEY" "${NODE1_USER}@${NODE1_HOST}" \
  "cd $NODE1_CHAIN_DIR && sudo -E YNX_HOME=$NODE1_HOME YNX_SERVICE=$NODE1_SERVICE ./scripts/consensus_profile_apply.sh $PROFILE --restart"

echo "[2/4] Apply profile '$PROFILE' on node2: $NODE2_HOST"
ssh -o ConnectTimeout=12 -o StrictHostKeyChecking=no -i "$NODE2_KEY" "${NODE2_USER}@${NODE2_HOST}" \
  "cd $NODE2_CHAIN_DIR && YNX_HOME=$NODE2_HOME YNX_SERVICE=$NODE2_SERVICE ./scripts/consensus_profile_apply.sh $PROFILE --restart"

echo "[3/4] Waiting ${WAIT_SECS}s for convergence..."
sleep "$WAIT_SECS"

echo "[4/4] Verifying validator status, signed ratio, and speed..."
report="$(
ssh -o ConnectTimeout=12 -o StrictHostKeyChecking=no -i "$NODE1_KEY" "${NODE1_USER}@${NODE1_HOST}" \
  "set -e; cd $NODE1_CHAIN_DIR; \
  STATUS=\$(./ynxd query staking validator $SG2_VALOPER --node http://127.0.0.1:26657 -o json | jq -r '.validator.status'); \
  JAILED=\$(./ynxd query staking validator $SG2_VALOPER --node http://127.0.0.1:26657 -o json | jq -r '.validator.jailed // false'); \
  L=\$(curl -s http://127.0.0.1:26657/status | jq -r '.result.sync_info.latest_block_height'); \
  S=\$((L-$SIGN_WINDOW+1)); C=0; \
  for h in \$(seq \$S \$L); do \
    f=\$(curl -s \"http://127.0.0.1:26657/block?height=\$h\" | jq -r --arg a \"$SG2_CONS_ADDR\" '.result.block.last_commit.signatures[]? | select(.validator_address==\$a) | .block_id_flag'); \
    [ \"\$f\" = \"2\" ] && C=\$((C+1)); \
  done; \
  h1=\$(curl -s http://127.0.0.1:26657/status | jq -r '.result.sync_info.latest_block_height'); \
  sleep $SPEED_SAMPLE_SECS; \
  h2=\$(curl -s http://127.0.0.1:26657/status | jq -r '.result.sync_info.latest_block_height'); \
  echo \"status=\$STATUS jailed=\$JAILED signed=\$C/$SIGN_WINDOW blocks_${SPEED_SAMPLE_SECS}s=\$((h2-h1))\""
)"

echo "$report"

signed_count="$(echo "$report" | sed -n 's/.*signed=\([0-9]\+\)\/[0-9]\+.*/\1/p')"
status_val="$(echo "$report" | sed -n 's/.*status=\([^ ]\+\).*/\1/p')"
jailed_val="$(echo "$report" | sed -n 's/.*jailed=\([^ ]\+\).*/\1/p')"

if [[ -z "$signed_count" || -z "$status_val" || -z "$jailed_val" ]]; then
  echo "Failed to parse verification report" >&2
  exit 1
fi

required_signed=$(( SIGN_WINDOW * MIN_SIGNED_PERCENT / 100 ))
if [[ "$status_val" != "BOND_STATUS_BONDED" || "$jailed_val" == "true" || "$signed_count" -lt "$required_signed" ]]; then
  echo "Profile check failed: status=$status_val jailed=$jailed_val signed=$signed_count/$SIGN_WINDOW (< ${MIN_SIGNED_PERCENT}%)" >&2
  exit 1
fi

echo "Profile '$PROFILE' applied and verified."
