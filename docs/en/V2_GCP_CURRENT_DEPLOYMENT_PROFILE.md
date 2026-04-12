# YNX v2 GCP Current Deployment Profile

Status: active  
Last updated: 2026-04-12

## Purpose

This document is the current operations baseline for the YNX v2 public testnet on GCP.
Use it as the source of truth for endpoint routing, node roles, and security switches.

## Baseline

- Repo baseline: `main` @ `7dd1dae`
- Domain: `ynxweb4.com`
- Public testnet chain id: `ynx_9102-1`
- EVM chain id: `0x238e`

## Active GCP Topology

- Bootstrap node: `34.96.134.119`
- RPC node: `34.150.93.74`
- Service node: `34.92.114.34`

## Public Domain Routing

- `rpc.ynxweb4.com` -> `34.150.93.74`
- `evm.ynxweb4.com` -> `34.150.93.74`
- `evm-ws.ynxweb4.com` -> `34.150.93.74`
- `rest.ynxweb4.com` -> `34.92.114.34`
- `grpc.ynxweb4.com` -> `34.92.114.34`
- `faucet.ynxweb4.com` -> `34.92.114.34`
- `indexer.ynxweb4.com` -> `34.92.114.34`
- `explorer.ynxweb4.com` -> `34.92.114.34`
- `ai.ynxweb4.com` -> `34.92.114.34`
- `web4.ynxweb4.com` -> `34.92.114.34`

## Network Descriptor Truth (live)

- Seed / persistent peer:
  - `4873f5737444f3fb3eced7035e0afc0fc1192110@34.96.134.119:36656`
- Descriptor endpoint:
  - `https://indexer.ynxweb4.com/ynx/network-descriptor`

## Security / Policy Enforcement State (live)

- AI gateway:
  - `enforce_policy=true`
  - `has_web4_authorizer=true`
- Web4 hub:
  - `enforce_policy=true`
  - `internal_authorizer_enabled=true`

## Provisioning Defaults (from deploy script)

Source: `chain/scripts/v2_gcp_fullblood_deploy.sh`

- Billing account default: `01562C-E2CAC9-5704C6`
- Region: `asia-east2`
- Zone: `asia-east2-b`
- VM machine type: `e2-standard-4`
- Boot disk: `80GB` (`pd-standard`)
- OS image family: `ubuntu-2204-lts`

## Public Ingress Ports

Main exposed ports used by the deployed stack:

- SSH: `22`
- P2P / node: `36656`, `36657`
- REST / gRPC / EVM: `31317`, `39090`, `38545`, `38546`
- App services: `38080`, `38081`, `38082`, `38090`, `38091`
- HTTPS gateway: `80`, `443`

## Quick Validation Commands

```bash
curl -sS https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network,.result.sync_info.latest_block_height,.result.sync_info.catching_up'
curl -sS https://evm.ynxweb4.com -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' | jq
curl -sS https://faucet.ynxweb4.com/health | jq
curl -sS https://indexer.ynxweb4.com/ynx/overview | jq
curl -sS https://ai.ynxweb4.com/health | jq
curl -sS https://web4.ynxweb4.com/health | jq
```

## Note

Instance-level hardware/runtime details (CPU/memory/disk usage per host) require direct SSH or `gcloud` access.
This profile records the verified active network behavior and deployment defaults.
