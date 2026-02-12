# `x/ynx` Module (v0) — Protocol Splits + Genesis System Contracts

Status: In progress  
Last updated: 2026-02-12  
Canonical language: English

## 0. Purpose

`x/ynx` is a chain-specific protocol module that enforces “economic rails” and deploys core EVM governance/treasury contracts deterministically at genesis.

## 1. Responsibilities

`x/ynx` provides:

- Deterministic deployment of v0 EVM “system contracts” during `InitGenesis` (optional).
- Protocol enforcement of the NYXT transaction fee split.
- Protocol enforcement of the inflation-to-treasury split.
- Governance-controlled parameters for the above (Cosmos SDK `authority` = `x/gov`).

## 2. Genesis System Contract Deployment

### 2.1 Enablement

Genesis system deployment is controlled by the `system` section of the `x/ynx` genesis state:

- `system.enabled` — when `true`, `InitGenesis` deploys the system contracts using the EVM keeper and stores the resulting addresses under `system_contracts`.

### 2.2 Inputs (required when enabled)

When `system.enabled = true`, the following fields MUST be set:

- `system.deployer_address` — the EVM deployer (bech32 or `0x...`)
- `system.team_beneficiary_address` — the recipient of the team vesting stream
- `system.community_recipient_address` — the recipient of the community allocation

The remaining fields have v0 defaults (supply, allocation percents, governance thresholds, voting period, timelock delay, vesting schedule).

### 2.3 Determinism and deployer selection

Contract addresses are deterministic under Ethereum CREATE semantics (derived from `deployer_address` and deployer nonce/sequence).

Operational requirement:

- The deployer address SHOULD NOT be the same account used to sign a validator `gentx`, because `InitGenesis` deployment will increment the deployer’s account sequence/nonce.
- Use a dedicated deployer account for genesis system deployment.

The local devnet helper (`chain/scripts/localnet.sh`) uses a dedicated deployer key by default for this reason.

### 2.4 Exported addresses

`x/ynx` stores the deployed contract addresses in state and exposes them via query:

- `ynxd query ynx system-contracts ...`

Current v0 system contracts include:

- `nyxt` (ERC-20 + Votes)
- `timelock`
- `treasury`
- `governor`
- `team_vesting`
- `org_registry`
- `subject_registry`
- `arbitration`
- `domain_inbox` (execution-domain / rollup commitments inbox)

## 3. Protocol Enforcement

### 3.1 Transaction fee split

The module enforces the fee split by moving coins out of the fee collector module account after fee deduction, on every successful DeliverTx.

Default v0 parameters:

- `fee_burn_bps = 4000`
- `fee_treasury_bps = 1000`
- `fee_founder_bps = 1000`
- The remainder is left for validator/delegator distribution.

If `treasury_address` or `founder_address` is unset, the corresponding share defaults to validators.

### 3.2 Inflation-to-treasury split

On each BeginBlock, the module transfers a portion of the current block provision from the fee collector to the treasury address:

- `inflation_treasury_bps = 3000` (v0 default)

This relies on the mint module running before `x/ynx` in BeginBlock ordering.

## 4. Parameters and Governance

`x/ynx` parameters are updated via `MsgUpdateParams` and are restricted to the chain authority (`x/gov`).

In addition, YNX provides an EVM-native governance bridge via a static precompile (`IYNXProtocol` at
`0x0000000000000000000000000000000000000810`) so the v0 timelock system contract can update protocol params
on-chain (see `docs/en/Protocol_Precompile_v0.md`).

Core params:

- `founder_address` (bech32; optional but RECOMMENDED for mainnet)
- `treasury_address` (bech32; if unset and system contracts are enabled, it defaults to the deployed treasury contract address)
- `fee_burn_bps`, `fee_treasury_bps`, `fee_founder_bps`
- `inflation_treasury_bps`

## 5. CLI and Queries

Genesis helper:

```bash
ynxd genesis ynx set --home <home> --ynx.system.enabled --ynx.system.deployer <addr> ...
```

Queries:

```bash
ynxd query ynx params
ynxd query ynx system-contracts
```
