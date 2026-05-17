# YNX Non-Technical Launch Packet

Status: Active
Last updated: 2026-05-17
Canonical language: English

## 1. Public Introduction

YNX is a speed-first Web4 execution and trading layer with EVM-compatible developer access, machine-payment workflows, and owner-policy-session controls for human and agent execution.

Current external wording:

`YNX public testnet is live for developers and operators. Core RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub services are online. The live public-testnet asset is NYXT/anyxt. Mainstream wrapped assets such as BTC, ETH, BNB, USDT, and USDC are planned trading targets, not live public-testnet assets yet.`

## 2. What YNX Is Not

YNX should not be described as:

- a custodian of user assets;
- a centralized exchange;
- a broker or dealer;
- a stablecoin issuer;
- a consumer KYC provider;
- an investment product;
- a promise of token price appreciation.

## 3. Public Claims Rules

Allowed:

- public testnet is live;
- services are reachable;
- Web4 and AI settlement workflows are available for testing;
- EVM JSON-RPC compatibility is available;
- ARES SDK observe-mode implementation exists;
- mainnet readiness is gated by P2P, validator, audit, legal, and governance checks.

Not allowed:

- “unhackable”;
- “quantum-proof forever”;
- “government hackers cannot break it”;
- “guaranteed profit”;
- “mainnet-ready” before readiness gates pass;
- “decentralized validator network” while validator count is `1`.
- “BTC/ETH/BNB are tradable on YNX” before bridge routes, liquidity, and risk controls are live.

## 4. Required Public Pages

Before mainnet-candidate messaging, the public website should include:

- project overview;
- public testnet status;
- developer quickstart;
- endpoint list;
- validator onboarding;
- security model;
- ARES crypto model summary;
- non-custodial business boundary;
- risk disclosures;
- terms of use;
- privacy policy;
- security contact / vulnerability disclosure.
- public asset status and risk disclosures.

## 5. Company and Operations Checklist

Before commercial launch:

- choose operating entity and jurisdiction;
- appoint responsible owner for security, ops, legal, finance, and developer relations;
- create security contact email;
- create abuse/contact email;
- create incident-response escalation channel;
- define data retention for public services;
- define customer contract templates for API/SLA/private deployments;
- define tax/accounting process for fiat revenue;
- confirm no regulated product is launched without counsel approval.

## 6. Deployment Procedure Summary

Current infrastructure baseline:

- Tencent Cloud Singapore canonical public stack;
- public HTTPS endpoints under `ynxweb4.com`;
- P2P TCP `36656` published for node connectivity;
- GCP is historical/archived and must not be used in current public wording.

Operator deployment flow:

1. Deploy or update server from tagged repository state.
2. Run local service health checks.
3. Run public runtime evidence capture.
4. Run HTTPS write-path smoke.
5. Run extreme readiness check.
6. If P2P/validator gates fail, keep status as public testnet, not mainnet-candidate.

## 7. Current Readiness References

- `docs/en/PUBLIC_TESTNET_READINESS_REPORT_2026_05_01.md`
- `docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md`
- `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`
- `docs/en/V2_HIGH_ASSURANCE_CRYPTO_MODEL.md`
- `docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md`

## 8. Founder Answer Bank

Does YNX touch user assets?

- No. Users keep their own keys and assets.

Does YNX run custody?

- No. The base project should remain non-custodial.

Does YNX run an exchange?

- Not as the base protocol company unless counsel approves a licensed/legal
  structure. The product direction can support fast trading UX, wrapped assets,
  and partner/DEX liquidity without pretending the base protocol is already a
  regulated exchange.

Can YNX trade BTC, ETH, and BNB today?

- Not yet as official real external assets. Today the live public-testnet asset
  is NYXT/anyxt. BTC, ETH, BNB, USDT, and USDC are priority wrapped-asset targets
  for the speed-first trading roadmap.

Does YNX issue a stablecoin?

- No. YNX should not issue or manage stablecoin reserves.

Does YNX run KYC?

- No as a base protocol business. Regulated partners can perform KYC if needed for their own products.

How does YNX make money?

- Hosted APIs, enterprise Web4/AI infrastructure, private deployments, SLA support, validator tooling, monitoring, SDK/API access, audits/integration support, and governance-approved protocol fees.

What if NYXT is worthless?

- The company must survive on fiat-priced SaaS/API/support/private deployment revenue. NYXT should be utility alignment, not the only business model.

Where should the company be opened?

- Current practical default: Singapore operating company, with optional foundation/governance entity if needed and optional Delaware C-Corp only if U.S. financing or U.S. enterprise sales become primary.
