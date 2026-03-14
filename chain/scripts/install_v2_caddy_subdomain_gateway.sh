#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_v2_caddy_subdomain_gateway.sh <base_domain> [tls_email]

Example:
  ./scripts/install_v2_caddy_subdomain_gateway.sh ynxweb4.com ops@ynxweb4.com

Purpose:
  Install/configure a Caddy HTTPS gateway for YNX v2 services using subdomains:
    rpc.<base_domain>       -> 127.0.0.1:36657
    evm.<base_domain>       -> 127.0.0.1:38545
    evm-ws.<base_domain>    -> 127.0.0.1:38546
    rest.<base_domain>      -> 127.0.0.1:31317
    faucet.<base_domain>    -> 127.0.0.1:38080
    indexer.<base_domain>   -> 127.0.0.1:38081
    explorer.<base_domain>  -> 127.0.0.1:38082
    ai.<base_domain>        -> 127.0.0.1:38090
    web4.<base_domain>      -> 127.0.0.1:38091

Notes:
  - DNS A records for all subdomains must point to this server IP.
  - TCP 80/443 must be open in cloud firewall/security group.
EOF
}

BASE_DOMAIN="${1:-}"
TLS_EMAIL="${2:-}"

if [[ -z "$BASE_DOMAIN" || "$BASE_DOMAIN" == "-h" || "$BASE_DOMAIN" == "--help" ]]; then
  usage
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
elif command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  echo "Need root or sudo privileges." >&2
  exit 1
fi

run_root() {
  if [[ -n "$SUDO" ]]; then
    "$SUDO" "$@"
  else
    "$@"
  fi
}

RPC_PORT="${YNX_RPC_PORT:-36657}"
EVM_PORT="${YNX_EVM_PORT:-38545}"
EVM_WS_PORT="${YNX_EVM_WS_PORT:-38546}"
REST_PORT="${YNX_REST_PORT:-31317}"
GRPC_PORT="${YNX_GRPC_PORT:-39090}"
FAUCET_PORT="${FAUCET_PORT:-38080}"
INDEXER_PORT="${INDEXER_PORT:-38081}"
EXPLORER_PORT="${EXPLORER_PORT:-38082}"
AI_GATEWAY_PORT="${AI_GATEWAY_PORT:-38090}"
WEB4_PORT="${WEB4_PORT:-38091}"

install_caddy() {
  if command -v caddy >/dev/null 2>&1; then
    return
  fi
  if command -v apt-get >/dev/null 2>&1; then
    run_root apt-get update -y >/dev/null
    run_root apt-get install -y caddy >/dev/null
    return
  fi
  if command -v dnf >/dev/null 2>&1; then
    run_root dnf install -y caddy >/dev/null
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    run_root yum install -y caddy >/dev/null
    return
  fi
  echo "Unsupported package manager (need apt-get/dnf/yum)." >&2
  exit 1
}

install_caddy

run_root install -d -m 0755 /etc/caddy/conf.d

if [[ ! -f /etc/caddy/Caddyfile ]]; then
  run_root tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
{
}

import /etc/caddy/conf.d/*.caddy
EOF
elif ! run_root grep -q 'import /etc/caddy/conf.d/\*.caddy' /etc/caddy/Caddyfile; then
  run_root tee -a /etc/caddy/Caddyfile >/dev/null <<'EOF'

import /etc/caddy/conf.d/*.caddy
EOF
fi

EMAIL_BLOCK=""
if [[ -n "$TLS_EMAIL" ]]; then
  echo "TLS email provided (${TLS_EMAIL}), using default Caddy ACME account configuration."
fi

run_root tee /etc/caddy/conf.d/ynx-v2-gateway.caddy >/dev/null <<EOF
(ynx_api_headers) {
  @preflight method OPTIONS
  header {
    Access-Control-Allow-Origin "*"
    Access-Control-Allow-Methods "GET,POST,OPTIONS"
    Access-Control-Allow-Headers "Content-Type,Authorization,X-Requested-With,x-ynx-payment"
  }
  respond @preflight 204
}

rpc.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${RPC_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

evm.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${EVM_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

evm-ws.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${EVM_WS_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

rest.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${REST_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

grpc.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy h2c://127.0.0.1:${GRPC_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

faucet.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${FAUCET_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

indexer.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${INDEXER_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

explorer.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${EXPLORER_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

ai.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${AI_GATEWAY_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}

web4.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${WEB4_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
  }
}
EOF

run_root caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null
run_root caddy fmt --overwrite /etc/caddy/conf.d/ynx-v2-gateway.caddy >/dev/null
run_root caddy validate --config /etc/caddy/Caddyfile >/dev/null
run_root systemctl enable --now caddy >/dev/null
run_root systemctl restart caddy

echo "Caddy YNX v2 HTTPS gateway installed."
echo "Set DNS A records to this server for:"
echo "  rpc.${BASE_DOMAIN}"
echo "  evm.${BASE_DOMAIN}"
echo "  evm-ws.${BASE_DOMAIN}"
echo "  rest.${BASE_DOMAIN}"
echo "  grpc.${BASE_DOMAIN}"
echo "  faucet.${BASE_DOMAIN}"
echo "  indexer.${BASE_DOMAIN}"
echo "  explorer.${BASE_DOMAIN}"
echo "  ai.${BASE_DOMAIN}"
echo "  web4.${BASE_DOMAIN}"
