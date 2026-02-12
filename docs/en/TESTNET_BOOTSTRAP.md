# Public Testnet Bootstrap (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Purpose

This document describes how to bootstrap a **public YNX testnet** with:

- A reproducible genesis
- Deterministic deployment of the v0 EVM “system contracts” (NYXT / Governor / Timelock / Treasury)
- A clear path to adding additional validators over time

For a fast local single-node devnet, see `docs/en/CHAIN_DEVNET.md`.

## 1. Terminology

- **Coordinator**: entity that produces the final genesis (`genesis.json`) and publishes it.
- **Genesis validator**: a validator whose `gentx` is included in the genesis.
- **Deployer**: the EVM deployer account used by `x/ynx` to deterministically deploy system contracts at genesis.

## 2. Bootstrap constraints (v0)

### 2.1 System contract deployment at genesis

If `x/ynx` `system.enabled = true`, the coordinator MUST set:

- `system.deployer_address`
- `system.team_beneficiary_address`

`system.community_recipient_address` is OPTIONAL:

- If it is unset, it defaults to the `deployer_address` (bootstrap-friendly; see tokenomics notes below).

See `docs/en/X_YNX_Module.md`.

### 2.2 Founder fee recipient

To enable protocol revenue on every transaction fee, the coordinator SHOULD set:

- `x/ynx` param `founder_address` (bech32)

See `docs/en/NYXT_Tokenomics_v0.md` and `docs/en/X_YNX_Module.md`.

## 3. Quick bootstrap (single-validator testnet home)

The repo ships a helper that bootstraps a single-validator testnet home directory:

```bash
cd chain
./scripts/testnet_bootstrap.sh --reset
```

### 3.1 Generating founder / team / community addresses

YNX uses bech32 account addresses with prefix `ynx1...`.

If you need real addresses to set in genesis (recommended for public testnets), generate them with `ynxd`:

```bash
cd chain
./ynxd keys add founder --keyring-backend os --key-type eth_secp256k1
./ynxd keys show founder --keyring-backend os --bech acc -a
```

To convert between bech32 (`ynx1...`) and EVM hex (`0x...`):

```bash
./ynxd debug addr ynx1...
./ynxd debug addr 0x...
```

Defaults:

- Home: `chain/.testnet`
- Chain ID: `ynx_9002-1`
- EVM chain id: parsed from chain id (fallback `9002`)
- Keyring backend: `test` (non-interactive; not for production funds)
- Denom: `anyxt`

You can override bootstrap fields via environment variables:

```bash
YNX_CHAIN_ID=ynx_9002-1 \
YNX_EVM_CHAIN_ID=9002 \
YNX_COMMUNITY_RECIPIENT=ynx1... \
YNX_FOUNDER_ADDRESS=ynx1... \
./scripts/testnet_bootstrap.sh --reset
```

You may also store these in a repo-local `.env` file (auto-loaded by the script). The script checks `repo/.env` first, then `chain/.env` (override with `YNX_ENV_FILE`).

This creates:

- `config/genesis.json`
- `config/config.toml` / `config/app.toml`
- one validator `gentx` collected into genesis

## 4. Public testnet coordination (multi-validator)

To launch a public testnet with more than one genesis validator, the recommended flow is:

1) Coordinator prepares a base genesis (module params, `x/ynx` system config, funded accounts).  
2) Each validator generates a `gentx` using the published chain id and denom.  
3) Coordinator runs `collect-gentxs` once with all received `gentx` files.  
4) Coordinator publishes the final `genesis.json` plus at least one seed node address.

Operational requirement:

- The `system.deployer_address` SHOULD be a dedicated account and MUST NOT be the same key used for a validator `gentx`
  (system deployment increments account sequence/nonce during `InitGenesis`).

### 4.1 Coordinator workflow (scripted)

1) Create a repo-local `.env` with your real addresses (not committed). The scripts check `repo/.env` first, then `chain/.env`:

```
YNX_FOUNDER_ADDRESS=ynx1...
YNX_TEAM_BENEFICIARY=ynx1...
YNX_COMMUNITY_RECIPIENT=ynx1...
```

2) Initialize base genesis:

```bash
cd chain
./scripts/testnet_coordinator.sh --reset
```

3) Collect validator gentxs in a directory (default: `chain/.testnet/config/gentx`) and add their genesis balances:

```bash
export YNX_VALIDATOR_ACCOUNTS="ynx1...:1000000000000000000000anyxt,ynx1...:1000000000000000000000anyxt"
./scripts/testnet_coordinator.sh --finalize
```

This outputs the finalized `genesis.json` and a SHA256 checksum.

### 4.2 Validator workflow (scripted)

Each validator runs:

```bash
cd chain
export YNX_CHAIN_ID=ynx_9002-1
./scripts/testnet_validator.sh --reset
```

Then sends to the coordinator:

- The generated `gentx-*.json`
- The `node-id` and public P2P address (`node-id@ip:26656`)

### 4.3 Single-machine multi-validator simulation (local only)

If you only have one machine but want to run multiple validators for a realistic testnet topology, use:

```bash
cd chain
./scripts/testnet_multinode.sh --reset --start
```

Options:

- `YNX_VALIDATOR_COUNT=4` to change the number of validators.
- `YNX_JSONRPC_NODE=0` to select which node exposes JSON-RPC (default: node 0).

The script:

- Creates `chain/.testnet-multi/node0`, `node1`, ... with unique ports.
- Generates validator keys in each node home (default keyring: `test`).
- Collects all `gentx` files into a single genesis.
- Connects validators via `persistent_peers`.
- Auto-loads `repo/.env` for founder / team / community addresses (falls back to node0 if unset).

JSON-RPC (default):

- `http://127.0.0.1:8545` (node 0)

Notes:

- This is a **local simulation**, not true decentralization.
- For a public testnet, use the coordinator + validator workflow above.

## 5. Tokenomics bootstrap note (no community yet)

In v0, NYXT ERC20 genesis allocation includes a “community & ecosystem” share.

If you do not have a community recipient at genesis:

- Leave `system.community_recipient_address` unset (it defaults to the deployer address), and
- Document a governance plan to migrate that allocation to a governance-controlled recipient over time.

See `docs/en/NYXT_Tokenomics_v0.md`.
