#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_v2_stack_systemd.sh

Install YNX v2 public-testnet stack as systemd services:
  - ynx-v2-node
  - ynx-v2-faucet
  - ynx-v2-indexer
  - ynx-v2-explorer
  - ynx-v2-ai-gateway
  - ynx-v2-web4-hub

Environment:
  YNX_REPO_DIR         default: $HOME/YNX
  YNX_HOME             default: $HOME/.ynx-v2
  YNX_CHAIN_ID         default: ynx_9102-1
  YNX_DENOM            default: anyxt
  USER_NAME            default: current user
  YNX_P2P_PORT         default: 36656
  YNX_RPC_PORT         default: 36657
  YNX_REST_PORT        default: 31317
  YNX_GRPC_PORT        default: 39090
  YNX_EVM_PORT         default: 38545
  YNX_EVM_WS_PORT      default: 38546
  YNX_PROM_PORT        default: 36660
  YNX_PPROF_PORT       default: 36661
  YNX_GETH_METRICS_PORT default: 38100
  INDEXER_RPC          default: http://127.0.0.1:36657
  FAUCET_PORT          default: 38080
  FAUCET_KEYRING_DIR   default: YNX_HOME
  INDEXER_PORT         default: 38081
  EXPLORER_INDEXER     default: http://127.0.0.1:INDEXER_PORT
  EXPLORER_PORT        default: 38082
  AI_GATEWAY_PORT      default: 38090
  WEB4_PORT            default: 38091
  AI_ENFORCE_POLICY    default: 1
  WEB4_ENFORCE_POLICY  default: 1
  WEB4_INTERNAL_TOKEN  default: ynx-v2-internal
  YNX_PUBLIC_RPC       default: http://127.0.0.1:YNX_RPC_PORT
  YNX_PUBLIC_EVM_RPC   default: http://127.0.0.1:YNX_EVM_PORT
  YNX_PUBLIC_EVM_WS    default: ws://127.0.0.1:YNX_EVM_WS_PORT
  YNX_PUBLIC_REST      default: http://127.0.0.1:YNX_REST_PORT
  YNX_PUBLIC_GRPC      default: http://127.0.0.1:YNX_GRPC_PORT
  YNX_PUBLIC_FAUCET    default: http://127.0.0.1:FAUCET_PORT
  YNX_PUBLIC_INDEXER   default: http://127.0.0.1:INDEXER_PORT
  YNX_PUBLIC_EXPLORER  default: http://127.0.0.1:EXPLORER_PORT
  YNX_PUBLIC_AI_GATEWAY default: http://127.0.0.1:AI_GATEWAY_PORT
  YNX_PUBLIC_WEB4_HUB  default: http://127.0.0.1:WEB4_PORT
  YNX_SEEDS            default: empty
  YNX_PERSISTENT_PEERS default: empty
  YNX_BINARY_VERSION   default: local-build
  YNX_RELEASE_URL      default: empty
  YNX_DESCRIPTOR_URL   default: empty
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found; this script must run on a systemd host." >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "Need root or sudo privileges to install systemd units." >&2
  exit 1
fi

run_root() {
  if [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

YNX_REPO_DIR="${YNX_REPO_DIR:-$HOME/YNX}"
CHAIN_DIR="$YNX_REPO_DIR/chain"
INFRA_DIR="$YNX_REPO_DIR/infra"

YNX_HOME="${YNX_HOME:-$HOME/.ynx-v2}"
YNX_CHAIN_ID="${YNX_CHAIN_ID:-ynx_9102-1}"
YNX_DENOM="${YNX_DENOM:-anyxt}"
USER_NAME="${USER_NAME:-$(id -un)}"
YNX_P2P_PORT="${YNX_P2P_PORT:-36656}"
YNX_RPC_PORT="${YNX_RPC_PORT:-36657}"
YNX_REST_PORT="${YNX_REST_PORT:-31317}"
YNX_GRPC_PORT="${YNX_GRPC_PORT:-39090}"
YNX_EVM_PORT="${YNX_EVM_PORT:-38545}"
YNX_EVM_WS_PORT="${YNX_EVM_WS_PORT:-38546}"
YNX_PROM_PORT="${YNX_PROM_PORT:-36660}"
YNX_PPROF_PORT="${YNX_PPROF_PORT:-36661}"
YNX_GETH_METRICS_PORT="${YNX_GETH_METRICS_PORT:-38100}"
INDEXER_RPC="${INDEXER_RPC:-http://127.0.0.1:${YNX_RPC_PORT}}"
FAUCET_PORT="${FAUCET_PORT:-38080}"
FAUCET_KEYRING_DIR="${FAUCET_KEYRING_DIR:-$YNX_HOME}"
INDEXER_PORT="${INDEXER_PORT:-38081}"
EXPLORER_INDEXER="${EXPLORER_INDEXER:-http://127.0.0.1:${INDEXER_PORT}}"
EXPLORER_PORT="${EXPLORER_PORT:-38082}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${WEB4_PORT:-38091}"
AI_ENFORCE_POLICY="${AI_ENFORCE_POLICY:-1}"
WEB4_ENFORCE_POLICY="${WEB4_ENFORCE_POLICY:-1}"
WEB4_INTERNAL_TOKEN="${WEB4_INTERNAL_TOKEN:-ynx-v2-internal}"
YNX_PUBLIC_RPC="${YNX_PUBLIC_RPC:-http://127.0.0.1:${YNX_RPC_PORT}}"
YNX_PUBLIC_EVM_RPC="${YNX_PUBLIC_EVM_RPC:-http://127.0.0.1:${YNX_EVM_PORT}}"
YNX_PUBLIC_EVM_WS="${YNX_PUBLIC_EVM_WS:-ws://127.0.0.1:${YNX_EVM_WS_PORT}}"
YNX_PUBLIC_REST="${YNX_PUBLIC_REST:-http://127.0.0.1:${YNX_REST_PORT}}"
YNX_PUBLIC_GRPC="${YNX_PUBLIC_GRPC:-http://127.0.0.1:${YNX_GRPC_PORT}}"
YNX_PUBLIC_FAUCET="${YNX_PUBLIC_FAUCET:-http://127.0.0.1:${FAUCET_PORT}}"
YNX_PUBLIC_INDEXER="${YNX_PUBLIC_INDEXER:-http://127.0.0.1:${INDEXER_PORT}}"
YNX_PUBLIC_EXPLORER="${YNX_PUBLIC_EXPLORER:-http://127.0.0.1:${EXPLORER_PORT}}"
YNX_PUBLIC_AI_GATEWAY="${YNX_PUBLIC_AI_GATEWAY:-http://127.0.0.1:${AI_GATEWAY_PORT}}"
YNX_PUBLIC_WEB4_HUB="${YNX_PUBLIC_WEB4_HUB:-http://127.0.0.1:${WEB4_PORT}}"
YNX_SEEDS="${YNX_SEEDS:-}"
YNX_PERSISTENT_PEERS="${YNX_PERSISTENT_PEERS:-}"
YNX_BINARY_VERSION="${YNX_BINARY_VERSION:-local-build}"
YNX_RELEASE_URL="${YNX_RELEASE_URL:-}"
YNX_DESCRIPTOR_URL="${YNX_DESCRIPTOR_URL:-}"

CONFIG_TOML="$YNX_HOME/config/config.toml"
APP_TOML="$YNX_HOME/config/app.toml"

if [[ ! -x "$CHAIN_DIR/ynxd" ]]; then
  echo "Binary not found: $CHAIN_DIR/ynxd" >&2
  exit 1
fi
if [[ ! -f "$INFRA_DIR/faucet/server.js" ]]; then
  echo "Faucet service not found: $INFRA_DIR/faucet/server.js" >&2
  exit 1
fi
if [[ ! -f "$CONFIG_TOML" || ! -f "$APP_TOML" ]]; then
  echo "v2 home config missing at $YNX_HOME. Run v2_testnet_bootstrap.sh first." >&2
  exit 1
fi

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

set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://0.0.0.0:${YNX_RPC_PORT}\""
set_section_key "$CONFIG_TOML" "rpc" "pprof_laddr" "\"localhost:${YNX_PPROF_PORT}\""
set_section_key "$CONFIG_TOML" "p2p" "laddr" "\"tcp://0.0.0.0:${YNX_P2P_PORT}\""
set_section_key "$CONFIG_TOML" "p2p" "seeds" "\"${YNX_SEEDS}\""
set_section_key "$CONFIG_TOML" "p2p" "persistent_peers" "\"${YNX_PERSISTENT_PEERS}\""
set_section_key "$CONFIG_TOML" "instrumentation" "prometheus_listen_addr" "\":${YNX_PROM_PORT}\""
set_section_key "$APP_TOML" "api" "address" "\"tcp://0.0.0.0:${YNX_REST_PORT}\""
set_section_key "$APP_TOML" "grpc" "address" "\"0.0.0.0:${YNX_GRPC_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "address" "\"0.0.0.0:${YNX_EVM_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"0.0.0.0:${YNX_EVM_WS_PORT}\""
set_section_key "$APP_TOML" "evm" "geth-metrics-address" "\"127.0.0.1:${YNX_GETH_METRICS_PORT}\""

run_root install -d -m 0755 /etc/ynx-v2
run_root tee /etc/ynx-v2/env >/dev/null <<EOF
YNX_REPO_DIR=$YNX_REPO_DIR
YNX_HOME=$YNX_HOME
YNX_CHAIN_ID=$YNX_CHAIN_ID
YNX_DENOM=$YNX_DENOM
INDEXER_RPC=$INDEXER_RPC
EXPLORER_INDEXER=$EXPLORER_INDEXER
YNX_P2P_PORT=$YNX_P2P_PORT
YNX_RPC_PORT=$YNX_RPC_PORT
YNX_REST_PORT=$YNX_REST_PORT
YNX_GRPC_PORT=$YNX_GRPC_PORT
YNX_EVM_PORT=$YNX_EVM_PORT
YNX_EVM_WS_PORT=$YNX_EVM_WS_PORT
YNX_PROM_PORT=$YNX_PROM_PORT
YNX_PPROF_PORT=$YNX_PPROF_PORT
YNX_GETH_METRICS_PORT=$YNX_GETH_METRICS_PORT
FAUCET_PORT=$FAUCET_PORT
FAUCET_KEYRING_DIR=$FAUCET_KEYRING_DIR
INDEXER_PORT=$INDEXER_PORT
EXPLORER_PORT=$EXPLORER_PORT
AI_GATEWAY_PORT=$AI_GATEWAY_PORT
WEB4_PORT=$WEB4_PORT
AI_ENFORCE_POLICY=$AI_ENFORCE_POLICY
WEB4_ENFORCE_POLICY=$WEB4_ENFORCE_POLICY
WEB4_INTERNAL_TOKEN=$WEB4_INTERNAL_TOKEN
YNX_PUBLIC_RPC=$YNX_PUBLIC_RPC
YNX_PUBLIC_EVM_RPC=$YNX_PUBLIC_EVM_RPC
YNX_PUBLIC_EVM_WS=$YNX_PUBLIC_EVM_WS
YNX_PUBLIC_REST=$YNX_PUBLIC_REST
YNX_PUBLIC_GRPC=$YNX_PUBLIC_GRPC
YNX_PUBLIC_FAUCET=$YNX_PUBLIC_FAUCET
YNX_PUBLIC_INDEXER=$YNX_PUBLIC_INDEXER
YNX_PUBLIC_EXPLORER=$YNX_PUBLIC_EXPLORER
YNX_PUBLIC_AI_GATEWAY=$YNX_PUBLIC_AI_GATEWAY
YNX_PUBLIC_WEB4_HUB=$YNX_PUBLIC_WEB4_HUB
YNX_SEEDS=$YNX_SEEDS
YNX_PERSISTENT_PEERS=$YNX_PERSISTENT_PEERS
YNX_BINARY_VERSION=$YNX_BINARY_VERSION
YNX_RELEASE_URL=$YNX_RELEASE_URL
YNX_DESCRIPTOR_URL=$YNX_DESCRIPTOR_URL
EOF

run_root tee /etc/systemd/system/ynx-v2-node.service >/dev/null <<EOF
[Unit]
Description=YNX v2 Node
After=network-online.target
Wants=network-online.target
Wants=ynx-v2-faucet.service ynx-v2-indexer.service ynx-v2-explorer.service ynx-v2-ai-gateway.service ynx-v2-web4-hub.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$CHAIN_DIR
EnvironmentFile=/etc/ynx-v2/env
ExecStart=$CHAIN_DIR/ynxd start --home $YNX_HOME --chain-id $YNX_CHAIN_ID --minimum-gas-prices 0.000000007$YNX_DENOM --api.enable --grpc.enable --grpc.address 0.0.0.0:$YNX_GRPC_PORT --json-rpc.enable --json-rpc.address 0.0.0.0:$YNX_EVM_PORT --json-rpc.ws-address 0.0.0.0:$YNX_EVM_WS_PORT
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root tee /etc/systemd/system/ynx-v2-faucet.service >/dev/null <<EOF
[Unit]
Description=YNX v2 Faucet
After=ynx-v2-node.service
Requires=ynx-v2-node.service
PartOf=ynx-v2-node.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$INFRA_DIR/faucet
EnvironmentFile=/etc/ynx-v2/env
Environment=FAUCET_HOME=$YNX_HOME
Environment=FAUCET_CHAIN_ID=$YNX_CHAIN_ID
Environment=FAUCET_DENOM=$YNX_DENOM
Environment=FAUCET_PORT=$FAUCET_PORT
Environment=FAUCET_NODE=http://127.0.0.1:$YNX_RPC_PORT
Environment=FAUCET_GAS_PRICES=0.000000007$YNX_DENOM
Environment=FAUCET_DATA_DIR=$YNX_HOME/faucet-data
Environment=FAUCET_KEYRING_DIR=$FAUCET_KEYRING_DIR
ExecStart=/usr/bin/env node $INFRA_DIR/faucet/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root tee /etc/systemd/system/ynx-v2-indexer.service >/dev/null <<EOF
[Unit]
Description=YNX v2 Indexer
After=ynx-v2-node.service
Requires=ynx-v2-node.service
PartOf=ynx-v2-node.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$INFRA_DIR/indexer
EnvironmentFile=/etc/ynx-v2/env
Environment=INDEXER_RPC=$INDEXER_RPC
Environment=INDEXER_PORT=$INDEXER_PORT
Environment=YNX_OVERVIEW_TRACK=v2-web4
Environment=INDEXER_DATA_DIR=$YNX_HOME/indexer-data
ExecStart=/usr/bin/env node $INFRA_DIR/indexer/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root tee /etc/systemd/system/ynx-v2-explorer.service >/dev/null <<EOF
[Unit]
Description=YNX v2 Explorer
After=ynx-v2-indexer.service
Requires=ynx-v2-indexer.service
PartOf=ynx-v2-node.service ynx-v2-indexer.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$INFRA_DIR/explorer
EnvironmentFile=/etc/ynx-v2/env
Environment=EXPLORER_INDEXER=$EXPLORER_INDEXER
Environment=EXPLORER_PORT=$EXPLORER_PORT
ExecStart=/usr/bin/env node $INFRA_DIR/explorer/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root tee /etc/systemd/system/ynx-v2-ai-gateway.service >/dev/null <<EOF
[Unit]
Description=YNX v2 AI Gateway
After=ynx-v2-node.service
Requires=ynx-v2-node.service
PartOf=ynx-v2-node.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$INFRA_DIR/ai-gateway
EnvironmentFile=/etc/ynx-v2/env
Environment=AI_CHAIN_ID=$YNX_CHAIN_ID
Environment=AI_GATEWAY_PORT=$AI_GATEWAY_PORT
Environment=AI_ENFORCE_POLICY=$AI_ENFORCE_POLICY
Environment=AI_WEB4_HUB_URL=http://127.0.0.1:$WEB4_PORT
Environment=AI_WEB4_INTERNAL_TOKEN=$WEB4_INTERNAL_TOKEN
Environment=AI_DATA_DIR=$YNX_HOME/ai-gateway-data
ExecStart=/usr/bin/env node $INFRA_DIR/ai-gateway/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root tee /etc/systemd/system/ynx-v2-web4-hub.service >/dev/null <<EOF
[Unit]
Description=YNX v2 Web4 Hub
After=ynx-v2-node.service
Requires=ynx-v2-node.service
PartOf=ynx-v2-node.service

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$INFRA_DIR/web4-hub
EnvironmentFile=/etc/ynx-v2/env
Environment=WEB4_CHAIN_ID=$YNX_CHAIN_ID
Environment=WEB4_PORT=$WEB4_PORT
Environment=WEB4_ENFORCE_POLICY=$WEB4_ENFORCE_POLICY
Environment=WEB4_INTERNAL_TOKEN=$WEB4_INTERNAL_TOKEN
Environment=WEB4_DATA_DIR=$YNX_HOME/web4-hub-data
ExecStart=/usr/bin/env node $INFRA_DIR/web4-hub/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

run_root systemctl daemon-reload
run_root systemctl enable --now \
  ynx-v2-node.service \
  ynx-v2-faucet.service \
  ynx-v2-indexer.service \
  ynx-v2-explorer.service \
  ynx-v2-ai-gateway.service \
  ynx-v2-web4-hub.service

for unit in \
  ynx-v2-node \
  ynx-v2-faucet \
  ynx-v2-indexer \
  ynx-v2-explorer \
  ynx-v2-ai-gateway \
  ynx-v2-web4-hub; do
  echo
  run_root systemctl --no-pager --full status "$unit" | sed -n '1,16p'
done

echo
echo "YNX v2 stack services installed and started."
