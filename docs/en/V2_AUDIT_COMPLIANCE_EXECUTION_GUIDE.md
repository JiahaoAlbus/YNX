# YNX v2 Audit + Compliance Execution Guide

Status: Active  
Track: `v2-web4`  
Last updated: 2026-03-21

## 1. Goal

Prepare YNX so the founder can submit directly to audit/compliance platforms with minimal additional writing.

Target output of this prep phase:

- complete audit scope + architecture package
- complete compliance readiness package (SOC 2 / ISO 27001 pre-stage)
- reproducible evidence bundle with fixed file paths
- one command to rebuild submission pack

## 2. Execution model

Run two tracks in parallel:

- **Security audit track (primary):** external code/security review readiness
- **Compliance readiness track (secondary):** controls/evidence readiness for formal certification

Do not wait for one track to finish before starting the other; synchronize at weekly checkpoints.

## 3. Week-by-week plan (first 4 weeks)

## Week 1 — Scope freeze + architecture evidence

Required deliverables:

1. Freeze target scope by tag (`git tag`) for review baseline.
2. Lock architecture references:
   - `docs/en/YNX_v2_WEB4_SPEC.md`
   - `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
   - `docs/en/YNX_v2_WEB4_API.md`
   - `infra/openapi/ynx-v2-ai.yaml`
   - `infra/openapi/ynx-v2-web4.yaml`
3. Lock public join and validator paths:
   - `docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md`
   - `docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`
   - `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`
4. Build docs readiness proof:
   - `scripts/verify_docs_readiness.sh`

Exit criteria:

- scope tag created
- docs readiness report is PASS

## Week 2 — Threat model + risk register + control mapping

Required deliverables:

1. Threat model focusing on:
   - key compromise
   - validator double-sign / liveness
   - faucet abuse and rate-limit bypass
   - API auth/session misuse (`/web4/*`)
   - settlement dispute abuse (`/ai/*`)
2. Risk register with severity, owner, remediation ETA.
3. Compliance control mapping draft:
   - access control
   - change management
   - logging and retention
   - incident response
   - key/secret handling
4. Confirm evidence paths and naming conventions.

Exit criteria:

- threat scenarios documented and assigned
- top risks have mitigation owner + due date

## Week 3 — Pre-audit hardening + evidence capture

Required deliverables:

1. Reproduce deploy and verify flow:
   - `chain/scripts/v2_public_testnet_deploy.sh`
   - `chain/scripts/v2_public_testnet_verify.sh`
   - `chain/scripts/v2_public_testnet_smoke.sh`
2. Capture service-level proof:
   - RPC / EVM / faucet / indexer / explorer / AI / Web4 health outputs
3. Capture node/validator operational proof:
   - validator status (`BONDED` target for consensus nodes)
   - watchdog service status/log excerpts
4. Generate pack artifact via script:
   - `scripts/prepare_audit_compliance_pack.sh`

Exit criteria:

- evidence bundle can be rebuilt by command
- smoke and verification outputs included in bundle

## Week 4 — Submission readiness gate

Required deliverables:

1. Audit submission packet complete and reviewed.
2. Compliance readiness packet complete and reviewed.
3. Final scope tag for external submission created and pushed.

Exit criteria:

- all required fields for external platform forms can be copy-pasted from packet docs
- tagged baseline exists in remote

## 4. Platform shortlist and submission strategy

## Security audit platforms

Primary outreach batch:

- OpenZeppelin
- Trail of Bits
- Halborn

Secondary parallel market:

- Cantina (competition format)
- Code4rena (contest format)
- Immunefi (bug bounty, post-audit continuous security)

Submission rule:

- send one canonical packet to all primary auditors
- keep scope/hash/tag identical across all submissions
- do not submit shifting scope variants

## Compliance platforms

Automation layer (choose one):

- Drata / Vanta / Secureframe

Auditor layer (choose one):

- Schellman / A-LIGN

Certification strategy:

- first milestone: SOC 2 Type I readiness + ISO 27001 readiness
- second milestone (later): SOC 2 Type II observation period

## 5. Required packet files (must exist)

- `docs/en/V2_AUDIT_SUBMISSION_PACKET.md`
- `docs/zh/V2_审计与合规提交包.md`
- `docs/en/RELEASE_YNXWEB4.md`
- `docs/zh/YNXWEB4_版本说明.md`
- `docs/en/V2_SECURITY_MODEL.md`
- `docs/en/V2_SMOKE_AND_VERIFY.md`
- `scripts/verify_docs_readiness.sh`
- `scripts/prepare_audit_compliance_pack.sh`

## 6. Final gate checklist (Go / No-Go)

Go only when all are true:

- docs readiness check is PASS (`13/13`)
- latest public testnet verify output is attached
- latest public smoke output is attached
- release note reflects latest onboarding/security changes
- submission tag exists in remote and is immutable

If any item fails, mark No-Go and fix before contacting platforms.
