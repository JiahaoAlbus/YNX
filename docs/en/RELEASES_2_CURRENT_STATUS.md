# YNX Releases 2 — Current Status Snapshot

Status: active  
Date: 2026-05-01
Tag target: current `main`

## Scope

This release updates the public testnet from baseline launch to a mainnet-parity operational posture:

- Positioning clarified: governance-native EVM chain for real Web3 services.
- Machine-readable overview API expanded for governance and positioning data.
- Explorer now surfaces positioning and governance metadata.
- One-command health verification now validates positioning fields.
- Controlled server upgrade script added (pull/build/restart/verify).
- Current readiness report and industry gates added.

## Network snapshot at release time

- Chain ID: `ynx_9102-1`
- EVM chain ID: `0x238e`
- Latest height snapshot: see `docs/en/PUBLIC_TESTNET_READINESS_REPORT_2026_05_01.md`
- Catching up: `false`
- No base fee: `true`
- Services: `ynx-node`, `ynx-faucet`, `ynx-indexer`, `ynx-explorer`, `ynx-ai-gateway`, `ynx-web4-hub` = active
- Caveat: public P2P peers and validator-set size are below industry-grade mainnet-candidate thresholds.

## Public endpoints

- RPC: `https://rpc.ynxweb4.com`
- EVM JSON-RPC: `https://evm.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`

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
- `docs/en/PUBLIC_TESTNET_READINESS_REPORT_2026_05_01.md`
- `docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md`
- `docs/en/PROJECT_NON_TECHNICAL_LAUNCH_PACKET.md`
