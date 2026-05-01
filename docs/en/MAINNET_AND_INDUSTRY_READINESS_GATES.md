# YNX Mainnet and Industry Readiness Gates

Status: Active
Last updated: 2026-05-01
Canonical language: English

## Purpose

This document defines the industry-grade gates that YNX must satisfy before using mainnet-candidate, production, or institution-ready language.

## Gate 1 — Public Service Availability

Required:

- RPC, EVM JSON-RPC, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub are reachable by HTTPS;
- chain ID and EVM chain ID match published docs;
- block height advances during verification;
- AI and Web4 readiness endpoints return `ok=true`;
- indexer height is close to live chain height.

Verification:

```bash
./scripts/verify_submission_readiness.sh
```

## Gate 2 — P2P and Validator Redundancy

Required before mainnet-candidate messaging:

- at least `2` public peers visible from canonical RPC `/net_info`;
- at least `4` validators or validator candidates operated across at least `2` regions;
- at least `2` cloud/provider or physical-failure domains for public sentry/full nodes;
- public P2P port `36656` reachable on published peers;
- persistent peers configured both directions where needed;
- documented validator onboarding and emergency replacement process.

Verification:

```bash
./scripts/public_testnet_extreme_readiness.sh
```

Current status on 2026-05-01: this gate is not satisfied.

## Gate 3 — Write-Path Workflow Completeness

Required:

- Web4 policy/session lifecycle works;
- policy enforcement rejects unauthorized writes;
- identity, agent, self-update, replication, intent, claim, challenge, and finalize flows work;
- AI vault, job, commit, finalize, payout, and x402 payment flows work;
- audit logs capture privileged actions.

Current status on 2026-05-01: public HTTPS smoke passed.

## Gate 4 — Security and Cryptography

Required:

- no committed production secrets;
- operator keys protected and rotated by procedure;
- ARES observe mode available in SDK;
- strict ARES enforcement gated behind audited post-quantum provider integration;
- governance, treasury, upgrade, bridge, and root-policy actions protected by multi-signature or threshold controls before mainnet;
- external security audit completed.

References:

- `docs/en/V2_SECURITY_MODEL.md`
- `docs/en/V2_HIGH_ASSURANCE_CRYPTO_MODEL.md`
- `docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md`

## Gate 5 — Non-Custodial Business and Legal Boundary

Required:

- public terms state that YNX does not custody user assets;
- no exchange matching engine;
- no stablecoin issuance or reserve management;
- no consumer KYC business operated by the base protocol company;
- regulated services are delegated to licensed partners or delayed until counsel approves;
- company entity, accounting, tax, security contact, and incident-response ownership are defined.

Reference:

- `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`
- `docs/en/PROJECT_NON_TECHNICAL_LAUNCH_PACKET.md`

## Gate 6 — Documentation and Public Claims

Required:

- English canonical docs are up to date;
- Chinese docs match operational facts;
- public website does not use obsolete GCP-cluster language;
- deployment guide matches Tencent Cloud topology;
- risk disclosures do not promise token price, guaranteed profit, or impossible security claims;
- latest readiness report is linked from internal operator docs.

## Gate 7 — Launch Decision

Mainnet launch is allowed only after:

1. Gates 1–6 pass;
2. legal counsel signs off on the operating model;
3. external audit findings are fixed or explicitly risk-accepted;
4. validator set and P2P topology pass strict readiness;
5. incident-response and rollback drills are completed;
6. governance approves launch parameters.

Until then, correct external wording is:

`YNX public testnet is live and usable, with service and workflow checks passing. Decentralized P2P and validator redundancy are still being completed before mainnet-candidate status.`
