# YNX v2 Validator Bootstrap (Public Testnet)

Status: Active  
Last updated: 2026-02-25

## 1. Goal

Bring a new validator, full-node, or public-RPC node online against an existing YNX v2 public testnet with one script.

## 2. Prerequisites

- Linux server with `curl`, `jq`
- `ynxd` binary in `chain/` (script will auto-build when missing)
- One of:
  - reachable v2 RPC endpoint,
  - v2 release bundle,
  - v2 network descriptor JSON

## 3. Bootstrap from Public Descriptor or Release Bundle

Descriptor-driven bootstrap:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --descriptor https://<INDEXER_HOST>:38081/ynx/network-descriptor \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --reset
```

Release-bundle bootstrap:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --bundle /path/to/ynx_v2_*.tar.gz \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --reset
```

## 4. Bootstrap from Direct RPC

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

## 5. Supported Roles

- `validator` — keeps RPC/REST/EVM local-only; exposes P2P
- `full-node` — local-only service profile without validator intent
- `public-rpc` — exposes RPC/REST/EVM for public client access

## 6. What Script Configures

- Initializes node home
- Pulls `genesis.json` from release bundle or RPC
- Applies seeds / persistent peers from descriptor/bundle/flags
- Configures state sync (`trust_height`, `trust_hash`) when healthy
- Falls back to block sync when trust data is not safe to use
- Applies canonical role profile (`validator`, `full-node`, `public-rpc`)
- Enables REST/JSON-RPC in app config
- Prints ready-to-run validator key + `create-validator` commands

## 7. Start Node

```bash
cd ~/YNX/chain
./ynxd start --home ~/.ynx-v2-validator --chain-id ynx_9102-1 --minimum-gas-prices 0.000000007anyxt
```

## 8. Optional Direct Start

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh --rpc http://<RPC_IP>:36657 --start
```
