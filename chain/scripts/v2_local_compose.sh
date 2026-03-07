#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_local_compose.sh up
  v2_local_compose.sh down
  v2_local_compose.sh logs
  v2_local_compose.sh ps
  v2_local_compose.sh build

Run the complete YNX v2 local stack with Docker Compose.

Requirements:
  - Docker
  - Docker Compose plugin
  - Go toolchain (only to build local linux binary/image if missing)
EOF
}

CMD="${1:-}"
if [[ -z "$CMD" || "$CMD" == "-h" || "$CMD" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/infra/docker-compose.v2-local.yml"
ENV_FILE="$PROJECT_ROOT/.env.v2.example"
IMAGE="${YNX_IMAGE:-ynx/ynxd:local}"
LINUX_BIN="$ROOT_DIR/ynxd-linux-amd64"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

ensure_image() {
  if docker image inspect "$IMAGE" >/dev/null 2>&1 && [[ -x "$LINUX_BIN" ]]; then
    return
  fi

  require_cmd go
  mkdir -p "$ROOT_DIR/.tmp/docker-ynxd"
  echo "Building linux binary for compose stack..."
  (
    cd "$ROOT_DIR"
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$LINUX_BIN" ./cmd/ynxd
  )

  cp "$LINUX_BIN" "$ROOT_DIR/.tmp/docker-ynxd/ynxd"
  echo "Building Docker image: $IMAGE"
  docker build -t "$IMAGE" -f - "$ROOT_DIR/.tmp/docker-ynxd" <<'EOF'
FROM scratch
COPY ynxd /usr/local/bin/ynxd
ENTRYPOINT ["/usr/local/bin/ynxd"]
EOF
}

bootstrap_local_home() {
  if [[ ! -f "$ROOT_DIR/.testnet-v2/config/genesis.json" ]]; then
    "$ROOT_DIR/scripts/v2_testnet_bootstrap.sh" --profile "${YNX_PROFILE:-web4-fast-regional}"
  fi
  "$ROOT_DIR/scripts/v2_ports_apply.sh"
}

require_cmd docker
docker compose version >/dev/null 2>&1 || {
  echo "Docker Compose plugin is required" >&2
  exit 1
}

case "$CMD" in
  up)
    bootstrap_local_home
    ensure_image
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
    ;;
  build)
    bootstrap_local_home
    ensure_image
    ;;
  down)
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
    ;;
  logs)
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f --tail=100
    ;;
  ps)
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 1
    ;;
esac
