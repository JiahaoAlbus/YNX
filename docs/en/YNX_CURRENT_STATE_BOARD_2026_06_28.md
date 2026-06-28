# YNX Current State Board

Status: active  
Prepared on: 2026-06-28  
Purpose: the shortest operational truth board for what is live now, what is
mock, what is repo-stronger-than-live, and what still needs external
counterparties

## 1. One-screen summary

| Surface | Current state | Short truth |
|---|---|---|
| Chain / RPC / REST / EVM | Live public testnet | online and usable now |
| Indexer / Explorer | Live public testnet | public chain data and redacted trace previews are online |
| Web4 policy/session | Live + local | protected policy/session gating is deployed and runnable |
| AI settlement | Live + local | vault/job/finalize flow is live on public testnet |
| Bridge | Mixed live maturity | real architecture; only `2/5` routes are `full_loop_tested` today |
| Trace / accountability | Implemented, partly protected | full capability exists; public side is intentionally redacted |
| YNX Card Mock | Runnable mock | logic proof is real; issuer-backed card is not live |
| AI Agent Spending | Repo/live hybrid | bounded spending logic exists; real provider spend rails are not live |
| Grant / external materials | Ready now | strong for grants, sponsors, providers, and technical diligence |
| Compliance / legal | Boundary documented | truthful scope exists; legal entity and formal sign-off are still external work |

## 2. What is live right now

- public-testnet chain and RPC
- EVM RPC and REST
- indexer and explorer
- Web4 Hub
- AI Gateway
- public website
- bridge readiness board
- at least `2/5` bridge routes with `full_loop_tested` evidence

## 3. What is runnable now but should still be described carefully

- protected trace graph and forensics cases
- comparative taint models and lot lineage
- provenance anchors such as `issuance_id` and `deposit_batch_id`
- YNX Card Mock authorization logic
- AI-agent bounded spending model

These are real repo capabilities, but some are intentionally protected or
presented through mock/testnet-only flows rather than public anonymous access.

## 4. What is mock today

- YNX Card as a real issuer-backed card product
- provider-backed programmable authorization against a live card network
- real KYC / issuer / processor / settlement integrations

Safe wording:

- YNX Card currently proves programmable control logic and auditability
- it does **not** yet prove a live regulated card program

## 5. What is blocked by external dependencies

- bridge `5/5 full_loop_tested`
  - current blockers are explicit route configuration/signer/lockbox gaps
- real issuer / processor / network-backed YNX Card
- formal legal entity and company-grade legal sign-off
- external security audit publication
- mainnet-grade reliability, persistence, and operational hardening

## 6. What not to claim today

Do not claim:

- all bridge routes are fully complete
- all bridge routes are automatically releasable
- YNX Card is already a live bank-card program
- YNX is legally complete or fully audited
- YNX is a mainnet-grade production financial network

## 7. Best next document by reader type

- builders: [Builder Readiness Pack](/Users/huangjiahao/Desktop/YNX/output/builder_readiness_pack_latest/MANIFEST.md)
- providers: [Card Provider Readiness Pack](/Users/huangjiahao/Desktop/YNX/output/card_provider_readiness_pack_latest/MANIFEST.md)
- grant reviewers: [Grant Visibility Pack](/Users/huangjiahao/Desktop/YNX/output/grant_visibility_pack_latest/MANIFEST.md)
- mixed diligence: [External Launchpad Pack](/Users/huangjiahao/Desktop/YNX/output/external_launchpad_pack_latest/MANIFEST.md)
- founders/operators: [Executive Closeout Pack](/Users/huangjiahao/Desktop/YNX/output/executive_closeout_pack_latest/MANIFEST.md)

## 8. Companion truth anchors

- [YNX Full-Stack Truth Matrix](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md)
- [Current Full-Stack Status Snapshot](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [YNX External Launchpad](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_EXTERNAL_LAUNCHPAD_2026_06_28.md)
