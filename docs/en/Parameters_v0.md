# YNX v0 Parameter Registry (Canonical)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

This document is the canonical registry for **v0 locked defaults** and their implementation hooks.

## 0. Denoms & Units

YNX uses an 18-decimal native coin.

- Base denom (on-chain): `anyxt`
- Display denom (UI): `nyxt`
- Display exponent: `18` (`1 nyxt = 10^18 anyxt`)
- Symbol: `NYXT`

## 1. Chain IDs

YNX uses two distinct identifiers:

- **Cosmos chain id** (string), e.g. `ynx_9001-1`
- **EVM chain id** (EIP-155 `uint64`), e.g. `9001`

The EVM chain id is configured via node config (`app.toml`) and MUST match what wallets use when signing EVM
transactions.

## 2. Confirmation Targets

- UX confirmation (preconfirm receipt): **≤ 1s** target
- Finality target (consensus): **5–8s** target

See `docs/en/Preconfirmations_v0.md`.

## 3. Block-Time Target (v0)

v0 defaults assume a ~**1 second block cadence** for:

- `x/mint` `blocks_per_year = 31,536,000`
- EVM Governor voting period expressed in **blocks**:
  - `voting_period_blocks = 604,800` (7 days @ 1s blocks)

Node operators SHOULD tune CometBFT consensus timeouts accordingly for production networks.

## 4. Tokenomics (v0 Locked Defaults)

### 4.1 Genesis Supply

- Genesis supply: **100,000,000,000 NYXT**

### 4.2 Inflation

- Annual inflation: **2% / year**
- Split:
  - **70%** to validators + delegators
  - **30%** to treasury

### 4.3 Transaction Fee Split

For every fee paid:

- **40%** burn
- **40%** validators (+ delegators via distribution)
- **10%** treasury
- **10%** founder

### 4.4 Genesis Allocation

- Team: **15%** via on-chain vesting (**1y cliff + 4y linear**)
- Treasury reserve: **40%** (governance-controlled)
- Community & ecosystem: **45%** (if `system.community_recipient_address` is unset, defaults to the deployed treasury contract)

See `docs/en/NYXT_Tokenomics_v0.md`.

## 5. Governance (v0 Locked Defaults)

### 5.1 EVM System Governance (Governor + Timelock)

Defaults:

- Voting delay: `1` block
- Voting period: `604,800` blocks (7 days @ 1s blocks)
- Proposal threshold: `1,000,000 NYXT`
- Proposal deposit: `100,000 NYXT`
- Quorum: `10%` (excluding abstain)
- Veto: `33.4%` of votes cast (NO_WITH_VETO)
- Timelock delay: `604,800` seconds (7 days)

### 5.2 Cosmos SDK Governance (Module Authority)

The base chain also sets Cosmos governance defaults to match v0 expectations:

- Min deposit: `100,000 NYXT`
- Voting period: `7d`
- Quorum: `10%`
- Threshold: `50%`
- Veto threshold: `33.4%` (burn-veto enabled)

## 6. Implementation Hooks (Where Enforced)

On the base chain:

- Fee split + inflation-to-treasury: `x/ynx` params
- EVM-native governance execution: EVM system contracts + `IYNXProtocol` precompile

See:

- `docs/en/X_YNX_Module.md`
- `docs/en/Governance_v0.md`
- `docs/en/Protocol_Precompile_v0.md`
