# YNX v2 Platform Submission Playbook

Status: Active  
Track: `v2-web4`  
Last updated: 2026-03-21

## 1. Goal

Provide a direct copy-paste path so the founder can submit YNX to audit/compliance platforms with minimum custom writing.

## 2. One-command preparation

Run from repository root:

```bash
./scripts/prepare_audit_compliance_pack.sh
```

This command prepares:

- docs readiness proof report
- public runtime evidence report
- audit/compliance packet docs
- tar archive under `output/`

## 3. Canonical files to upload/reference

- `docs/en/V2_AUDIT_SUBMISSION_PACKET.md`
- `docs/zh/V2_审计与合规提交包.md`
- `docs/en/V2_SECURITY_MODEL.md`
- `docs/en/RELEASE_YNXWEB4.md`
- `docs/en/YNX_v2_WEB4_SPEC.md`
- `docs/en/YNX_v2_WEB4_API.md`
- `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
- `infra/openapi/ynx-v2-ai.yaml`
- `infra/openapi/ynx-v2-web4.yaml`

## 4. Standard answers bank (copy/paste)

Project name:

`YNX`

Project category:

`L1 public execution network (AI-native Web4 track)`

Positioning:

`Sovereign Execution Layer`

Repository:

`https://github.com/JiahaoAlbus/YNX`

Live track:

`v2-web4`

Chain profile:

- Cosmos Chain ID: `ynx_9102-1`
- EVM Chain ID: `0x238e` (`9102`)
- Denom: `anyxt`

Public endpoints:

- `https://rpc.ynxweb4.com`
- `https://evm.ynxweb4.com`
- `https://faucet.ynxweb4.com`
- `https://indexer.ynxweb4.com`
- `https://explorer.ynxweb4.com`
- `https://ai.ynxweb4.com`
- `https://web4.ynxweb4.com`

Security model sentence:

`YNX enforces sovereignty order owner > policy > session key > agent action, with policy-bounded delegation and auditable machine-execution flows.`

Audit scope sentence:

`Scope includes chain runtime (chain/), public service stack (infra/faucet, infra/indexer, infra/explorer), AI/Web4 gateways (infra/ai-gateway, infra/web4-hub), and OpenAPI surfaces (infra/openapi/ynx-v2-ai.yaml, infra/openapi/ynx-v2-web4.yaml).`

## 5. Platform-specific submission checklist

## Security auditors (OpenZeppelin / Trail of Bits / Halborn)

- [ ] Attach repository URL
- [ ] Attach scope text from packet section C
- [ ] Attach threat priorities from packet section D
- [ ] Attach docs readiness + runtime evidence report
- [ ] Provide preferred audit window and budget model

## Security competitions (Cantina / Code4rena)

- [ ] Provide immutable submission tag and commit hash
- [ ] Provide in-scope/out-of-scope paths
- [ ] Provide payout policy and severity model
- [ ] Attach quickstart and test commands for wardens

## Bug bounty (Immunefi)

- [ ] Publish in-scope components and exclusions
- [ ] Publish severity and reward table
- [ ] Publish disclosure and response SLA
- [ ] Link `SECURITY.md` and incident contact

## Compliance automation (Drata / Vanta / Secureframe)

- [ ] Map control owners
- [ ] Upload change-management evidence (tagged releases)
- [ ] Upload logging and access-control evidence
- [ ] Upload incident response and backup process artifacts

## Compliance auditor (Schellman / A-LIGN)

- [ ] Share architecture, scope, and readiness packet
- [ ] Confirm initial target (SOC 2 Type I / ISO 27001 readiness)
- [ ] Confirm evidence period and sampling expectations

## 6. Final pre-submit gate

Submit only when all are true:

- docs readiness report is PASS
- runtime evidence report is PASS
- scope tag is pushed to remote
- packet contact/commercial fields are filled
