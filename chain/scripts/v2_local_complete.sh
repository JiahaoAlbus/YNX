#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_local_complete.sh <command>

Commands:
  up            bootstrap + start full v2 local stack
  compose-up    bootstrap/build/start full v2 stack with Docker Compose
  compose-down  stop Docker Compose v2 stack
  compose-logs  follow Docker Compose v2 stack logs
  verify        run v2 read verification
  smoke         run v2 write-path smoke
  verify-smoke  run verify with smoke (YNX_SMOKE_WRITE=1)
  pack          build v2 release bundle
  company-pack  build company-ready local handoff bundle
  multinode     bootstrap/start v2 local multi-validator simulation
  down          stop v2 local stack
  all           up + verify-smoke + pack + company-pack

Environment:
  YNX_PROFILE            default: web4-fast-regional
  YNX_PUBLIC_HOST        default: 127.0.0.1
  YNX_VALIDATOR_COUNT    used by multinode (default: 4)
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${YNX_PROFILE:-web4-fast-regional}"
HOST="${YNX_PUBLIC_HOST:-127.0.0.1}"
CMD="${1:-}"

if [[ -z "$CMD" || "$CMD" == "-h" || "$CMD" == "--help" ]]; then
  usage
  exit 0
fi

case "$CMD" in
  up)
    "$ROOT_DIR/scripts/v2_testnet_bootstrap.sh" --profile "$PROFILE"
    "$ROOT_DIR/scripts/v2_services_start.sh"
    ;;
  compose-up)
    "$ROOT_DIR/scripts/v2_local_compose.sh" up
    ;;
  compose-down)
    "$ROOT_DIR/scripts/v2_local_compose.sh" down
    ;;
  compose-logs)
    "$ROOT_DIR/scripts/v2_local_compose.sh" logs
    ;;
  verify)
    YNX_PUBLIC_HOST="$HOST" "$ROOT_DIR/scripts/v2_public_testnet_verify.sh"
    ;;
  smoke)
    YNX_PUBLIC_HOST="$HOST" "$ROOT_DIR/scripts/v2_public_testnet_smoke.sh"
    ;;
  verify-smoke)
    YNX_PUBLIC_HOST="$HOST" YNX_SMOKE_WRITE=1 "$ROOT_DIR/scripts/v2_public_testnet_verify.sh"
    ;;
  pack)
    "$ROOT_DIR/scripts/v2_testnet_release.sh"
    ;;
  company-pack)
    "$ROOT_DIR/scripts/v2_company_pack.sh"
    ;;
  multinode)
    "$ROOT_DIR/scripts/v2_testnet_multinode.sh" --reset --start --validators "${YNX_VALIDATOR_COUNT:-4}"
    ;;
  down)
    "$ROOT_DIR/scripts/v2_services_stop.sh"
    ;;
  all)
    "$ROOT_DIR/scripts/v2_testnet_bootstrap.sh" --profile "$PROFILE"
    "$ROOT_DIR/scripts/v2_services_start.sh"
    YNX_PUBLIC_HOST="$HOST" YNX_SMOKE_WRITE=1 "$ROOT_DIR/scripts/v2_public_testnet_verify.sh"
    "$ROOT_DIR/scripts/v2_testnet_release.sh"
    "$ROOT_DIR/scripts/v2_company_pack.sh"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 1
    ;;
esac
