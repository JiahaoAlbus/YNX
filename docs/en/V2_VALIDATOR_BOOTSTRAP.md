# YNX v2 Validator Bootstrap (Public Testnet)

Status: Active  
Last updated: 2026-02-25

## 1. Goal

Bring a new validator/full-node online against an existing YNX v2 public testnet with one script.

## 2. Prerequisites

- Linux server with `curl`, `jq`
- `ynxd` binary in `chain/` (script will auto-build when missing)
- At least one reachable v2 RPC endpoint

## 3. Bootstrap Command

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --rpc http://<RPC_IP>:36657 \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --seeds '<seed_node_id@seed_ip:36656>' \
  --reset
```

## 4. What Script Configures

- Initializes node home
- Pulls live `genesis.json` from RPC
- Applies seeds / persistent peers
- Configures state sync (`trust_height`, `trust_hash`)
- Enables REST/JSON-RPC in app config
- Prints ready-to-run validator key + `create-validator` commands

## 5. Start Node

```bash
cd ~/YNX/chain
./ynxd start --home ~/.ynx-v2-validator --chain-id ynx_9102-1 --minimum-gas-prices 0.000000007anyxt
```

## 6. Optional Direct Start

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh --rpc http://<RPC_IP>:36657 --start
```
