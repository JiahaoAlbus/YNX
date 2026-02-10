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

## Not implemented yet (next)

- Base-chain client (consensus, validator set, fee split enforcement at protocol level, inflation minting)
- Preconfirmations (≤ 1s UX) and the finality path (5–8s target)
- Additional “order modules” beyond v0: registries (names/permits), reputation/attestations, appeal processes and arbitration economics
