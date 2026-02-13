#!/usr/bin/env bash

set -euo pipefail

screen -S ynx-ynxd -X quit || true
screen -S ynx-faucet -X quit || true
screen -S ynx-indexer -X quit || true
screen -S ynx-explorer -X quit || true

pkill -f "ynxd start --home .*\\.testnet" || true
pkill -f "/Users/huangjiahao/Desktop/YNX/infra/faucet/server.js" || true
pkill -f "/Users/huangjiahao/Desktop/YNX/infra/indexer/server.js" || true
pkill -f "/Users/huangjiahao/Desktop/YNX/infra/explorer/server.js" || true

echo "Stopped services (ynxd, faucet, indexer, explorer)."
