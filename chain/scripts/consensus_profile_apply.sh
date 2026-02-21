#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  consensus_profile_apply.sh <profile> [--restart]

Profiles:
  stable-fast            1s / 500ms / 1s
  cross-continent-safe   3s / 2s / 5s

Environment:
  YNX_HOME      Node home path (default: chain/.testnet)
  YNX_SERVICE   Optional service name to restart when --restart is set
                (example: ynx-node or ynx-node2)

Examples:
  ./scripts/consensus_profile_apply.sh stable-fast
  YNX_HOME=/home/ubuntu/.ynx-testnet YNX_SERVICE=ynx-node ./scripts/consensus_profile_apply.sh stable-fast --restart
  YNX_HOME=/root/.ynx-testnet2 YNX_SERVICE=ynx-node2 ./scripts/consensus_profile_apply.sh cross-continent-safe --restart
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
YNX_HOME="${YNX_HOME:-$ROOT_DIR/.testnet}"
CONFIG="$YNX_HOME/config/config.toml"
YNX_SERVICE="${YNX_SERVICE:-}"

if [[ ! -f "$CONFIG" ]]; then
  echo "config.toml not found: $CONFIG" >&2
  exit 1
fi

case "$PROFILE" in
  stable-fast)
    timeout_propose="1s"
    timeout_propose_delta="200ms"
    timeout_vote="500ms"
    timeout_vote_delta="200ms"
    timeout_commit="1s"
    ;;
  cross-continent-safe)
    timeout_propose="3s"
    timeout_propose_delta="1s"
    timeout_vote="2s"
    timeout_vote_delta="1s"
    timeout_commit="5s"
    ;;
  *)
    echo "Unknown profile: $PROFILE" >&2
    usage
    exit 1
    ;;
esac

echo "Applying profile: $PROFILE"
echo "Config: $CONFIG"

sed -i.bak -E "s/^timeout_propose = .*/timeout_propose = \"${timeout_propose}\"/" "$CONFIG"
sed -i.bak -E "s/^timeout_propose_delta = .*/timeout_propose_delta = \"${timeout_propose_delta}\"/" "$CONFIG"
if grep -q '^timeout_vote = ' "$CONFIG"; then
  sed -i.bak -E "s/^timeout_vote = .*/timeout_vote = \"${timeout_vote}\"/" "$CONFIG"
  sed -i.bak -E "s/^timeout_vote_delta = .*/timeout_vote_delta = \"${timeout_vote_delta}\"/" "$CONFIG"
else
  sed -i.bak -E "s/^timeout_prevote = .*/timeout_prevote = \"${timeout_vote}\"/" "$CONFIG"
  sed -i.bak -E "s/^timeout_prevote_delta = .*/timeout_prevote_delta = \"${timeout_vote_delta}\"/" "$CONFIG"
  sed -i.bak -E "s/^timeout_precommit = .*/timeout_precommit = \"${timeout_vote}\"/" "$CONFIG"
  sed -i.bak -E "s/^timeout_precommit_delta = .*/timeout_precommit_delta = \"${timeout_vote_delta}\"/" "$CONFIG"
fi
sed -i.bak -E "s/^timeout_commit = .*/timeout_commit = \"${timeout_commit}\"/" "$CONFIG"

echo "Applied values:"
grep -n '^timeout_propose =\|^timeout_propose_delta =\|^timeout_vote =\|^timeout_vote_delta =\|^timeout_prevote =\|^timeout_prevote_delta =\|^timeout_precommit =\|^timeout_precommit_delta =\|^timeout_commit =' "$CONFIG"

if [[ "$DO_RESTART" -eq 1 ]]; then
  if [[ -z "$YNX_SERVICE" ]]; then
    echo "YNX_SERVICE is required when using --restart" >&2
    exit 1
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    echo "systemctl not found; restart skipped" >&2
    exit 1
  fi
  echo "Restarting service: $YNX_SERVICE"
  systemctl restart "$YNX_SERVICE"
  echo "Service status:"
  systemctl --no-pager --full status "$YNX_SERVICE" | sed -n '1,20p'
fi

echo "Done."
