# YNX v2 GCP Current Deployment Profile

Status: active  
Last updated: 2026-04-17

## Purpose

This document is the current operations baseline for the YNX v2 public testnet on GCP.
Use it as the source of truth for endpoint routing, node roles, and security switches.

## Baseline

- Repo baseline: `main` @ `c4e9a75`
- Domain: `ynxweb4.com`
- Public testnet chain id: `ynx_9102-1`
- EVM chain id: `0x238e`

## Active GCP Topology

- Bootstrap node: `34.96.134.119`
- RPC node: `34.150.93.74`
- Service node: `34.92.114.34`

All three nodes are currently:
- `RUNNING`
- machine type: `e2-standard-4` (4 vCPU, 16 GB RAM)
- zone: `asia-east2-b`
- network: `default` (IPv4 only)

## Runtime Instance Profile (live)

- `ynx-v2-bootstrap-1`
  - internal IP: `10.170.0.2`
  - external IP: `34.96.134.119`
  - boot disk: `200GB`, `pd-balanced`, Ubuntu 22.04
  - deletion protection: `false`
  - shielded VM: `vTPM=true`, integrity monitoring=true, secure boot=false
- `ynx-v2-rpc-1`
  - internal IP: `10.170.0.4`
  - external IP: `34.150.93.74`
  - boot disk: `80GB`, `pd-standard`, Ubuntu 22.04
  - deletion protection: `false`
  - shielded VM: `vTPM=true`, integrity monitoring=true, secure boot=false
- `ynx-v2-service-1`
  - internal IP: `10.170.0.5`
  - external IP: `34.92.114.34`
  - boot disk: `80GB`, `pd-standard`, Ubuntu 22.04
  - deletion protection: `false`
  - shielded VM: `vTPM=true`, integrity monitoring=true, secure boot=false

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

Note:
- Current runtime differs from script default on bootstrap disk (live is `200GB pd-balanced`).

## Public Ingress Ports

Main exposed ports used by the deployed stack:

- SSH: `22`
- P2P / node: `36656`, `36657`
- REST / gRPC / EVM: `31317`, `39090`, `38545`, `38546`
- App services: `38080`, `38081`, `38082`, `38090`, `38091`
- HTTPS gateway: `80`, `443`

Firewall rule:
- `ynx-v2-public` (INGRESS, source `0.0.0.0/0`)

## Billing Controls (live)

- Project billing: enabled (`projects/ynx-testnet-gcp` -> `billingAccounts/01562C-E2CAC9-5704C6`)
- Budget `YNX`:
  - monthly HKD `100`
  - current-spend alerts: 50%, 90%, 100% (plus 25%, 75%)
  - `creditTypesTreatment=EXCLUDE_ALL_CREDITS`
- Budget `YNX-Credit-Guard-Stop`:
  - monthly HKD `2300`
  - current-spend alert: 100%
  - `creditTypesTreatment=EXCLUDE_ALL_CREDITS`

## Cost Behavior Notes (important)

- GCP VM billing is based on uptime + machine type, not CPU saturation.
- Therefore, low CPU usage does not mean low compute cost.
- Current stack has 3 always-on `e2-standard-4` VMs, so credits are consumed continuously even during low-traffic periods.
- Stopping a VM saves most compute cost immediately, but disks and reserved/public IP items may still incur small charges.

## Stop/Start Without Redeploy

- You can stop and start the instances without redeploying the chain.
- State is preserved on persistent disks.
- Systemd units are enabled, so services auto-recover at boot.
- Validation command after restart:
  - `curl -sS https://rpc.ynxweb4.com/status | jq -r '.result.sync_info.catching_up'`
  - `curl -sS https://ai.ynxweb4.com/ready | jq -r '.ok'`
  - `curl -sS https://web4.ynxweb4.com/ready | jq -r '.ok'`

## New Control Scripts

- IPv4-safe gcloud wrapper:
  - `chain/scripts/gcloud_ipv4.sh`
- One-command stack control:
  - `chain/scripts/v2_gcp_stack_ctl.sh`
- Extreme performance benchmark:
  - `chain/scripts/v2_extreme_perf_bench.sh`

Examples:

```bash
# Show VM status + endpoint health
./chain/scripts/v2_gcp_stack_ctl.sh status

# Stop all 3 YNX v2 GCP instances
./chain/scripts/v2_gcp_stack_ctl.sh stop

# Start and wait until public endpoints are ready
./chain/scripts/v2_gcp_stack_ctl.sh start

# Resize instances (default target: all 3)
./chain/scripts/v2_gcp_stack_ctl.sh rightsize e2-standard-2

# Apply predefined cost/perf profile
./chain/scripts/v2_gcp_stack_ctl.sh mode economy
./chain/scripts/v2_gcp_stack_ctl.sh mode balanced
./chain/scripts/v2_gcp_stack_ctl.sh mode extreme

# One-click read/write benchmark
./chain/scripts/v2_extreme_perf_bench.sh
```

## High-Throughput Runtime Tuning

AI gateway and Web4 hub now support debounced async persistence to reduce write-path blocking.

Key env vars:

- `AI_PERSIST_DEBOUNCE_MS` (default `200`)
- `WEB4_PERSIST_DEBOUNCE_MS` (default `200`)
- `AI_MAX_JOBS`, `AI_MAX_PAYMENTS`, `AI_MAX_VAULTS`
- `WEB4_MAX_INTENTS`, `WEB4_MAX_CLAIMS`, `WEB4_MAX_SESSIONS`, etc.

These are for throughput scaling under high write concurrency while keeping bounded state file growth.

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
