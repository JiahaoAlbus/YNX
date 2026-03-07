#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"

YNX_P2P_PORT="${YNX_P2P_PORT:-36656}"
YNX_RPC_PORT="${YNX_RPC_PORT:-36657}"
YNX_REST_PORT="${YNX_REST_PORT:-31317}"
YNX_GRPC_PORT="${YNX_GRPC_PORT:-39090}"
YNX_EVM_PORT="${YNX_EVM_PORT:-38545}"
YNX_EVM_WS_PORT="${YNX_EVM_WS_PORT:-38546}"
YNX_PROM_PORT="${YNX_PROM_PORT:-36660}"
YNX_PPROF_PORT="${YNX_PPROF_PORT:-36661}"
YNX_GETH_METRICS_PORT="${YNX_GETH_METRICS_PORT:-38100}"

CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

if [[ ! -f "$CONFIG_TOML" || ! -f "$APP_TOML" ]]; then
  echo "Missing config files under $HOME_DIR" >&2
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
set_section_key "$CONFIG_TOML" "instrumentation" "prometheus_listen_addr" "\":${YNX_PROM_PORT}\""
set_section_key "$APP_TOML" "api" "address" "\"tcp://0.0.0.0:${YNX_REST_PORT}\""
set_section_key "$APP_TOML" "grpc" "address" "\"0.0.0.0:${YNX_GRPC_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "address" "\"0.0.0.0:${YNX_EVM_PORT}\""
set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"0.0.0.0:${YNX_EVM_WS_PORT}\""
set_section_key "$APP_TOML" "evm" "geth-metrics-address" "\"127.0.0.1:${YNX_GETH_METRICS_PORT}\""

echo "Ports applied to $HOME_DIR"
