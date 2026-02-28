# YNX v2 Execution Plan (Web4 / AI-Native)

Status: Active  
Last updated: 2026-02-25

## 1. Strategy

YNX v2 is delivered as a separate track from v1:

- New chain-id
- New genesis
- New public testnet rollout

This prevents v1 operational risk while enabling fast v2 iteration.

## 2. Workstreams

### WS-A: Protocol and Runtime

- Define v2 parameter profile (latency, mempool, gas policy).
- Maintain deterministic BFT finality.
- Introduce execution parallelization roadmap milestones.

### WS-B: AI Settlement Plane

- Job registry and lifecycle (created/committed/finalized/challenged).
- Result commitment format and verification hooks.
- Reward/slash economic flow and dispute timing.

### WS-C: Developer Experience

- EVM tooling compatibility baseline (wallet + RPC + deployment).
- Account abstraction / sponsored transaction feature track.
- SDK and starter template for AI + Web4 dApps.

### WS-D: Infra and Operations

- RPC, indexer, explorer, faucet for v2 chain-id.
- Health checks, watchdog, and alerting.
- Validator onboarding automation and documentation.

### WS-E: Governance and Economics

- v2 parameter registry.
- Governance timelock and execution controls.
- Treasury and fee-routing policy for sustainable ecosystem growth.

## 3. Milestones

### M0 (Complete)

- v2 product target and protocol scope frozen.
- v2 spec + execution plan published.

### M1

- v2 local single-node bootstrap ready.
- v2 runtime profile script ready.
- v2 explorer/indexer positioning metadata updated.

### M2

- v2 multi-node testnet in controlled environment.
- validator onboarding and failover scripts verified.

### M3

- open public testnet for external validators and builders.
- AI settlement API + docs exposed.

### M4

- governance hardening + economic parameter freeze candidate.
- mainnet readiness review.

## 4. Non-Negotiable Quality Gates

- No plaintext secrets in repo.
- Reproducible bootstrap from clean machine.
- Public observability for chain and validator health.
- Backward-incompatible changes documented before release.

## 5. What “Complete v2” Means in This Repository

The repository reaches “v2 complete track” when it includes:

- protocol specification (`YNX_v2_WEB4_SPEC.md`)
- executable bootstrap/profile scripts for v2
- v2 positioning exposed via machine-readable API
- operator docs to run and observe the v2 public testnet

Mainnet launch remains a governance and operations decision after public testnet performance validation.
