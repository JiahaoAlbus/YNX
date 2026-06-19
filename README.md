# YNX Web4 (v2)

YNX is a Web4 and AI-execution layer for **humans + AI agents**.

- Positioning: **Web4 And AI-Execution Layer**
- Active track: `v2-web4`
- Sovereignty order: `owner > policy > session key > agent action`
- Native asset: `NYXT` (gas / staking / governance)

Important boundary:

- YNX is strongest today as a policy-bounded execution and settlement stack.
- YNX should not be described as a novel-consensus moat or a mainnet-grade
  production network yet.
- Public bridge routes are testnet architecture evidence, not production
  custody claims.
- No public legal entity has been announced yet, so project disclosures should
  not be read as company-level legal completion.
- Current external support is best framed as grants, sponsorships, or other
  project-stage infrastructure backing until entity formation and legal
  ownership are complete.

---

## Network (Public Testnet)

- Cosmos Chain ID: `ynx_9102-1`
- EVM Chain ID: `0x238e`
- Denom: `anyxt`
- Currently usable public-testnet assets: `NYXT` / `anyxt`, `YUSD.test`
- Public-testnet wrapped representations deployed: `wBTC.y`, `wETH.y`,
  `wBNB.y`, `wUSDT.y`, `wUSDC.y`
- Important scope: these wrapped assets are testnet contracts and route
  evidence, not proof of production custody, redemption, or official
  mainnet-asset liquidity
- AI settlement rail: `0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf`

Public HTTPS endpoints:

- RPC: `https://rpc.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- EVM WS: `https://evm-ws.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- Bridge Service: `https://rpc.ynxweb4.com/bridge/*`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`

---

## Start Here

### 1) End users (no install)

```bash
curl -s https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s https://indexer.ynxweb4.com/ynx/overview | jq
curl -s https://faucet.ynxweb4.com/health | jq
curl -s https://rpc.ynxweb4.com/bridge/route-checks | jq
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

The public testnet also has an on-chain AI settlement contract for vault-funded
AI jobs, result commits, challenge/slash, and reward finalization:

```text
0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf
```

Docs:

- EN: [`docs/en/AI_WEB4_OFFICIAL_DEMO.md`](docs/en/AI_WEB4_OFFICIAL_DEMO.md)
- ZH: [`docs/zh/AI_WEB4_官方演示.md`](docs/zh/AI_WEB4_官方演示.md)

### 4) Asset status and speed-first trading direction

- EN: [`docs/en/PUBLIC_ASSET_STATUS.md`](docs/en/PUBLIC_ASSET_STATUS.md)
- EN: [`docs/en/SPEED_FIRST_MULTI_ASSET_TRADING_PLAN.md`](docs/en/SPEED_FIRST_MULTI_ASSET_TRADING_PLAN.md)
- ZH: [`docs/zh/公开资产状态.md`](docs/zh/公开资产状态.md)
- ZH: [`docs/zh/极速优先多资产交易计划.md`](docs/zh/极速优先多资产交易计划.md)

### 4.5) Funding / grant / compliance packet

Current funding boundary:

- these materials are strongest for grants, sponsorships, strategic technical
  support, and exploratory early-stage diligence;
- they should not be used to imply that YNX already has a formed operating
  entity, completed external audit coverage, or standard institutional equity
  readiness.

- Root start-here page: [`START_HERE_FOR_SUPPORT.md`](START_HERE_FOR_SUPPORT.md)
- EN one-pager: [`docs/en/YNX_OUTLIER_ONE_PAGER_2026_06_18.md`](docs/en/YNX_OUTLIER_ONE_PAGER_2026_06_18.md)
- EN one-pager PDF: [`docs/en/YNX_OUTLIER_ONE_PAGER_2026_06_18.pdf`](docs/en/YNX_OUTLIER_ONE_PAGER_2026_06_18.pdf)
- EN standard answer pack: [`docs/en/EXTERNAL_RESPONSE_PACK_2026_06_19.md`](docs/en/EXTERNAL_RESPONSE_PACK_2026_06_19.md)
- EN follow-up templates: [`docs/en/FOLLOW_UP_TEMPLATES_2026_06_19.md`](docs/en/FOLLOW_UP_TEMPLATES_2026_06_19.md)
- ZH start-here page: [`docs/zh/资助与尽调入口_2026_06_19.md`](docs/zh/资助与尽调入口_2026_06_19.md)
- ZH standard answer pack: [`docs/zh/对外答复标准包_2026_06_19.md`](docs/zh/对外答复标准包_2026_06_19.md)
- ZH follow-up templates: [`docs/zh/跟进模板_2026_06_19.md`](docs/zh/跟进模板_2026_06_19.md)
- EN: [`docs/en/INVESTOR_DATA_ROOM_2026_06_13.md`](docs/en/INVESTOR_DATA_ROOM_2026_06_13.md)
- EN: [`docs/en/FUNDRAISING_MEMO_2026_06_13.md`](docs/en/FUNDRAISING_MEMO_2026_06_13.md)
- EN: [`docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md`](docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
- ZH: [`docs/zh/投资人与尽调资料室_2026_06_13.md`](docs/zh/投资人与尽调资料室_2026_06_13.md)
- ZH: [`docs/zh/融资备忘录_2026_06_13.md`](docs/zh/融资备忘录_2026_06_13.md)
- ZH: [`docs/zh/合规就绪包_2026_06_13.md`](docs/zh/合规就绪包_2026_06_13.md)

### 5) Builders

Use the builder quickstart for EVM RPC, Web4 Hub, AI Gateway, and local demo entry points:

- EN: [`docs/en/BUILDER_QUICKSTART.md`](docs/en/BUILDER_QUICKSTART.md)

### 6) Node Operators / Validators

Install the YNX CLI and join from a clean Linux machine:

```bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="$HOME/.local/bin:$PATH"
ynx join --role full-node
```

Fresh Windows machine:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
irm https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx_windows.ps1 | iex
```

Windows support boundary: the documented path is WSL2 + Ubuntu. Native non-WSL Windows validator support is not claimed here.

For consensus-validator candidates, use `ynx join --role validator` after operator review and funding. The CLI defaults to state sync for the public testnet so new machines do not replay incompatible historical genesis state.

If deployment stalls, use the public AI troubleshooting page at `https://www.ynxweb4.com/ai` and paste the exact command plus exact error output.

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
- `infra/` — faucet, indexer, explorer, bridge service, AI gateway, Web4 hub, OpenAPI
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
