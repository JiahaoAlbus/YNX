#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/server_public_acceptance.sh [--host ubuntu@43.153.202.237] [--key /path/to/Huang.pem]

Runs the YNX public-testnet acceptance commands on the Tencent Cloud server,
not on the local Mac. The server is expected to have the YNX repository at
/home/ubuntu/YNX.
EOF
}

HOST="ubuntu@43.153.202.237"
KEY="/Users/huangjiahao/Downloads/Huang.pem"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST="${2:-}"
      shift 2
      ;;
    --key)
      KEY="${2:-}"
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

ssh -i "$KEY" -o ConnectTimeout=10 "$HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
cd /home/ubuntu/YNX

echo "== YNX server acceptance =="
date -u
hostname
git rev-parse --short HEAD || true

echo
echo "== Core services =="
systemctl --no-pager --type=service | grep -i ynx || true

echo
echo "== Public security gate =="
scripts/public_security_gate.sh --output-dir "output/server_public_security_gate_$(date +%Y%m%d_%H%M%S)"

echo
echo "== Public readiness =="
scripts/public_testnet_extreme_readiness.sh --output-dir "output/server_public_readiness_$(date +%Y%m%d_%H%M%S)"

echo
echo "== Bridge full-loop probe =="
scripts/public_bridge_full_loop_probe.sh --output-dir "output/server_bridge_full_loop_$(date +%Y%m%d_%H%M%S)"

echo
echo "== AI on-chain settlement probe =="
scripts/public_ai_onchain_settlement_probe.sh --output-dir "output/server_ai_onchain_$(date +%Y%m%d_%H%M%S)"

echo
echo "== Uptime SLO single sample =="
scripts/public_uptime_slo_probe.sh --once

echo
echo "== AI latest transaction query =="
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"用中文简短总结 YNX 链上最后一次交易数据。"}' | jq
REMOTE
