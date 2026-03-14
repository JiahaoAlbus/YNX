# YNX v2 Public Testnet Playbook (Web4 Track)

Status: Active  
Last updated: 2026-02-25

## 0. External Naming (Competition/PR)

- Official English name: `YNX Sovereign Execution Layer`
- Official Chinese name: `YNX 主权执行层`
- Suggested title line: `YNX Sovereign Execution Layer: A Decentralized Execution Network for Web4 and AI Agents`

## 1. Objective

Bring YNX v2 to public-testnet readiness so external users only need:

- endpoint list,
- faucet URL,
- validator onboarding info,
- explorer link.

## 1.1 Local-Only Completion Mode

Before any server rollout, complete local buildout:

```bash
cd ~/YNX/chain
./scripts/v2_local_complete.sh all
```

This ensures code, APIs, smoke tests, and release bundle are complete locally first.

Optional Docker Compose path for the same local stack:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_local_compose.sh up
```

## 2. Required Components

- `ynxd` node (v2 chain-id)
- faucet (`/faucet`)
- indexer (`/health`, `/ynx/overview`, `/blocks`, `/txs`, `/validators`)
- explorer UI
- AI gateway (`/ai/*`)
- Web4 hub (`/web4/*`)
- x402-style resource endpoint (`/x402/resource`)

## 3. Server Preparation

Minimum recommended for each public node:

- 4 vCPU
- 8 GB RAM
- 120 GB SSD
- Ubuntu 22.04+

Open inbound TCP ports:

- `22` (SSH)
- `36656` (P2P)
- `36657` (RPC, public only if needed)
- `38545` (EVM RPC, public only if needed)
- `31317` (REST, optional public)
- `38080` (faucet)
- `38081` (indexer)
- `38082` (explorer)
- `38090` (AI gateway)
- `38091` (Web4 hub)

## 4. One-Command Remote Deploy

From operator machine:

```bash
cd ~/YNX/chain
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset
```

Deploy and run write-path smoke in same command:

```bash
cd ~/YNX/chain
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset --smoke-write
```

Deploy with HTTPS subdomain endpoints (recommended for public websites):

```bash
cd ~/YNX/chain
YNX_PUBLIC_BASE_DOMAIN=ynxweb4.com \
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset --smoke-write
```

Then install HTTPS reverse proxy gateway on the server:

```bash
cd ~/YNX/chain
./scripts/install_v2_caddy_subdomain_gateway.sh ynxweb4.com ops@ynxweb4.com
```

Expected public endpoints after gateway:

- `https://rpc.ynxweb4.com`
- `https://evm.ynxweb4.com`
- `https://evm-ws.ynxweb4.com`
- `https://rest.ynxweb4.com`
- `https://faucet.ynxweb4.com`
- `https://indexer.ynxweb4.com`
- `https://explorer.ynxweb4.com`
- `https://ai.ynxweb4.com`
- `https://web4.ynxweb4.com`

What this command does:

- installs required dependencies,
- pulls latest repo,
- uploads a prebuilt Linux `ynxd` from the operator machine by default,
- installs infra dependencies,
- bootstraps v2 chain home,
- installs systemd stack services,
- runs v2 full verification.

Why prebuilt binary is the default:

- it avoids fresh-server Go module resolution failures,
- it avoids Debian/Ubuntu toolchain drift,
- it keeps the deployed binary exactly aligned with the operator source tree.

## 5. Post-Deploy Verification

On server:

```bash
cd ~/YNX/chain
YNX_PUBLIC_HOST=127.0.0.1 ./scripts/v2_public_testnet_verify.sh
```

From external network:

```bash
curl -s http://<SERVER_IP>:38081/ynx/overview | jq
curl -s http://<SERVER_IP>:38090/health | jq
curl -s http://<SERVER_IP>:38091/web4/overview | jq
```

Write-path smoke test:

```bash
cd ~/YNX/chain
YNX_PUBLIC_HOST=<SERVER_IP> ./scripts/v2_public_testnet_smoke.sh
```

Smoke now validates:

- owner/policy/session delegation model
- wallet bootstrap + verify flow
- AI vault creation + reward settlement + direct machine charge
- x402 payment-required and paid delivery flow
- agent self-update and constrained replication

## 6. Build Validator Bootstrap Bundle

```bash
cd ~/YNX/chain
./scripts/v2_testnet_release.sh
```

Output:

- `ynxd`
- `genesis.json`
- `config.toml`
- `app.toml`
- `endpoints.json`
- `network.json`
- `descriptor.json`
- `bootstrap/v2_validator_bootstrap.sh`
- `bootstrap/v2_role_apply.sh`
- role env profiles
- checksums and tarball

Company-ready local handoff package:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_company_pack.sh
```

## 7. Public Announcement Checklist

Before promotion:

- `v2_public_testnet_verify.sh` passes
- explorer loads and updates blocks
- faucet sends test tokens
- `/ynx/overview` shows `track=v2-web4`
- AI and Web4 APIs are reachable
- at least 2 validators running in bonded state

## 8. Operator Commands

Service status:

```bash
sudo systemctl status ynx-v2-node ynx-v2-faucet ynx-v2-indexer ynx-v2-explorer ynx-v2-ai-gateway ynx-v2-web4-hub --no-pager
```

Service logs:

```bash
sudo journalctl -u ynx-v2-node -f --no-pager
sudo journalctl -u ynx-v2-ai-gateway -f --no-pager
sudo journalctl -u ynx-v2-web4-hub -f --no-pager
```

Public network descriptor:

```bash
curl -s http://<SERVER_IP>:38081/ynx/network-descriptor | jq
```

## 9. Validator Bootstrap (Public Join)

Preferred external validator join via network descriptor:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --descriptor http://<SERVER_IP>:38081/ynx/network-descriptor \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --reset
```

Direct RPC fallback:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --rpc http://<RPC_IP>:36657 \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --seeds '<seed_node_id@seed_ip:36656>' \
  --reset
```

## 10. Watchdog Auto-Restart Service

Install watchdog on each validator node:

```bash
cd ~/YNX/chain
./scripts/install_v2_watchdog_systemd.sh
```

Check watchdog:

```bash
sudo systemctl status ynx-v2-watchdog --no-pager
sudo journalctl -u ynx-v2-watchdog -f --no-pager
```
