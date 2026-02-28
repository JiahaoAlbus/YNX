#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${YNX_HOME:-$ROOT_DIR/.testnet-v2}"

screen -S ynx-v2-ynxd -X quit || true
screen -S ynx-v2-faucet -X quit || true
screen -S ynx-v2-indexer -X quit || true
screen -S ynx-v2-explorer -X quit || true
screen -S ynx-v2-ai-gateway -X quit || true
screen -S ynx-v2-web4-hub -X quit || true

pkill -f "ynxd start --home ${HOME_DIR}" || true
pkill -f "FAUCET_HOME=${HOME_DIR}" || true
pkill -f "INDEXER_DATA_DIR=${HOME_DIR}/indexer-data" || true
pkill -f "EXPLORER_INDEXER=http://127.0.0.1:${YNX_INDEXER_PORT:-38081}" || true
pkill -f "AI_DATA_DIR=${HOME_DIR}/ai-gateway-data" || true
pkill -f "WEB4_DATA_DIR=${HOME_DIR}/web4-hub-data" || true

echo "Stopped YNX v2 services."
