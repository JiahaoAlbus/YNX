#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_profile_apply.sh <profile> [--restart]

Profiles:
  web4-fast-regional   Lower latency profile for same-region validators
  web4-global-stable   Cross-region safety-oriented profile

Environment:
  YNX_HOME      Node home path (default: chain/.testnet-v2)
  YNX_SERVICE   Optional systemd service to restart (required with --restart)

Examples:
  ./scripts/v2_profile_apply.sh web4-fast-regional
  YNX_HOME=/home/ubuntu/.ynx-v2 YNX_SERVICE=ynx-v2-node ./scripts/v2_profile_apply.sh web4-global-stable --restart
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

PROFILE="$1"
shift

DO_RESTART=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart)
      DO_RESTART=1
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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"
SERVICE_NAME="${YNX_SERVICE:-}"

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

if [[ ! -f "$CONFIG_TOML" ]]; then
  echo "config.toml not found: $CONFIG_TOML" >&2
  exit 1
fi
if [[ ! -f "$APP_TOML" ]]; then
  echo "app.toml not found: $APP_TOML" >&2
  exit 1
fi

case "$PROFILE" in
  web4-fast-regional)
    timeout_propose="900ms"
    timeout_propose_delta="200ms"
    timeout_vote="400ms"
    timeout_vote_delta="150ms"
    timeout_commit="800ms"
    max_txs_bytes="31457280"
    max_num_inbound_peers="80"
    max_num_outbound_peers="40"
    ;;
  web4-global-stable)
    timeout_propose="2s"
    timeout_propose_delta="500ms"
    timeout_vote="1s"
    timeout_vote_delta="300ms"
    timeout_commit="2s"
    max_txs_bytes="20971520"
    max_num_inbound_peers="60"
    max_num_outbound_peers="30"
    ;;
  *)
    echo "Unknown profile: $PROFILE" >&2
    usage
    exit 1
    ;;
esac

echo "Applying v2 profile: $PROFILE"
echo "Home: $HOME_DIR"

sed -i.bak -E "s/^timeout_propose = .*/timeout_propose = \"${timeout_propose}\"/" "$CONFIG_TOML"
sed -i.bak -E "s/^timeout_propose_delta = .*/timeout_propose_delta = \"${timeout_propose_delta}\"/" "$CONFIG_TOML"
if grep -q '^timeout_vote = ' "$CONFIG_TOML"; then
  sed -i.bak -E "s/^timeout_vote = .*/timeout_vote = \"${timeout_vote}\"/" "$CONFIG_TOML"
  sed -i.bak -E "s/^timeout_vote_delta = .*/timeout_vote_delta = \"${timeout_vote_delta}\"/" "$CONFIG_TOML"
else
  sed -i.bak -E "s/^timeout_prevote = .*/timeout_prevote = \"${timeout_vote}\"/" "$CONFIG_TOML"
  sed -i.bak -E "s/^timeout_prevote_delta = .*/timeout_prevote_delta = \"${timeout_vote_delta}\"/" "$CONFIG_TOML"
  sed -i.bak -E "s/^timeout_precommit = .*/timeout_precommit = \"${timeout_vote}\"/" "$CONFIG_TOML"
  sed -i.bak -E "s/^timeout_precommit_delta = .*/timeout_precommit_delta = \"${timeout_vote_delta}\"/" "$CONFIG_TOML"
fi
sed -i.bak -E "s/^timeout_commit = .*/timeout_commit = \"${timeout_commit}\"/" "$CONFIG_TOML"
sed -i.bak -E "s/^max_txs_bytes = .*/max_txs_bytes = ${max_txs_bytes}/" "$CONFIG_TOML"
sed -i.bak -E "s/^max_num_inbound_peers = .*/max_num_inbound_peers = ${max_num_inbound_peers}/" "$CONFIG_TOML"
sed -i.bak -E "s/^max_num_outbound_peers = .*/max_num_outbound_peers = ${max_num_outbound_peers}/" "$CONFIG_TOML"

sed -i.bak -E '/^\[api\]$/,/^\[/ s/^enable = .*/enable = true/' "$APP_TOML" || true
sed -i.bak -E '/^\[grpc\]$/,/^\[/ s/^enable = .*/enable = true/' "$APP_TOML" || true
sed -i.bak -E '/^\[json-rpc\]$/,/^\[/ s/^enable = .*/enable = true/' "$APP_TOML" || true
sed -i.bak -E "s#^address = \"127.0.0.1:8545\"#address = \"0.0.0.0:8545\"#" "$APP_TOML" || true
sed -i.bak -E "s#^ws-address = \"127.0.0.1:8546\"#ws-address = \"0.0.0.0:8546\"#" "$APP_TOML" || true

echo "Applied consensus/network values:"
grep -n '^timeout_propose =\|^timeout_propose_delta =\|^timeout_vote =\|^timeout_vote_delta =\|^timeout_prevote =\|^timeout_prevote_delta =\|^timeout_precommit =\|^timeout_precommit_delta =\|^timeout_commit =\|^max_txs_bytes =\|^max_num_inbound_peers =\|^max_num_outbound_peers =' "$CONFIG_TOML"

if [[ "$DO_RESTART" -eq 1 ]]; then
  if [[ -z "$SERVICE_NAME" ]]; then
    echo "YNX_SERVICE is required with --restart" >&2
    exit 1
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl not found; cannot restart service" >&2
    exit 1
  fi
  systemctl restart "$SERVICE_NAME"
  systemctl --no-pager --full status "$SERVICE_NAME" | sed -n '1,20p'
fi

echo "Done."
