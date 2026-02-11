# YNX / NYXT

YNX is a permissionless, EVM-compatible network targeting **sub-second user experience** (via preconfirmations) while preserving **open participation** and **fully on-chain governance**. NYXT is the native token (gas, staking, governance).

This repository contains:

- v0 protocol specs (canonical)
- v0 reference implementation (system contracts + SDK)
- base-chain MVP (`ynxd`) built on Cosmos SDK + Cosmos EVM

## Canonical Docs (English)

- `docs/en/INDEX.md` (start here)

## v0 Parameters (Locked)

- UX confirmation (preconfirm): **≤ 1s**
- Finality target: **5–8s**
- Execution: **EVM-compatible**, **gas** fee model
- Token: **NYXT**
- Genesis supply: **100,000,000,000 NYXT**
- Inflation: **2% / year** (70% validators+delegators, 30% treasury)
- Fee split: **40% burn / 40% validators / 10% treasury / 10% founder**
- Team allocation: **15%**, **1y cliff + 4y linear vesting** (on-chain, public)
- Treasury (genesis reserve): **40%** (spend via on-chain governance)
- Governance: proposer stake **1,000,000 NYXT**, deposit **100,000 NYXT**, voting **7d**, timelock **7d**

## Quickstart

```bash
npm install
npm test
```

Devnet:

```bash
# YNX chain devnet (node + JSON-RPC)
(cd chain && ./scripts/localnet.sh --reset)

# terminal 1
npm --workspace @ynx/contracts run devnet:node

# terminal 2
npm --workspace @ynx/contracts run devnet:deploy
```

YN address CLI:

```bash
npx ynx address encode 0x0000000000000000000000000000000000000000
npx ynx address decode <YN...>
```
