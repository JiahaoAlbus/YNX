# YNX Releases 2 — Current Status Snapshot

Status: active  
Date: 2026-02-17  
Tag target: `f9d314e`

## Scope

This release updates the public testnet from baseline launch to a mainnet-parity operational posture:

- Positioning clarified: governance-native EVM chain for real Web3 services.
- Machine-readable overview API expanded for governance and positioning data.
- Explorer now surfaces positioning and governance metadata.
- One-command health verification now validates positioning fields.
- Controlled server upgrade script added (pull/build/restart/verify).

## Network snapshot at release time

- Chain ID: `ynx_9002-1`
- EVM chain ID: `0x232a`
- Latest height snapshot: `13805`
- Catching up: `false`
- No base fee: `true`
- Services: `ynx-node`, `ynx-faucet`, `ynx-indexer`, `ynx-explorer` = active

## Public endpoints

- RPC: `http://43.134.23.58:26657`
- EVM JSON-RPC: `http://43.134.23.58:8545`
- REST: `http://43.134.23.58:1317`
- Faucet: `http://43.134.23.58:8080`
- Indexer: `http://43.134.23.58:8081`
- Explorer: `http://43.134.23.58:8082`

## New operator endpoints

- `GET /health`
- `GET /stats`
- `GET /ynx/overview`

## Core files in this release

- `README.md`
- `chain/scripts/public_testnet_verify.sh`
- `chain/scripts/server_upgrade_apply.sh`
- `infra/indexer/server.js`
- `infra/explorer/public/app.js`
- `docs/en/YNX_POSITIONING.md`
- `docs/zh/YNX_定位与卖点.md`
- `docs/en/MAINNET_PARITY_AND_ADVANTAGES.md`

