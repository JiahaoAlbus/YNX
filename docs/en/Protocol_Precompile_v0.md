# Protocol Precompile (v0) — `IYNXProtocol`

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Overview

YNX exposes protocol-economic parameters to the EVM via a **static precompile** (“native contract”).

- Address: `0x0000000000000000000000000000000000000810`
- Name: `IYNXProtocol`

This precompile is intended to bridge EVM-native governance (Governor + Timelock) to protocol parameters stored in
`x/ynx`.

## 1. ABI

The precompile implements:

- `getParams() → (address founder, address treasury, uint32 feeBurnBps, uint32 feeTreasuryBps, uint32 feeFounderBps, uint32 inflationTreasuryBps)`
- `getSystemContracts() → (address nyxt, address timelock, address treasury, address governor, address teamVesting, address orgRegistry, address subjectRegistry, address arbitration, address domainInbox)`
- `updateParams(address founder, address treasury, uint32 feeBurnBps, uint32 feeTreasuryBps, uint32 feeFounderBps, uint32 inflationTreasuryBps) → (bool ok)`

## 2. Access control

`updateParams(...)` is **restricted**:

- It MUST revert unless `msg.sender == system_contracts.timelock`.

This ensures that protocol parameter updates are executed through the v0 timelock queue.

## 3. Parameter semantics

Basis points:

- `BPS_DENOMINATOR = 10_000`
- The fee split constraints are:
  - `feeBurnBps ≤ 10_000`
  - `feeTreasuryBps ≤ 10_000`
  - `feeFounderBps ≤ 10_000`
  - `feeBurnBps + feeTreasuryBps + feeFounderBps ≤ 10_000`
- `inflationTreasuryBps ≤ 10_000`

Addresses:

- `founder` and `treasury` are EVM addresses.
- `address(0)` means “unset” (the corresponding share defaults to validators).

## 4. Storage mapping (`x/ynx`)

The precompile updates `x/ynx` module params:

- `founder_address` (bech32 string)
- `treasury_address` (bech32 string)
- `fee_burn_bps`, `fee_treasury_bps`, `fee_founder_bps`
- `inflation_treasury_bps`

The precompile converts EVM addresses to the chain’s bech32 account format internally.

## 5. Governance usage (v0)

The intended v0 flow is:

1) A proposal is created in `YNXGovernor`.
2) If passed, it is queued in `YNXTimelock`.
3) The timelock executes an EVM call to `0x...0810` with `updateParams(...)` calldata.

This provides a fully on-chain and auditable mechanism for protocol-economic changes.

## 6. Devnet demo

On a running local chain devnet (`chain/scripts/localnet.sh`), you can run an end-to-end governance flow (proposal → vote
→ queue → execute) that calls `IYNXProtocol.updateParams(...)`:

```bash
npm --workspace @ynx/contracts run ynxdev:governance-e2e
```

See `docs/en/CHAIN_DEVNET.md` for the recommended fast-governance dev mode.
