# YNX Web4 (v2)

YNX is a public execution network for **humans + AI agents**.

- Positioning: **Sovereign Execution Layer**
- Active track: `v2-web4`
- Sovereignty order: `owner > policy > session key > agent action`
- Native asset: `NYXT` (gas / staking / governance)

---

## Network (Public Testnet)

- Cosmos Chain ID: `ynx_9102-1`
- EVM Chain ID: `0x238e`
- Denom: `anyxt`

Public HTTPS endpoints:

- RPC: `https://rpc.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- EVM WS: `https://evm-ws.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`

---

## Start Here

### 1) End users (no install)

```bash
curl -s https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s https://indexer.ynxweb4.com/ynx/overview | jq
curl -s https://faucet.ynxweb4.com/health | jq
```

### 2) Builders (local full stack)

```bash
git clone https://github.com/JiahaoAlbus/YNX.git
cd YNX/chain
./scripts/v2_local_complete.sh all
```

### 3) AI/Web4 settlement demo

Run the official local demo for the core AI-agent flow: bounded Web4 policy, session key, AI job, result commit, finalize, and vault reward settlement.

```bash
./scripts/ai_web4_settlement_demo.sh
```

Docs:

- EN: [`docs/en/AI_WEB4_OFFICIAL_DEMO.md`](docs/en/AI_WEB4_OFFICIAL_DEMO.md)
- ZH: [`docs/zh/AI_WEB4_官方演示.md`](docs/zh/AI_WEB4_官方演示.md)

### 4) Builders

Use the builder quickstart for EVM RPC, Web4 Hub, AI Gateway, and local demo entry points:

- EN: [`docs/en/BUILDER_QUICKSTART.md`](docs/en/BUILDER_QUICKSTART.md)

### 5) Node Operators / Validators

Install the YNX CLI and join from a clean Linux machine:

```bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="$HOME/.local/bin:$PATH"
ynx join --role full-node
```

For consensus-validator candidates, use `ynx join --role validator` after operator review and funding. The CLI defaults to state sync for the public testnet so new machines do not replay incompatible historical genesis state.

Use the **zero-start** join manuals below (EN/ZH).  
These guides start from a clean machine and include complete bootstrap paths.

---

## Public Join Manuals (Canonical)

### English

- Public testnet join: [`docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md`](docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md)
- Validator node (non-consensus): [`docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`](docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md)
- Consensus validator (BONDED): [`docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`](docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md)

### Chinese

- 公开测试网加入手册: [`docs/zh/V2_公开测试网加入手册.md`](docs/zh/V2_公开测试网加入手册.md)
- 验证节点加入手册（不进共识）: [`docs/zh/V2_验证节点加入手册.md`](docs/zh/V2_验证节点加入手册.md)
- 共识验证人加入手册（BONDED）: [`docs/zh/V2_共识验证人加入手册.md`](docs/zh/V2_共识验证人加入手册.md)

Index:

- English index: [`docs/en/INDEX.md`](docs/en/INDEX.md)
- Chinese index: [`docs/zh/INDEX.md`](docs/zh/INDEX.md)

---

## Release Notes

- Current release: `ynxweb4`
- EN: [`docs/en/RELEASE_YNXWEB4.md`](docs/en/RELEASE_YNXWEB4.md)
- ZH: [`docs/zh/YNXWEB4_版本说明.md`](docs/zh/YNXWEB4_版本说明.md)
- Platform submit playbook (EN): [`docs/en/V2_PLATFORM_SUBMISSION_PLAYBOOK.md`](docs/en/V2_PLATFORM_SUBMISSION_PLAYBOOK.md)
- 平台提交流程手册（ZH）: [`docs/zh/V2_平台提交流程手册.md`](docs/zh/V2_平台提交流程手册.md)

---

## Operator Quick Commands

Current ops baseline:

- EN: `docs/en/V2_TENCENT_CURRENT_DEPLOYMENT_PROFILE.md`
- ZH: `docs/zh/V2_腾讯云_当前部署配置清单.md`

### Deploy public testnet to a server

```bash
cd chain
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset --smoke-write
```

### Verify deployed stack

```bash
cd chain
YNX_PUBLIC_HOST=127.0.0.1 ./scripts/v2_public_testnet_verify.sh
```

### Generate validator bootstrap bundle

```bash
cd chain
./scripts/v2_testnet_release.sh
```

---

## Docs Readiness Check (13 checks)

```bash
./scripts/verify_docs_readiness.sh
```

This script validates:

- existence/readability of 6 public join manuals
- zero-start semantics in EN/ZH manuals
- README / docs indexes / release notes reference coverage, including security and non-custodial boundary docs

Report output:

- `output/docs_verification_report_<timestamp>.md`

## Submission Readiness Check

```bash
./scripts/verify_submission_readiness.sh
```

This script validates:

- docs readiness (`13 checks`)
- public runtime evidence across RPC/EVM/Faucet/Indexer/Explorer/AI/Web4

## Public Uptime / SLO Probe

```bash
scripts/public_uptime_slo_probe.sh --once
```

Continuous alerting:

```bash
CHECK_INTERVAL_SEC=60 \
ALERT_WEBHOOK_URL="https://your-alert-webhook" \
scripts/public_uptime_slo_probe.sh
```

Install as a systemd service on an operator host:

```bash
scripts/install_public_uptime_slo_systemd.sh
```

Hardening roadmap:

- [`docs/en/PRODUCTION_HARDENING_ROADMAP.md`](docs/en/PRODUCTION_HARDENING_ROADMAP.md)

## Terminal-only submission flow

```bash
./scripts/terminal_submission_ready.sh
```

This flow runs verify + pack, asks required form fields in terminal, and writes filled submission files under:

- `output/audit_compliance_pack_<timestamp>/submission_profile/`

## Audit + Compliance Pack (submission-ready)

```bash
./scripts/prepare_audit_compliance_pack.sh
```

Generated artifacts:

- `output/audit_compliance_pack_<timestamp>/`
- `output/audit_compliance_pack_<timestamp>.tar.gz`

---

## Repository Layout

- `chain/` — chain node, scripts, validator tooling
- `infra/` — faucet, indexer, explorer, AI gateway, Web4 hub, OpenAPI
- `docs/en/` — canonical English docs
- `docs/zh/` — Chinese docs
- `packages/` — SDK and contracts packages
- `ops/` — ops assets

---

## Security Notes

- Public websites should call HTTPS endpoints only.
- Testnet is for testing only; do not use real production funds.
- Never commit private keys, mnemonics, or `.env` secrets.
- High-assurance crypto baseline: [`docs/en/V2_HIGH_ASSURANCE_CRYPTO_MODEL.md`](docs/en/V2_HIGH_ASSURANCE_CRYPTO_MODEL.md)
- YNX ARES hybrid crypto protocol: [`docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md`](docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md)
- Non-custodial business boundary: [`docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`](docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md)
- ARES SDK utility: `packages/sdk/src/ares.ts`
- Current readiness report: [`docs/en/PUBLIC_TESTNET_READINESS_REPORT_2026_05_01.md`](docs/en/PUBLIC_TESTNET_READINESS_REPORT_2026_05_01.md)
- Mainnet / industry gates: [`docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md`](docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md)
- Non-technical launch packet: [`docs/en/PROJECT_NON_TECHNICAL_LAUNCH_PACKET.md`](docs/en/PROJECT_NON_TECHNICAL_LAUNCH_PACKET.md)
