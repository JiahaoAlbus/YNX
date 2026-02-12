# Implementation (v0) — What’s in this repo

Status: In progress  
Last updated: 2026-02-12

## Reference implementation (shipping now)

These components are chain-agnostic and will be used regardless of which L1/L2 stack YNX ultimately chooses.

- `packages/contracts`
  - `NYXT` (ERC-20 + Votes) token reference
  - `YNXGovernor` + `YNXTimelock` + `YNXTreasury` (proposal threshold, deposit, 7d voting, 7d timelock, veto option)
  - `NYXTTeamVesting` (1y cliff + 4y linear vesting)
  - Order modules (v0 reference): `YNXOrgRegistry`, `YNXSubjectRegistry`, `YNXArbitration` (opt-in callback model)
  - Layered execution landing (v0 reference): `YNXDomainInbox` (execution-domain / rollup commitments)
- `packages/sdk`
  - `YN...` ⇄ `0x...` address encoding/decoding + CLI (`npx ynx ...`)

## Base-chain (MVP)

- `chain`
  - `ynxd` node built on Cosmos SDK + Cosmos EVM (CometBFT consensus, staking, governance, EVM + JSON-RPC)
  - `x/ynx` protocol module:
    - deterministic system contract deployment during `InitGenesis` (optional)
    - protocol enforcement for fee splits and inflation-to-treasury splits
  - `ynx` JSON-RPC namespace:
    - `ynx_preconfirmTx(txHash)` signed receipts for UX confirmation (v0 preconfirm prototype)
  - Protocol governance bridge (static precompile):
    - `IYNXProtocol` at `0x0000000000000000000000000000000000000810`
    - timelock-restricted `updateParams(...)` for on-chain control of protocol fee/inflation splits
  - Local devnet helper: `chain/scripts/localnet.sh`

## Not implemented yet (next)

- Decentralized preconfirmation (committee / threshold signatures) and the full two-path confirmation model (preconfirm vs BFT finality)
- Additional “order modules” beyond v0: registries (names/permits), reputation/attestations, appeal processes and arbitration economics
