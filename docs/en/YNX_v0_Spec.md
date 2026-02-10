# YNX Protocol Specification (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-09  
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

Implementation details that are not yet locked (e.g., the exact BFT variant, committee size parameters, cryptographic primitives for threshold signatures) are explicitly marked **TBD**.

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

### 3.2 Finality (hard confirmation)

Finality is the protocol state where a transaction is considered non-reversible except for extreme protocol failures.

- Finality MUST be driven by the consensus protocol.
- Finality SHOULD be achieved within the target range (5–8 seconds) under typical conditions.

## 4. Execution & Fees

- The execution environment MUST be **EVM-compatible**.
- Transactions MUST pay fees via an EVM-style **gas** model (base fee/priority fee model is RECOMMENDED; exact algorithm TBD).
- Fee handling MUST follow the locked v0 splits defined in `docs/en/NYXT_Tokenomics_v0.md`.

## 5. Consensus Design (v0 Requirements)

### 5.1 Design constraint

Global, permissionless participation at large scale cannot have “every validator votes on every block” at sub-second latency. YNX therefore separates:

- A large validator set (permissionless, long-term decentralization), and
- A **rotating, randomly selected committee** that participates in fast BFT finality for a given window.

### 5.2 Two-signature path

YNX consensus is specified as a two-path confirmation system:

1) **Preconfirm quorum signature** (fast path, UX confirmation) — **TBD**
2) **Finality committee BFT vote** (hard finality) — **TBD**

The protocol MUST define:

- Committee selection mechanism (randomness beacon / VRF) — **TBD**
- Committee rotation schedule (epoch length) — **TBD**
- Slashing conditions for equivocation and safety violations — **TBD**
- Liveness conditions and fallback behavior during partial network failures — **TBD**

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
- MEV and ordering manipulation (policy TBD)
- Bridge and cross-domain risk (minimize trust, clear security boundaries)
- Key management and operational security for validators and system contracts

