# YNX Protocol Specification (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Normative Language

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this document are to be interpreted as described in RFC 2119.

## 1. Scope

This document defines the v0 goals and protocol-level requirements for YNX:

- Sub-second user experience via **preconfirmations**
- Fast **finality** (target 5–8 seconds)
- Permissionless participation (full nodes and validators)
- EVM compatibility and a gas fee model
- A scalable architecture that supports layered execution

This v0 spec reflects the current public implementation and avoids placeholders.

## 2. Goals & Non-goals

### 2.1 Goals

- **UX confirmation (preconfirm)** MUST be available within **≤ 1 second** for typical network conditions.
- **Finality** SHOULD be achieved within **5–8 seconds** for typical network conditions.
- The network MUST remain permissionless: anyone MAY run a full node; anyone MAY become a validator by meeting protocol-defined requirements.
- The execution layer MUST be EVM-compatible for developer and infrastructure adoption.
- The protocol MUST support fully on-chain governance and a treasury.

### 2.2 Non-goals (v0)

- v0 does not require trust-minimized bridges to all external networks.
- v0 does not require mandatory KYC, blacklisting, or privileged freezing of user assets.

## 3. Confirmation Model: Preconfirm vs Finality

### 3.1 Preconfirmations (UX confirmation)

Preconfirmation is a fast acknowledgment that a transaction (or transaction batch) is expected to be included, providing near-instant UX for payments and interactions.

- Preconfirmations MUST be cryptographically verifiable.
- Preconfirmations MUST clearly state their security boundary (they are not finality).
- The protocol SHOULD minimize the probability of preconfirm rollback.

v0 reference implementation:

- Signed preconfirm receipts are exposed via JSON-RPC `ynx_preconfirmTx` (see `docs/en/Preconfirmations_v0.md`).

### 3.2 Finality (hard confirmation)

Finality is the protocol state where a transaction is considered non-reversible except for extreme protocol failures.

- Finality MUST be driven by the consensus protocol.
- Finality SHOULD be achieved within the target range (5–8 seconds) under typical conditions.

## 4. Execution & Fees

- The execution environment MUST be **EVM-compatible**.
- Transactions MUST pay fees via an EVM-style **gas** model using EIP‑1559 base fee + priority fee (implemented via `x/feemarket`).
- Fee handling MUST follow the locked v0 splits defined in `docs/en/NYXT_Tokenomics_v0.md`.

## 5. Consensus Design (v0 Implementation)

YNX v0 uses **CometBFT (Tendermint BFT)**:

- All active validators participate in consensus.
- Blocks are committed with **≥ 2/3 precommit voting power**.
- Finality is achieved at **block commit** (no extra finality committee).

The validator set and voting power are managed by the staking module.

## 6. Layered Scaling (Accepted)

YNX explicitly accepts layered scaling:

- The base chain provides final settlement, governance, and “order modules” (identity/treasury/arbitration).
- High-throughput execution MAY be carried out by execution domains / rollups that post commitments to the base chain.

The base chain MUST define a security boundary for any official scaling layer and SHOULD provide at least one reference implementation (v0 roadmap).

## 7. Differentiation: “Order-State L1”

YNX is not only an execution engine. It aims to standardize protocol-level “order components” (subject registry, treasury/budget, arbitration hooks) so dApps can reuse shared rule infrastructure instead of re-implementing centralized governance and dispute processes.

See `docs/en/Order_Modules_v0.md`.

## 8. Security Considerations (v0)

The design MUST account for:

- Governance capture (whales, collusion) and mitigation via timelocks and veto mechanisms
- Preconfirmation fraud or equivocation and enforcement via slashing
- MEV and ordering manipulation: in v0, ordering is proposer‑controlled within CometBFT rules (no protocol‑level MEV mitigation yet)
- Bridge and cross-domain risk (minimize trust, clear security boundaries)
- Key management and operational security for validators and system contracts
