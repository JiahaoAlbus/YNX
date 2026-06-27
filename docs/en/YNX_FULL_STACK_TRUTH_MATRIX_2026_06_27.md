# YNX Full-Stack Truth Matrix

Status: active  
Prepared on: 2026-06-27  
Purpose: one-page truth matrix for what is runnable now, what is mock, what is public testnet, and what still depends on provider, legal, or mainnet-grade work

## 1. Why this exists

YNX now spans:

- chain and validator infrastructure
- public bridge routes
- Web4 policy/session authorization
- AI settlement and agent execution
- protected trace / accountability workflows
- YNX Card mock controls
- outreach, grant, and compliance packets

Those pieces are real, but they do not all sit at the same readiness level.

This document is the shortest honest answer to:

- what is live now
- what is local but not yet reflected in live deployment
- what is intentionally a mock
- what still needs external provider, legal, audit, or mainnet work

## 2. The matrix

| Surface | What it is | State now | Evidence / entry point | What not to claim yet | What is still needed |
|---|---|---|---|---|---|
| Chain / RPC | Live public-testnet chain and RPC | Live public testnet | `https://rpc.ynxweb4.com/status`, `docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md` | mainnet-candidate, institution-ready | more validator redundancy, stronger production ops, external audit |
| Indexer / Explorer | Public indexing and explorer for chain and trace previews | Live public testnet | `https://indexer.ynxweb4.com/health`, `https://explorer.ynxweb4.com/`, `docs/en/EXPLORER.md` | full protected trace is public, full provenance ids are public | keep protected/public boundary intact; wider live observability |
| Web4 policy/session | Wallet bootstrap, policy, session, protected action gates | Runnable locally and deployed live | `docs/en/YNX_v2_WEB4_API.md`, `infra/openapi/ynx-v2-web4.yaml`, `https://web4.ynxweb4.com/ready` | open public write surface, custody, card-issuer authorization | more production hardening and provider integrations |
| AI settlement | Vault-backed AI job and payment flow | Runnable locally and deployed live on public testnet | `docs/en/AI_WEB4_OFFICIAL_DEMO.md`, `docs/en/YNX_v2_AI_SETTLEMENT_API.md`, `https://ai.ynxweb4.com/health` | production financial network, production LLM compliance stack | stronger persistence, more operator telemetry, audit/legal maturity |
| AI agent spending | Policy-bounded machine spending model | Implemented as repo capability and doc/model; partly live through AI settlement rails | `docs/en/AI_AGENT_SPENDING.md`, `scripts/ai_web4_settlement_demo.sh` | unlimited autonomous spending, issuer-backed card spend | provider-backed spend rails, legal/compliance review, production controls |
| Trace base layer | Deterministic fungible-asset traceability | Implemented now | `README.md`, `infra/indexer/server.js`, `infra/indexer/server.test.js`, `docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md` | per-unit permanent serial numbers on every merged/split fragment | more denoms, more anchors, wider ingestion |
| Forensics / accountability | Comparative taint, clustering, labels, patterns, evidence, case reports | Implemented now behind protected flows | `docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md`, `infra/openapi/ynx-v2-ai.yaml`, `GET /ai/forensics/cases` | universal multi-chain forensic platform, self-help seizure authority | broader label providers, more detector families, stronger persistence, external workflows |
| Provenance anchors | Stable origin references on traceable lots | Implemented now | `issuance_id`, `deposit_batch_id`, indexer trace docs/tests | exact lifelong identity for every smallest coin fragment | expand source coverage and provider attestations where applicable |
| Public trace preview | Redacted public search / preview graph | Live public testnet | explorer search UI, `docs/en/EXPLORER.md` | exact anchor ids or full lot-level reconstruction are public | preserve redaction boundary while improving UX |
| Protected trace graph | Full graph traversal for operators / reviewed access | Implemented now; availability depends on protected token path | `GET /trace/graph`, `docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md` | public anonymous full-trace access | keep auth, review, and audit boundaries |
| Bridge routes | Cross-chain lock / mint / release proof surface | Live public testnet with mixed route maturity | `https://rpc.ynxweb4.com/bridge/route-readiness`, bridge blocker and rollout packets | `5/5 full-loop-tested`, all routes automatic | load missing EVM signer for Sepolia routes; deploy/configure BNB testnet lockbox and signer |
| YNX Card Mock | Programmable card-control logic to prove policy and spending controls | Runnable mock, not issuer-backed | `docs/en/YNX_CARD_MOCK.md`, `docs/en/YNX_CARD_MOCK_DEMO.md`, `scripts/ynx_card_mock_demo.sh`, `infra/web4-hub/server.js` | live bank-card issuance, licensed card program, production card network | issuer/processor integration, KYC/compliance/legal entity, settlement/provider agreements |
| Website / grant materials | Public story, diligence, and support packet | Live public website + repo docs | `https://www.ynxweb4.com/`, `docs/en/GRANT_APPLICATION_KIT_2026_06_27.md`, `docs/en/X_TELEGRAM_OUTREACH_KIT_2026_06_27.md` | all engineering is already fully online at production grade | keep docs synced with live route truth and deployment granularity |
| Compliance packet | Truthful non-custodial and readiness boundary | Implemented now as documentation and handoff | `docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md`, `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md` | finished legal sign-off, completed audit coverage | external counsel, formal entity, jurisdiction/legal package, production incident ownership |

## 3. Fast reading by readiness tier

### 3.1 Live now on public testnet

- chain / RPC
- indexer
- explorer
- website
- Web4 hub
- AI gateway
- public bridge readiness board

### 3.2 Implemented in repo, but live deployment is narrower

- newer AI forensics counters on `/health` and `/ready`
- protected trace / case detail workflows
- richer provenance-anchor and case-review detail than public explorer shows

### 3.3 Runnable mock / controlled proof layer

- YNX Card Mock
- bounded AI-agent spending over mock/provider-incomplete card rails

### 3.4 Not yet complete without external counterparties

- issuer-backed real card program
- production bank / processor / network integrations
- mainnet-grade legal and audit package
- full bridge completion on all routes

## 4. Accountability / serial-number decision

YNX should keep the current architecture decision:

- use `lot lineage + pro-rata taint tracking` as the V2 truth base
- add stable provenance anchors where true origin references exist
- add case, risk, clustering, graph, and evidence layers on top
- do **not** describe the system as permanent per-unit serial tracking after
  merges and splits

That means the broader accountability / forensics-engine strategy is already
the correct official direction for YNX, but it should be understood as a V2
strengthening path, not a disconnected rewrite.

Primary architecture note:

- [Accountability / Forensics Engine](/Users/huangjiahao/Desktop/YNX/docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md)

## 5. Strongest safe external wording right now

Safe:

- YNX is a live public-testnet Web4 and AI execution stack
- YNX has real bridge route evidence, but not all routes are equally mature
- YNX has protected accountability / forensics capability for traceable assets
- YNX Card currently proves programmable control logic as a mock layer, not as
  a live issuer-backed payment card

Unsafe:

- all bridge routes are complete or automatic
- every token unit has a permanent lifelong serial number
- YNX already runs a licensed production card program
- YNX is fully audited, legally complete, or institution-ready

## 6. Best companion docs

- [Current full-stack status](/Users/huangjiahao/Desktop/YNX/docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md)
- [Final full-stack handoff](/Users/huangjiahao/Desktop/YNX/docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md)
- [YNX Card Mock](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_MOCK.md)
- [AI Agent Spending](/Users/huangjiahao/Desktop/YNX/docs/en/AI_AGENT_SPENDING.md)
- [Compliance readiness packet](/Users/huangjiahao/Desktop/YNX/docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
