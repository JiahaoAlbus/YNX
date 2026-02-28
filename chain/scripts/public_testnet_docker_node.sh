#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  public_testnet_docker_node.sh up [--reset]
  public_testnet_docker_node.sh down
  public_testnet_docker_node.sh logs
  public_testnet_docker_node.sh status

Run a YNX public testnet full node in Docker (macOS/Linux host).

Environment:
  YNX_CHAIN_ID            (default: ynx_9002-1)
  YNX_DENOM               (default: anyxt)
  YNX_MONIKER             (default: ynx-docker-node)
  YNX_NODE_HOME           (default: $HOME/.ynx-docker-node)
  YNX_CONTAINER_NAME      (default: ynx-docker-node)
  YNX_IMAGE               (default: ynx/ynxd:local)
  YNX_P2P_PORT            (default: 26656)
  YNX_RPC_PORT            (default: 26657)
  YNX_PRIMARY_RPC         (default: http://43.134.23.58:26657)
  YNX_SECONDARY_RPC       (default: http://43.134.23.58:26657)
  YNX_SEEDS               (default: e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656)
  YNX_PERSISTENT_PEERS    (default: empty)
  YNX_TRUST_OFFSET        (default: 2000)
  YNX_GENESIS_URL         (default: empty, optional fallback URL)
EOF
}

CHAIN_ID="${YNX_CHAIN_ID:-ynx_9002-1}"
DENOM="${YNX_DENOM:-anyxt}"
MONIKER="${YNX_MONIKER:-ynx-docker-node}"
NODE_HOME="${YNX_NODE_HOME:-$HOME/.ynx-docker-node}"
CONTAINER_NAME="${YNX_CONTAINER_NAME:-ynx-docker-node}"
IMAGE="${YNX_IMAGE:-ynx/ynxd:local}"
P2P_PORT="${YNX_P2P_PORT:-26656}"
RPC_PORT="${YNX_RPC_PORT:-26657}"
PRIMARY_RPC="${YNX_PRIMARY_RPC:-http://43.134.23.58:26657}"
SECONDARY_RPC="${YNX_SECONDARY_RPC:-http://43.134.23.58:26657}"
SEEDS="${YNX_SEEDS:-e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656}"
PERSISTENT_PEERS="${YNX_PERSISTENT_PEERS:-}"
TRUST_OFFSET="${YNX_TRUST_OFFSET:-2000}"
GENESIS_URL="${YNX_GENESIS_URL:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="${1:-up}"
RESET=0
if [[ "${2:-}" == "--reset" ]]; then
  RESET=1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing command: $1" >&2
    exit 1
  }
}

rpc_csv() {
  local p s
  p="$(docker_reachable_rpc "$PRIMARY_RPC")"
  s="$(docker_reachable_rpc "$SECONDARY_RPC")"
  if [[ "$p" == "$s" ]]; then
    echo "$p,$p"
  else
    echo "$p,$s"
  fi
}

docker_reachable_rpc() {
  local rpc="$1"
  rpc="${rpc/127.0.0.1/host.docker.internal}"
  rpc="${rpc/localhost/host.docker.internal}"
  echo "$rpc"
}

fetch_json() {
  local path="$1"
  local attempt rpc out
  for attempt in {1..8}; do
    for rpc in "$PRIMARY_RPC" "$SECONDARY_RPC"; do
      out="$(curl -fsS --max-time 10 "${rpc}${path}" 2>/dev/null || true)"
      if [[ -n "$out" ]]; then
        echo "$out"
        return 0
      fi
    done
    sleep 2
  done
  return 1
}

set_top_level_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  awk -v key="$key" -v value="$value" '
    BEGIN { done=0 }
    $0 ~ "^[[:space:]]*"key"[[:space:]]*=" && done==0 {
      print key" = "value
      done=1
      next
    }
    { print }
    END {
      if (done==0) {
        print key" = "value
      }
    }
  ' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

set_section_key() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"
  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN { in_section=0; done=0 }
    /^\[/ {
      if ($0 == "["section"]") {
        in_section=1
      } else {
        if (in_section && done==0) {
          print key" = "value
          done=1
        }
        in_section=0
      }
      print
      next
    }
    {
      if (in_section && $0 ~ "^[[:space:]]*"key"[[:space:]]*=" && done==0) {
        print key" = "value
        done=1
      } else {
        print
      }
    }
    END {
      if (in_section && done==0) {
        print key" = "value
      }
    }
  ' "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

ensure_image() {
  if docker image inspect "$IMAGE" >/dev/null 2>&1; then
    return
  fi

  require_cmd go
  mkdir -p "$ROOT_DIR/.tmp"
  local docker_bin="$ROOT_DIR/.tmp/ynxd-linux-amd64"
  local docker_ctx="$ROOT_DIR/.tmp/docker-ynxd"

  echo "Building linux binary with local Go toolchain..."
  (
    cd "$ROOT_DIR"
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o "$docker_bin" ./cmd/ynxd
  )

  rm -rf "$docker_ctx"
  mkdir -p "$docker_ctx"
  cp "$docker_bin" "$docker_ctx/ynxd"

  echo "Building Docker image: $IMAGE"
  docker build -t "$IMAGE" -f - "$docker_ctx" <<'EOF'
FROM scratch
COPY ynxd /usr/local/bin/ynxd
ENTRYPOINT ["/usr/local/bin/ynxd"]
EOF
}

prepare_home() {
  if [[ "$RESET" -eq 1 ]]; then
    echo "Resetting node home: $NODE_HOME"
    rm -rf "$NODE_HOME"
  fi

  mkdir -p "$NODE_HOME"
  if [[ ! -f "$NODE_HOME/config/genesis.json" ]]; then
    echo "Initializing node home..."
    docker run --rm -v "$NODE_HOME:/data" "$IMAGE" init "$MONIKER" --chain-id "$CHAIN_ID" --home /data >/dev/null 2>&1
  fi

  echo "Fetching live genesis from RPC"
  if genesis_json="$(fetch_json "/genesis" | jq -e '.result.genesis' 2>/dev/null)"; then
    echo "$genesis_json" >"$NODE_HOME/config/genesis.json"
    return
  fi

  if [[ -n "$GENESIS_URL" ]]; then
    echo "RPC genesis unavailable, fallback to YNX_GENESIS_URL"
    curl -fsS "$GENESIS_URL" >"$NODE_HOME/config/genesis.json"
    return
  fi

  echo "Failed to fetch genesis from RPCs. You can set YNX_GENESIS_URL as fallback." >&2
  exit 1
}

configure_toml() {
  local cfg="$NODE_HOME/config/config.toml"
  local app="$NODE_HOME/config/app.toml"

  local latest_height trust_height trust_hash
  latest_height="$(fetch_json "/status" | jq -r '.result.sync_info.latest_block_height' || true)"
  if [[ -z "$latest_height" ]]; then
    echo "Failed to query /status from RPCs for state sync setup." >&2
    exit 1
  fi
  if ! [[ "$latest_height" =~ ^[0-9]+$ ]]; then
    echo "Invalid latest height from RPC: $latest_height" >&2
    exit 1
  fi
  if (( latest_height <= TRUST_OFFSET + 10 )); then
    trust_height=$((latest_height - 10))
  else
    trust_height=$((latest_height - TRUST_OFFSET))
  fi
  trust_hash="$(fetch_json "/block?height=$trust_height" | jq -r '.result.block_id.hash' || true)"
  if [[ -z "$trust_hash" || "$trust_hash" == "null" ]]; then
    echo "Failed to query trust hash at height $trust_height" >&2
    exit 1
  fi

  set_top_level_key "$cfg" "seeds" "\"$SEEDS\""
  set_top_level_key "$cfg" "persistent_peers" "\"$PERSISTENT_PEERS\""
  set_top_level_key "$cfg" "external_address" "\"\""
  set_top_level_key "$cfg" "addr_book_strict" "false"

  set_section_key "$cfg" "statesync" "enable" "true"
  set_section_key "$cfg" "statesync" "rpc_servers" "\"$(rpc_csv)\""
  set_section_key "$cfg" "statesync" "trust_height" "$trust_height"
  set_section_key "$cfg" "statesync" "trust_hash" "\"$trust_hash\""

  set_section_key "$app" "api" "enable" "false"
  set_section_key "$app" "json-rpc" "enable" "false"

  echo "State sync configured:"
  echo "  trust_height=$trust_height"
  echo "  trust_hash=$trust_hash"
}

start_node() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

  echo "Starting Docker node: $CONTAINER_NAME"
  docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$P2P_PORT:26656" \
    -p "$RPC_PORT:26657" \
    -v "$NODE_HOME:/data" \
    "$IMAGE" start \
      --home /data \
      --chain-id "$CHAIN_ID" \
      --minimum-gas-prices "0.000000007${DENOM}" >/dev/null

  echo
  echo "Started."
  echo "Logs:   docker logs -f $CONTAINER_NAME"
  echo "Status: curl -s http://127.0.0.1:${RPC_PORT}/status | jq -r '.result.sync_info.latest_block_height, .result.sync_info.catching_up'"
}

case "$CMD" in
  up)
    require_cmd docker
    require_cmd curl
    require_cmd jq
    ensure_image
    prepare_home
    configure_toml
    start_node
    ;;
  down)
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    echo "Stopped container: $CONTAINER_NAME"
    ;;
  logs)
    docker logs -f "$CONTAINER_NAME"
    ;;
  status)
    curl -fsS "http://127.0.0.1:${RPC_PORT}/status" | jq -r '.result.sync_info.latest_block_height, .result.sync_info.catching_up'
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    usage
    exit 1
    ;;
esac
