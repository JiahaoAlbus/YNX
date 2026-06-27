# YNX Final Full-Stack Handoff Snapshot

Status: active working handoff  
Prepared on: 2026-06-27  
Purpose: one-document handoff for current truth, completed work, remaining blockers, and compliance entry points

## 1. Executive summary

YNX now has a much stronger and clearer full-stack baseline than it did at the
start of this work cycle.

What is materially true now:

- the chain, indexer, explorer, AI gateway, Web4 hub, and website are online
- the AI/Web4 write path and protected read path are significantly harder than
  before
- the trace/accountability stack now has:
  - lot lineage
  - comparative taint models
  - structured forensics cases
  - provenance anchors (`issuance_id`, `deposit_batch_id`)
  - public redacted previews versus protected full-detail access
- live bridge evidence is real, but current strongest truth is still `2/5`
  `full_loop_tested`, not `5/5`

This means YNX is much closer to a disciplined, defensible public-testnet
infrastructure story, but it is not yet at a truthful "everything complete"
state.

## 2. What was completed in this improvement cycle

### 2.1 Security and funds-safety hardening

The stack now has stronger controls around:

- AI/Web4 protected read surfaces
- policy-scoped access boundaries
- audit redaction
- vault funding defaults
- bootstrap signature verification
- bootstrap API-key expiry and one-time-use style constraints
- public-versus-protected forensics boundary

### 2.2 Accountability / forensics strengthening

The trace and forensics layer now has:

- deterministic lot-lineage tracing
- comparative taint models:
  - poison
  - pro-rata
  - fifo
  - lifo
  - specific trace
- protected case creation / review / escalation state
- provenance anchor propagation:
  - `issuance_id`
  - `deposit_batch_id`
- case dossier output
- evidence-chain output

### 2.3 Public-versus-protected truth boundary

The explorer/search layer now follows a clearer boundary:

- public side:
  - redacted graph preview
  - path and counterparty visibility
  - provenance-anchor count summaries
- protected side:
  - exact lineage detail
  - exact provenance anchors
  - case evidence and review state

This is important for both safety and compliance positioning.

### 2.4 Status and alignment tooling

The repository now includes a repeatable live snapshot command:

```bash
./scripts/current_full_stack_status_snapshot.sh
```

This produces machine-readable and human-readable status artifacts for the
current full stack.

The repository now also includes a direct live runtime alignment audit:

```bash
./scripts/verify_live_runtime_alignment.sh
```

This produces a PASS/WARN/FAIL alignment report showing where live deployment
matches or lags current local/runtime expectations.

The repository now also includes a one-command founder/operator evidence pack:

```bash
./scripts/prepare_full_stack_evidence_pack.sh
```

This bundles the latest snapshot, latest alignment report, docs verification,
and core current-state/compliance docs into one stable handoff folder plus
archive.

The repository now also includes a one-command grant / visibility pack:

```bash
./scripts/prepare_grant_visibility_pack.sh
```

This bundles the latest truthful status evidence, grant target shortlist,
application templates, outreach copy, and diligence/compliance boundary docs
into one stable outward-facing pack.

The repository now also includes a top-level executive closeout pack:

```bash
./scripts/prepare_executive_closeout_pack.sh
```

This orchestrates the snapshot, runtime alignment audit, founder/operator
evidence pack, and grant/visibility pack into one highest-level closeout
folder and archive.

The repository now also includes a closeout-pack verifier:

```bash
./scripts/verify_latest_closeout_packs.sh
```

This checks that the latest packs exist, their `SHA256SUMS.txt` files match,
their artifact index resolves to real files, and their key manifest links are
still present.

## 3. Current live full-stack status

The canonical current-status source is:

- [Current full-stack status and alignment snapshot](/Users/huangjiahao/Desktop/YNX/docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md)

The latest generated artifact from the new snapshot script is:

- [CURRENT_FULL_STACK_STATUS.md](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [CURRENT_FULL_STACK_STATUS.json](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json)

The latest generated live runtime alignment audit is available at:

- [LIVE_RUNTIME_ALIGNMENT.md](/Users/huangjiahao/Desktop/YNX/output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md)
- [LIVE_RUNTIME_ALIGNMENT.json](/Users/huangjiahao/Desktop/YNX/output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json)

The latest generated bridge blocker remediation packet is available at:

- [BRIDGE_BLOCKER_PACKET.md](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md)
- [BRIDGE_BLOCKER_PACKET.json](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.json)

Current live truth at the time of the latest captured snapshot:

- RPC online on `ynx_9102-1`
- chain height advancing
- indexer online and caught up at snapshot time
- AI gateway online, policy-enforced, on-chain settlement ready
- Web4 hub online and policy-enforced
- explorer online
- website `/ai` online

## 4. Current bridge truth

Current strongest bridge truth:

- `5` routes total
- `2` `full_loop_tested`
- `4` `deposit_tested`
- `2` `automatic_loop_ready`
- `1` `mapped_route_only`

This must remain the canonical public wording until live route readiness
changes.

## 5. Remaining critical blockers

### 5.1 Bridge blockers

The highest-signal live blockers remain:

- `eth-sepolia-eth`
  - missing `BRIDGE_SOURCE_EVM_PRIVATE_KEY`
- `eth-sepolia-usdc`
  - missing `BRIDGE_SOURCE_EVM_PRIVATE_KEY`
- `bnb-testnet-bnb`
  - missing source lockbox deployment/configuration
  - missing `lockboxAddress`
  - missing `BRIDGE_SOURCE_EVM_PRIVATE_KEY`

### 5.2 Mainnet / industry blockers

The larger non-testnet blockers remain:

- stronger validator and P2P redundancy
- production-grade durable persistence
- external security audit
- company/legal sign-off
- final legal and incident-response ownership maturity

## 6. Safe external wording right now

Safe wording:

- YNX is a live public-testnet Web4 and AI-execution stack
- YNX has real bridge route evidence
- YNX has protected accountability/forensics capabilities
- YNX should be positioned as non-custodial infrastructure today

Unsafe wording:

- `5/5 routes are full-loop-tested`
- `all bridge routes are automatic`
- `mainnet-candidate`
- `institution-ready`
- `fully audited and legally signed off`

## 7. Compliance and legal packet entry points

Primary documents:

- [Compliance readiness packet](/Users/huangjiahao/Desktop/YNX/docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
- [Non-custodial business and compliance boundary](/Users/huangjiahao/Desktop/YNX/docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md)
- [Mainnet and industry readiness gates](/Users/huangjiahao/Desktop/YNX/docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md)
- [Production hardening roadmap](/Users/huangjiahao/Desktop/YNX/docs/en/PRODUCTION_HARDENING_ROADMAP.md)
- [Audit submission packet](/Users/huangjiahao/Desktop/YNX/docs/en/V2_AUDIT_SUBMISSION_PACKET.md)
- [Security response policy](/Users/huangjiahao/Desktop/YNX/docs/en/SECURITY_RESPONSE_POLICY_2026_06_13.md)

## 8. Recommended next actions

Immediate:

1. fix Sepolia release-signer configuration
2. deploy/configure BSC source lockbox and signer path
3. keep public-versus-protected trace boundary intact
4. keep current-status docs refreshed from the snapshot script

After that:

1. package grant / sponsor outreach around the truthful public-testnet story
2. do not let BSC incompleteness dominate broader infrastructure outreach
3. pursue legal / security / persistence hardening in parallel

## 9. Canonical commands

Docs readiness:

```bash
./scripts/verify_docs_readiness.sh
```

Current full-stack live snapshot:

```bash
./scripts/current_full_stack_status_snapshot.sh
```

Live runtime alignment audit:

```bash
./scripts/verify_live_runtime_alignment.sh
```

Full-stack evidence pack:

```bash
./scripts/prepare_full_stack_evidence_pack.sh
```

Grant / visibility pack:

```bash
./scripts/prepare_grant_visibility_pack.sh
```

Executive closeout pack:

```bash
./scripts/prepare_executive_closeout_pack.sh
```

Verify latest closeout packs:

```bash
./scripts/verify_latest_closeout_packs.sh
```

Submission readiness:

```bash
./scripts/verify_submission_readiness.sh
```

Public testnet strict/extreme readiness:

```bash
./scripts/public_testnet_extreme_readiness.sh
```
