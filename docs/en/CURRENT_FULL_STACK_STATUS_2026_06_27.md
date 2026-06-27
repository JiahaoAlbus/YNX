# YNX Current Full-Stack Status and Alignment Snapshot

Status: active working snapshot  
Verified on: 2026-06-27  
Scope: current repository state + live public endpoint spot-checks

## 1. Why this document exists

This document is the practical alignment note for:

- current local repository capabilities
- current live public endpoint behavior
- current public bridge / AI / Web4 / explorer truth boundary
- current compliance-readiness packet entry points

It is intentionally narrower and more current than older launch-grade or
readiness reports.

Repeatable snapshot command:

```bash
./scripts/current_full_stack_status_snapshot.sh
```

Repeatable live-vs-local runtime alignment audit:

```bash
./scripts/verify_live_runtime_alignment.sh
```

Founder/operator evidence-pack command:

```bash
./scripts/prepare_full_stack_evidence_pack.sh
```

Stable latest generated artifacts:

- [Latest full-stack snapshot markdown](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [Latest full-stack snapshot json](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json)
- [Latest runtime alignment markdown](/Users/huangjiahao/Desktop/YNX/output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md)
- [Latest runtime alignment json](/Users/huangjiahao/Desktop/YNX/output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json)
- [Latest bridge blocker packet markdown](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md)
- [Latest bridge blocker packet json](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.json)
- [Latest live alignment rollout packet markdown](/Users/huangjiahao/Desktop/YNX/output/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md)
- [Latest live alignment rollout packet json](/Users/huangjiahao/Desktop/YNX/output/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.json)

## 2. Live public facts verified on 2026-06-27

The following live checks were verified directly:

- RPC status:
  - endpoint: `https://rpc.ynxweb4.com/status`
  - chain id: `ynx_9102-1`
  - latest height observed: `2155498`
  - catching up: `false`
- Indexer health:
  - endpoint: `https://indexer.ynxweb4.com/health`
  - `ok=true`
  - `last_indexed=2155539`
  - `latest_seen=2155539`
- AI Gateway health:
  - endpoint: `https://ai.ynxweb4.com/health`
  - `ok=true`
  - policy enforcement: enabled
  - Web4 authorizer: present
  - LLM mode: `ollama`, model `qwen2.5:1.5b`
  - on-chain AI settlement mode: enabled and ready
  - current stats observed: `8 jobs`, `7 vaults`, `9 payments`
  - current live health still does **not** expose forensic-case review /
    escalation breakdown counters
- Web4 Hub readiness:
  - endpoint: `https://web4.ynxweb4.com/ready`
  - `ok=true`
  - policy enforcement: enabled
  - internal authorizer: enabled
- Public website AI page:
  - endpoint: `https://www.ynxweb4.com/ai`
  - HTTP `200`
- Public explorer root:
  - endpoint: `https://explorer.ynxweb4.com/`
  - HTTP `200`

## 3. Real bridge status today

Current bridge route-readiness summary from
`https://rpc.ynxweb4.com/bridge/route-readiness`:

- total routes: `5`
- `full_loop_tested`: `2/5`
- `deposit_tested`: `4/5`
- `automatic_loop_ready`: `2/5`
- `mapped_route_only`: `1/5`

This means:

- YNX should **not** currently claim `5/5 full-loop-tested`
- YNX should **not** currently claim that all bridge routes are automatically
  releasable
- the public bridge still proves real architecture and working route evidence,
  but only `2/5` routes currently satisfy the stronger full-loop-tested claim

### 3.1 Route reality at a glance

- `btc-testnet-btc`
  - phase: `full_loop_tested`
  - automatic: yes
- `tron-shasta-usdt`
  - phase: `full_loop_tested`
  - automatic: yes
- `eth-sepolia-eth`
  - phase: `deposit_tested`
  - blocker: `release_pending_signer`
- `eth-sepolia-usdc`
  - phase: `deposit_tested`
  - blocker: `release_pending_signer`
- `bnb-testnet-bnb`
  - phase: `mapped_route_only`
  - blockers: source lockbox not deployed / configured, signer missing

### 3.2 Current bridge blockers

The live route-readiness output currently points to these concrete blockers:

- high priority:
  - load `BRIDGE_SOURCE_EVM_PRIVATE_KEY` for:
    - `eth-sepolia-eth`
    - `eth-sepolia-usdc`
- high priority:
  - deploy and configure source lockbox for:
    - `bnb-testnet-bnb`
  - also load `BRIDGE_SOURCE_EVM_PRIVATE_KEY` for BSC route

So the current bridge gap is not "unknown." It is specific and configuration
scoped.

Stable remediation packet for the current blockers:

- [BRIDGE_BLOCKER_PACKET.md](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md)
- [BRIDGE_BLOCKER_PACKET.json](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.json)

Stable rollout packet for the remaining live/local gaps:

- [LIVE_ALIGNMENT_ROLLOUT_PACKET.md](/Users/huangjiahao/Desktop/YNX/output/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md)
- [LIVE_ALIGNMENT_ROLLOUT_PACKET.json](/Users/huangjiahao/Desktop/YNX/output/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.json)

## 4. Local repository state versus live public state

Current local repository state is stronger than the current public bridge route
count in several areas.

### 4.1 Local / repository capabilities now present

The repository currently contains:

- protected lot-lineage tracing
- comparative taint models
- structured forensics case creation and review
- provenance-anchor support:
  - `issuance_id`
  - `deposit_batch_id`
- protected full trace surfaces
- public redacted trace previews
- stricter AI/Web4 read/write policy scoping
- stricter bootstrap signature and API-key controls
- stricter vault funding defaults

### 4.2 Live public status is narrower than local code scope

Current live public truth should therefore be stated carefully:

- chain, AI gateway, Web4 hub, indexer, explorer, and website are online
- bridge architecture is real and multiple routes have working evidence
- only `2/5` routes currently justify the strongest `full_loop_tested` wording
- provenance-anchor and protected forensics capabilities exist in the codebase,
  but public explorer/search intentionally exposes only redacted previews
- current local AI gateway code can also expose forensic-case workflow
  breakdowns on `/health` and `/ready`, but the current live public deployment
  does not yet expose those newer counters

This is the correct "online vs local granularity alignment" posture:

- do not downgrade real local capability
- do not overstate live route completion
- do keep public-versus-protected evidence boundaries explicit

### 4.3 AI runtime visibility gap that still exists today

There is also a smaller but real runtime-visibility gap:

- local code now supports AI-health visibility for:
  - total forensic cases
  - forensic cases by review status
  - forensic cases by escalation status
  - persistence metadata such as writes and last persist time
- the current live AI health response still exposes:
  - jobs
  - vaults
  - payments
  - job status counts
- the current live AI health response does **not** yet expose the newer
  forensic workflow counters

So the current truth is:

- the capability exists in the repository
- the current live deployment has not yet caught up to that newer runtime
  visibility shape

That gap is smaller than the bridge blocker gap, but it is still worth
recording because it affects operator observability and online/local alignment.

## 5. Public versus protected trace boundary

Current trace/accountability behavior is intentionally split:

- protected trace surfaces can include:
  - full lot lineage
  - `tainted_amount`
  - exact `issuance_id`
  - exact `deposit_batch_id`
  - full case evidence and dossier state
- public explorer/search can include:
  - path previews
  - counterparty directionality
  - root-origin previews
  - provenance-anchor count summaries
- public explorer/search should omit:
  - exact `issuance_id`
  - exact `deposit_batch_id`
  - full lot-transfer reconstruction fields
  - full tainted-amount reconstruction payloads

This is a deliberate security and privacy boundary, not a missing feature.

## 6. Compliance-readiness entry points

The main current compliance packet entry points remain:

- [Compliance packet](/Users/huangjiahao/Desktop/YNX/docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
- [Non-custodial boundary](/Users/huangjiahao/Desktop/YNX/docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md)
- [Mainnet and industry readiness gates](/Users/huangjiahao/Desktop/YNX/docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md)
- [Production hardening roadmap](/Users/huangjiahao/Desktop/YNX/docs/en/PRODUCTION_HARDENING_ROADMAP.md)
- [Audit submission packet](/Users/huangjiahao/Desktop/YNX/docs/en/V2_AUDIT_SUBMISSION_PACKET.md)
- [Security response policy](/Users/huangjiahao/Desktop/YNX/docs/en/SECURITY_RESPONSE_POLICY_2026_06_13.md)

## 7. What is true to say right now

Safe, accurate current wording:

- YNX is a live public-testnet Web4 and AI-execution stack
- the chain, AI gateway, Web4 hub, indexer, explorer, and website are online
- YNX has real bridge route evidence, but only `2/5` routes currently justify
  the strongest full-loop-tested claim
- protected accountability / forensics capabilities now go beyond simple
  balance tracing and include provenance anchors, case reports, and review flow
- the project should still be positioned as non-custodial testnet
  infrastructure rather than a fully licensed production financial service

Unsafe or inaccurate current wording:

- `5/5 routes are full-loop-tested today`
- `all bridge routes are fully automatic today`
- `YNX is already mainnet-candidate`
- `YNX already has completed external legal and audit sign-off`

## 8. Immediate next alignment actions

1. bring live bridge route truth closer to local/docs expectations by fixing:
   - Sepolia release signer configuration
   - BSC lockbox + signer configuration
2. keep public trace preview redacted while preserving protected full-detail
   case surfaces
3. continue aligning current-status documents with live public evidence instead
   of older launch reports
4. keep compliance packet language tied to non-custodial public-testnet reality

## 9. Supporting evidence generated this turn

- docs verification report:
  [docs_verification_report_20260627_091751.md](/Users/huangjiahao/Desktop/YNX/output/docs_verification_report_20260627_091751.md)

Direct live commands used:

```bash
curl -sS https://rpc.ynxweb4.com/status | jq
curl -sS https://indexer.ynxweb4.com/health | jq
curl -sS https://ai.ynxweb4.com/health | jq
curl -sS https://web4.ynxweb4.com/ready | jq
curl -sS https://rpc.ynxweb4.com/bridge/route-readiness | jq
curl -I -sS https://explorer.ynxweb4.com/
curl -I -sS https://www.ynxweb4.com/ai
```
