# YNX v2 Verify + Smoke

Status: Active  
Last updated: 2026-02-25

## 1. Read-Only Verify

Run core availability and consistency checks:

```bash
cd ~/YNX/chain
YNX_PUBLIC_HOST=<SERVER_IP> ./scripts/v2_public_testnet_verify.sh
```

Checks include:

- RPC chain-id and advancing block height
- EVM chain-id
- REST chain-id
- faucet/indexer/explorer availability
- AI gateway + Web4 hub health and metadata consistency

## 2. Write-Path Smoke

Run end-to-end API write flow:

```bash
cd ~/YNX/chain
YNX_PUBLIC_HOST=<SERVER_IP> ./scripts/v2_public_testnet_smoke.sh
```

Smoke flow includes:

- policy/session issuance and owner control (pause/resume)
- wallet bootstrap and verify
- AI vault + payment charge + x402 resource paywall
- AI job lifecycle: create → commit → finalize (with vault payout)
- Web4 lifecycle: identity + agent + intent → claim → challenge → finalize
- agent self-update and controlled replication

## 3. Deploy and Verify in One Command

```bash
cd ~/YNX/chain
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset --smoke-write
```
