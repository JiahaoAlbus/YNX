# YNX v2 Audit + Compliance Submission Packet

Status: Template (fill before submission)  
Track: `v2-web4`  
Last updated: 2026-03-21

---

## A. Project identity

- Project name: `YNX`
- Positioning: `Sovereign Execution Layer`
- Current release line: `ynxweb4-v2`
- Repository: `https://github.com/JiahaoAlbus/YNX`
- Primary docs index: `docs/en/INDEX.md`

## B. Network profile

- Cosmos Chain ID: `ynx_9102-1`
- EVM Chain ID: `0x238e` (`9102`)
- Native denom: `anyxt`
- Public endpoints:
  - `https://rpc.ynxweb4.com`
  - `https://evm.ynxweb4.com`
  - `https://faucet.ynxweb4.com`
  - `https://indexer.ynxweb4.com`
  - `https://explorer.ynxweb4.com`
  - `https://ai.ynxweb4.com`
  - `https://web4.ynxweb4.com`

## C. Scope to audit

Code surfaces:

- Chain runtime: `chain/`
- Service stack: `infra/faucet`, `infra/indexer`, `infra/explorer`
- AI and Web4 control surfaces: `infra/ai-gateway`, `infra/web4-hub`
- API specs: `infra/openapi/ynx-v2-ai.yaml`, `infra/openapi/ynx-v2-web4.yaml`

Protocol and behavior references:

- `docs/en/YNX_v2_WEB4_SPEC.md`
- `docs/en/YNX_v2_WEB4_API.md`
- `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
- `docs/en/V2_SECURITY_MODEL.md`

Out-of-scope (customize if needed):

- historical `v0` docs not used by active `v2-web4` runtime
- social/media materials

## D. Threat priorities

1. key management and privileged operation paths
2. validator liveness/double-sign handling
3. policy/session privilege escalation (`/web4/*`)
4. settlement and challenge integrity (`/ai/*`)
5. faucet abuse / anti-drain controls
6. replay, auth bypass, and request-signature misuse

## E. Security evidence (attach latest outputs)

- docs readiness report: `output/docs_verification_report_<timestamp>.md`
- testnet verify output: `output/v2_public_testnet_verify_<timestamp>.log` (or equivalent)
- smoke output: `output/v2_public_testnet_smoke_<timestamp>.log` (or equivalent)
- system service status snapshots:
  - node
  - faucet
  - indexer
  - explorer
  - ai-gateway
  - web4-hub

## F. Compliance readiness snapshot

Control areas currently prepared:

- access control and least privilege
- change management and tagged release baselines
- logging and operational evidence capture
- security incident handling runbook ownership
- secrets/key backup and rotation process

Planned certification sequence:

1. SOC 2 Type I readiness + audit planning
2. ISO 27001 readiness + stage audit planning
3. SOC 2 Type II after observation period

## G. Contacts (fill before sending)

- Founder / project owner: `<fill>`
- Security contact email: `<fill>`
- Ops contact email: `<fill>`
- Timezone for live sync: `<fill>`

## H. Commercial request profile (fill before sending)

- Preferred audit window: `<fill>`
- Preferred delivery mode (fixed bid / T&M / contest): `<fill>`
- Expected report disclosure model (public/private): `<fill>`
- Need retest included: `yes/no`

## I. Submission checklist (must be complete)

- [ ] Scope paths are final and exact
- [ ] Submission git tag is created and pushed
- [ ] Latest release notes are up to date
- [ ] Docs readiness report attached
- [ ] Verify + smoke evidence attached
- [ ] Contact block filled
- [ ] Commercial request profile filled
