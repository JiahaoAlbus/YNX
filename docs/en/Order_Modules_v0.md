# “Order-State L1” Modules (v0 Blueprint)

Status: Draft  
Last updated: 2026-02-09  
Canonical language: English

YNX differentiates by providing reusable protocol-level “order components” so applications share the same rule infrastructure.

## 1. Layering

### L0 — Base Chain

Consensus, finality, EVM, gas, staking, RPC/indexing.

### L1 — Order Infrastructure (Core Differentiation)

1) **Subject Registry (Identity / Subjects)**
   - Defines “subjects”: addresses, organizations, contract accounts
   - Supports declarations, control changes, and optional verifiable claims

2) **Organizations & Roles**
   - Organization registration and role-based permissions
   - Standardizes how treasuries, arbitration sets, and public funding operate

3) **Treasury & Budget**
   - On-chain treasury accounting, budget periods, earmarked funds
   - Strict governance + timelock execution

4) **Disputes & Arbitration**
   - Opt-in hooks for contracts/protocols (no protocol-level forced confiscation by default)
   - Case registration, arbitrator sets, rulings, appeal windows, execution hooks

### L2 — Public Services (Optional Network Effects)

Public goods funding frameworks, registries (names/permits), reputation/attestations (pluggable, anti-sybil optional).

## 2. Dependency Order

- Treasury/budget depends on governance.
- Arbitration depends on subjects/orgs (for arbitrator sets and permissions).
- Registries/reputation depend on subjects and arbitration (or they become spam/centralized).

Recommended v0 shipping order:

1) Governance + treasury  
2) Subjects + organizations  
3) Arbitration (opt-in)  

## 3. Global, Permissionless Principles

- No mandatory KYC; no privileged freezing/blacklisting as a default.
- Arbitration is opt-in by default; protocols choose to bind to it.
- Public funds and upgrades are transparent, auditable, and time-locked.

