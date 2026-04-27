# YNX v2 Tencent Cloud Current Deployment Profile

Status: active  
Last updated: 2026-04-28

## Purpose

This document is the **current ops baseline** for the live YNX v2 public testnet running on **Tencent Cloud**.
Use it as the source of truth for endpoint routing, node roles, and security switches.

## Baseline

- Repo baseline: `main` (use the latest `main` unless a tagged release is announced)
- Domain: `ynxweb4.com`
- Public testnet chain id: `ynx_9102-1`
- EVM chain id: `0x238e` (`9102`)

## Active Tencent Topology (live)

Current production routing is **single-host / all-in-one**:

- Tencent Cloud Lighthouse
  - region: Singapore (Singapore Zone 2)
  - instance id: `lhins-kewmg5r7`
  - public IPv4: `43.153.202.237`
  - OS: Ubuntu
  - moniker: `ynx-tencent-singapore`
  - node id: `c97ce9fdf76d2634651e4cb9cbb12dbad8327037`

Installed services (systemd):

- `ynx-v2-node.service`
- `ynx-v2-faucet.service`
- `ynx-v2-indexer.service`
- `ynx-v2-explorer.service`
- `ynx-v2-ai-gateway.service`
- `ynx-v2-web4-hub.service`
- `caddy.service` (HTTPS gateway)

## Public Domain Routing (current)

All public subdomains terminate TLS on the Tencent host via Caddy and reverse-proxy to local services.

- `rpc.ynxweb4.com` -> `43.153.202.237`
- `evm.ynxweb4.com` -> `43.153.202.237`
- `evm-ws.ynxweb4.com` -> `43.153.202.237`
- `rest.ynxweb4.com` -> `43.153.202.237`
- `grpc.ynxweb4.com` -> `43.153.202.237`
- `faucet.ynxweb4.com` -> `43.153.202.237`
- `indexer.ynxweb4.com` -> `43.153.202.237`
- `explorer.ynxweb4.com` -> `43.153.202.237`
- `ai.ynxweb4.com` -> `43.153.202.237`
- `web4.ynxweb4.com` -> `43.153.202.237`

## Network Descriptor Truth (live)

- Descriptor endpoint:
  - `https://indexer.ynxweb4.com/ynx/network-descriptor`

If you change routing (IP / host split), you MUST ensure the descriptor stays accurate, since the join CLI relies on it.

## Public Ingress Ports (Tencent)

Cloud firewall (Lighthouse firewall rules) must allow at minimum:

- TCP `80` from `0.0.0.0/0` (ACME HTTP challenge / redirects)
- TCP `443` from `0.0.0.0/0` (HTTPS gateway)
- TCP `36656` from `0.0.0.0/0` (YNX P2P)

Local listening ports (expected on the host):

- Node: `36656` (P2P), `36657` (RPC), `31317` (REST), `39090` (gRPC), `38545` (EVM JSON-RPC), `38546` (EVM WS)
- App services: `38080` (faucet), `38081` (indexer), `38082` (explorer), `38090` (AI gateway), `38091` (Web4 hub)

## Deployment Entry Points (repo)

- Deploy to a server: `chain/scripts/v2_public_testnet_deploy.sh`
- Install systemd services: `chain/scripts/install_v2_stack_systemd.sh`
- Install Caddy subdomain gateway: `chain/scripts/install_v2_caddy_subdomain_gateway.sh`
- Backup/restore node state:
  - `chain/scripts/v2_node_backup.sh`
  - `chain/scripts/v2_node_restore.sh`

## GCP Decommission Note

GCP was previously used for the live baseline. As of **2026-04-28**, public routing and services are migrated to Tencent.
Historical GCP runbooks remain in `docs/en/V2_GCP_*` for audit/traceability, but they are not the current baseline.

