# NYXT Tokenomics (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-09  
Canonical language: English

## 0. Normative Language

Normative keywords are per RFC 2119.

## 1. Token Utility

NYXT is the native token of YNX and MUST be used for:

- Gas fees
- PoS staking/security
- Governance voting power (see `docs/en/Governance_v0.md`)

## 2. Genesis Supply and Inflation

- Genesis supply MUST be **100,000,000,000 NYXT**.
- The protocol MUST mint **2% annual inflation** (rate is a governance parameter but is locked for v0).

### 2.1 Inflation Split

Inflation MUST be split as:

- **70%** to validators and delegators (security rewards)
- **30%** to the on-chain treasury (public goods and ecosystem budget)

> Emission schedule (per-block vs per-epoch) is TBD but MUST be deterministic and auditable.

## 3. Transaction Fee Split

For every transaction fee paid (gas fees), the protocol MUST apply the following split:

- **50%** burned (permanently removed from supply)
- **40%** to validators (and their delegators per delegation rules)
- **10%** to the treasury

## 4. Genesis Allocation (v0)

### 4.1 Team / Founder Allocation

- **15%** (15,000,000,000 NYXT)
- Vesting MUST be **1 year cliff + 4 year linear vesting**.
- Tokens MUST be held in an on-chain vesting contract and the contract addresses MUST be publicly disclosed.

### 4.2 Treasury Reserve (Genesis)

- **40%** (40,000,000,000 NYXT)
- Treasury spending MUST be governed on-chain (see governance spec).

### 4.3 Community & Ecosystem

- **45%** (45,000,000,000 NYXT)
- Distribution SHOULD prioritize real users, developers, and infrastructure contributors, using auditable programs.

## 5. Supply Notes

NYXT supply is elastic due to:

- Inflation minting (+)
- Fee burning (-)

Any dashboards or explorers MUST present supply transparently (total supply, circulating supply, burned supply, treasury holdings).

