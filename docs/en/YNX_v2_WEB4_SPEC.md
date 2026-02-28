# YNX Protocol Specification (v2 Web4 Track)

Status: Active Draft  
Version: v2.0-draft  
Last updated: 2026-02-25  
Canonical language: English

## 0. Normative Language

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, **SHOULD NOT**, **RECOMMENDED**, **MAY**, and **OPTIONAL** in this document are to be interpreted as described in RFC 2119.

## 1. Scope

YNX v2 is defined as an **AI-native Web4 execution chain**:

- Ethereum-grade developer compatibility
- Solana-class performance targets
- Fully on-chain governance and treasury control
- Decentralized validator participation
- Native AI workload settlement and verification rails

The v2 track is a protocol reset track, not a minor patch of v1.

## 2. Product Positioning

### 2.1 One-line Positioning

YNX v2 is a **Web4 chain for AI applications** with **EVM-first developer experience** and **high-throughput low-latency execution**.

### 2.2 Target Users

- AI agent and AI application developers
- Real-time consumer dApp teams
- Operators who need transparent governance and predictable fees
- Validator operators joining an open network

## 3. Design Goals and SLOs

### 3.1 Performance Goals

- UX confirmation SHOULD target **≤ 1s** for normal network conditions.
- Final confirmation SHOULD target **2–4s regional** and **≤ 6s cross-region**.
- Throughput SHOULD scale via parallel execution and multi-lane mempool design.

### 3.2 Developer Experience Goals

- Ethereum JSON-RPC compatibility MUST remain first-class.
- Smart contract deployment flow MUST stay compatible with mainstream EVM tools.
- Account abstraction and sponsored gas flow SHOULD be native protocol capabilities.

### 3.3 AI/Web4 Goals

- The chain MUST support AI task settlement (task registration, result commitment, reward/penalty settlement).
- AI execution MAY happen off-chain, but result integrity MUST be verifiable on-chain (proofs, attestations, or stake-backed challenge flow).
- AI-specific economic primitives (job deposits, slashing, dispute windows) MUST be governance-controlled and auditable.
- Machine-payment flows SHOULD support HTTP 402/x402 shape for service-to-service usage.

### 3.4 Decentralization Goals

- Validator onboarding MUST stay permissionless.
- Governance changes MUST be on-chain with transparent timelocks.
- Network health and validator liveness MUST be externally observable via public APIs.

### 3.5 Sovereignty Goals

- User sovereignty MUST remain superior to agent autonomy.
- The control order MUST be: **Owner > Policy > Session Key > Agent Action**.
- Owner MUST have immediate pause/revoke authority for all delegated sessions.
- Delegated session credentials MUST be time-bounded and scope-bounded.

## 4. Architecture Overview

### 4.1 Execution Layer

- EVM compatibility is retained.
- v2 introduces a **parallel execution roadmap**:
  - conflict-aware transaction scheduling,
  - deterministic execution lanes,
  - state-commit integrity checks.

### 4.2 Consensus Layer

- BFT finality remains the baseline for deterministic final confirmation.
- Consensus parameters are profile-based:
  - fast profile (regional low-latency),
  - resilient profile (cross-region stability).

### 4.3 Mempool and Fee Market

- Local fee market design SHOULD reduce global fee contention.
- Base fee + priority fee mechanics remain supported.
- Sponsored transaction and paymaster-like patterns are v2 first-class goals.

### 4.4 AI Settlement Plane

v2 defines a protocol plane for AI jobs:

- Job creation (demand side)
- Worker commitment and execution proof submission (supply side)
- Result acceptance/challenge window
- Reward and slash settlement

### 4.5 Web4 Sovereignty Plane

The v2 public track includes machine-operable primitives:

- Wallet bootstrap (`/web4/wallet/bootstrap`, `/web4/wallet/verify`)
- Policy registry (`/web4/policies`)
- Session issuance and bounded capability delegation (`/web4/policies/:id/sessions`)
- Agent controlled self-update (`/web4/agents/:id/self-update`)
- Agent controlled replication (`/web4/agents/:id/replicate`)
- Audit log surface (`/web4/audit`)

## 5. Governance and Upgrade Safety

- All critical v2 parameters MUST be modifiable only through on-chain governance.
- Governance executions MUST be timelocked.
- A staged release policy MUST be followed:
  1. devnet
  2. private testnet
  3. public testnet
  4. mainnet candidate

## 6. Compatibility Policy

- v1 and v2 are treated as separate network tracks (different chain-id/genesis).
- Tooling compatibility with EVM wallets and SDKs MUST be preserved.
- Any breaking change MUST be documented with migration notes before rollout.

## 7. Security Baseline

- No privileged hidden backdoors.
- Validator and operator key material MUST never be committed.
- AI settlement logic MUST include anti-spam deposits, challenge periods, and slashable misbehavior criteria.
- Public observability endpoints MUST be maintained for consensus and governance data.
- Policy/session controls MUST enforce operation count and spend ceilings.
- Machine-payment vaults MUST enforce per-payment and per-day limits.
- Critical autonomous actions MUST be externally auditable.

## 8. Delivery Definition (v2 Public Testnet Exit Criteria)

The v2 public testnet is considered feature-complete only when:

- Stable block production under multi-validator operation
- Public RPC/EVM RPC/indexer/explorer/faucet availability
- AI task settlement endpoints exposed and documented
- Governance proposal flow validated end-to-end
- Incident response and watchdog automation active
