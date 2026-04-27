#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  install_v2_caddy_subdomain_gateway.sh <base_domain> [tls_email] [--hosts rpc,evm,...]

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
  - Use --hosts to install only the subdomains this server should terminate.
EOF
}

BASE_DOMAIN="${1:-}"
TLS_EMAIL=""
HOSTS_CSV="${YNX_CADDY_HOSTS_CSV:-all}"

if [[ -z "$BASE_DOMAIN" || "$BASE_DOMAIN" == "-h" || "$BASE_DOMAIN" == "--help" ]]; then
  usage
  exit 1
fi

shift
if [[ $# -gt 0 && "$1" != --* && "$1" != "-h" && "$1" != "--help" ]]; then
  TLS_EMAIL="$1"
  shift
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts)
      HOSTS_CSV="${2:-}"
      if [[ -z "$HOSTS_CSV" ]]; then
        echo "--hosts requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

HOSTS_CSV="$(echo "$HOSTS_CSV" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

has_host() {
  local host="$1"
  if [[ "$HOSTS_CSV" == "all" ]]; then
    return 0
  fi
  [[ ",$HOSTS_CSV," == *",$host,"* ]]
}

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
    if ! run_root apt-get install -y caddy >/dev/null 2>&1; then
      # Ubuntu default repos may not contain Caddy. Fall back to the official Caddy apt repo.
      run_root apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg >/dev/null
      run_root install -d -m 0755 /usr/share/keyrings
      curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
        | run_root gpg --dearmor --batch --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
      curl -1sLf https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt \
        | run_root tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
      run_root apt-get update -y >/dev/null
      run_root apt-get install -y caddy >/dev/null
    fi
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

TMP_CADDY="$(mktemp)"
cat >"$TMP_CADDY" <<EOF
(ynx_api_headers) {
  @preflight method OPTIONS
  header {
    Access-Control-Allow-Origin "*"
    Access-Control-Allow-Methods "GET,POST,OPTIONS"
    Access-Control-Allow-Headers "Content-Type,Authorization,X-Requested-With,x-ynx-payment"
  }
	respond @preflight 204
}
EOF

append_site() {
  cat >>"$TMP_CADDY"
}

if has_host "rpc"; then
  append_site <<EOF

rpc.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${RPC_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "evm"; then
  append_site <<EOF

evm.${BASE_DOMAIN} {
  import ynx_api_headers
  @evm_probe {
    method GET HEAD
    path / /health
  }
  respond @evm_probe 200 {
    body "{\"ok\":true,\"service\":\"evm-rpc\"}"
  }
  reverse_proxy 127.0.0.1:${EVM_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "evm-ws"; then
  append_site <<EOF

evm-ws.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${EVM_WS_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "rest"; then
  append_site <<EOF

rest.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${REST_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "grpc"; then
  append_site <<EOF

grpc.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy h2c://127.0.0.1:${GRPC_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "faucet"; then
  append_site <<EOF

faucet.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${FAUCET_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "indexer"; then
  append_site <<EOF

indexer.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${INDEXER_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "explorer"; then
  append_site <<EOF

explorer.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${EXPLORER_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "ai"; then
  append_site <<EOF

ai.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${AI_GATEWAY_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

if has_host "web4"; then
  append_site <<EOF

web4.${BASE_DOMAIN} {
  import ynx_api_headers
  reverse_proxy 127.0.0.1:${WEB4_PORT} {
    header_down -Access-Control-Allow-Origin
    header_down -Access-Control-Allow-Methods
    header_down -Access-Control-Allow-Headers
	}
}
EOF
fi

run_root install -m 0644 "$TMP_CADDY" /etc/caddy/conf.d/ynx-v2-gateway.caddy
rm -f "$TMP_CADDY"

run_root caddy fmt --overwrite /etc/caddy/Caddyfile >/dev/null
run_root caddy fmt --overwrite /etc/caddy/conf.d/ynx-v2-gateway.caddy >/dev/null
run_root caddy validate --config /etc/caddy/Caddyfile >/dev/null
run_root systemctl enable --now caddy >/dev/null
run_root systemctl restart caddy

echo "Caddy YNX v2 HTTPS gateway installed."
echo "Configured hosts: ${HOSTS_CSV}"
echo "Set DNS A records to this server for the configured subdomains."
