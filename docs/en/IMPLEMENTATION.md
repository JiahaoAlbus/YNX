# Implementation (v0) — What’s in this repo

Status: In progress  
Last updated: 2026-02-09

## Reference implementation (shipping now)

These components are chain-agnostic and will be used regardless of which L1/L2 stack YNX ultimately chooses.

- `packages/contracts`
  - `NYXT` (ERC-20 + Votes) token reference
  - `YNXGovernor` + `YNXTimelock` + `YNXTreasury` (proposal threshold, deposit, 7d voting, 7d timelock, veto option)
  - `NYXTTeamVesting` (1y cliff + 4y linear vesting)
  - Order modules (v0 reference): `YNXOrgRegistry`, `YNXSubjectRegistry`, `YNXArbitration` (opt-in callback model)
- `packages/sdk`
  - `YN...` ⇄ `0x...` address encoding/decoding + CLI (`npx ynx ...`)

## Base-chain (MVP)

- `chain`
  - `ynxd` node built on Cosmos SDK + Cosmos EVM (CometBFT consensus, staking, governance, EVM + JSON-RPC)
  - Local devnet helper: `chain/scripts/localnet.sh`

## Not implemented yet (next)

- Preconfirmations (≤ 1s UX) and the two-path confirmation model (preconfirm vs BFT finality)
- Fee split enforcement at the protocol level (50% burn / 40% validators / 10% treasury)
- Inflation minting split enforcement (2% annual, 70% security / 30% treasury)
- Additional “order modules” beyond v0: registries (names/permits), reputation/attestations, appeal processes and arbitration economics
