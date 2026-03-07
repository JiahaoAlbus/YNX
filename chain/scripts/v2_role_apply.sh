#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_role_apply.sh <validator|full-node|public-rpc>

Apply a canonical runtime role profile to a YNX v2 node home.

Environment:
  YNX_HOME       default: chain/.testnet-v2
  YNX_RPC_PORT   default: 36657
  YNX_REST_PORT  default: 31317
  YNX_EVM_PORT   default: 38545
  YNX_EVM_WS_PORT default: 38546
EOF
}

ROLE="${1:-}"
if [[ -z "$ROLE" || "$ROLE" == "-h" || "$ROLE" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"
CONFIG_TOML="$HOME_DIR/config/config.toml"
APP_TOML="$HOME_DIR/config/app.toml"

YNX_RPC_PORT="${YNX_RPC_PORT:-36657}"
YNX_REST_PORT="${YNX_REST_PORT:-31317}"
YNX_EVM_PORT="${YNX_EVM_PORT:-38545}"
YNX_EVM_WS_PORT="${YNX_EVM_WS_PORT:-38546}"

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

case "$ROLE" in
  validator)
    set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://127.0.0.1:${YNX_RPC_PORT}\""
    set_section_key "$APP_TOML" "api" "enable" "true"
    set_section_key "$APP_TOML" "api" "address" "\"tcp://127.0.0.1:${YNX_REST_PORT}\""
    set_section_key "$APP_TOML" "json-rpc" "enable" "true"
    set_section_key "$APP_TOML" "json-rpc" "address" "\"127.0.0.1:${YNX_EVM_PORT}\""
    set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"127.0.0.1:${YNX_EVM_WS_PORT}\""
    ;;
  full-node)
    set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://127.0.0.1:${YNX_RPC_PORT}\""
    set_section_key "$APP_TOML" "api" "enable" "true"
    set_section_key "$APP_TOML" "api" "address" "\"tcp://127.0.0.1:${YNX_REST_PORT}\""
    set_section_key "$APP_TOML" "json-rpc" "enable" "true"
    set_section_key "$APP_TOML" "json-rpc" "address" "\"127.0.0.1:${YNX_EVM_PORT}\""
    set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"127.0.0.1:${YNX_EVM_WS_PORT}\""
    ;;
  public-rpc)
    set_section_key "$CONFIG_TOML" "rpc" "laddr" "\"tcp://0.0.0.0:${YNX_RPC_PORT}\""
    set_section_key "$APP_TOML" "api" "enable" "true"
    set_section_key "$APP_TOML" "api" "address" "\"tcp://0.0.0.0:${YNX_REST_PORT}\""
    set_section_key "$APP_TOML" "json-rpc" "enable" "true"
    set_section_key "$APP_TOML" "json-rpc" "address" "\"0.0.0.0:${YNX_EVM_PORT}\""
    set_section_key "$APP_TOML" "json-rpc" "ws-address" "\"0.0.0.0:${YNX_EVM_WS_PORT}\""
    ;;
  *)
    echo "Unknown role: $ROLE" >&2
    usage
    exit 1
    ;;
esac

echo "Applied v2 node role: $ROLE"
echo "home=$HOME_DIR"
