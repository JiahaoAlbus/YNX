# YNXWEB4 版本说明

发布名：`ynxweb4`  
赛道：`v2-web4`  
状态：公开测试网 active  
发布日期：2026-03-21

## 1）这个版本是什么

`ynxweb4` 是 YNX Web4 公开测试网的整合发布版本。

该版本把以下内容整理为同一条可运行基线：

- EVM 优先链运行时（`ynxd`，链 ID `ynx_9102-1`）
- AI 结算面（`/ai/*`）
- Web4 主权控制面（`/web4/*`）
- 对外服务栈（`faucet`、`indexer`、`explorer`）
- 验证人加入与入共识脚本
- 中英文对外加入文档

## 2）网络参数（本版本）

- Cosmos Chain ID：`ynx_9102-1`
- EVM Chain ID：`0x238e`（`9102`）
- Denom：`anyxt`
- Track：`v2-web4`
- 主权顺序：`owner > policy > session key > agent action`

## 3）公开端点（HTTPS）

- RPC：`https://rpc.ynxweb4.com`
- EVM RPC：`https://evm.ynxweb4.com`
- EVM WS：`https://evm-ws.ynxweb4.com`
- REST：`https://rest.ynxweb4.com`
- Faucet：`https://faucet.ynxweb4.com`
- Indexer：`https://indexer.ynxweb4.com`
- Explorer：`https://explorer.ynxweb4.com`
- AI Gateway：`https://ai.ynxweb4.com`
- Web4 Hub：`https://web4.ynxweb4.com`

## 4）本版本核心能力

### A. 链与执行基线

- 公测链运行时 + EVM JSON-RPC
- 稳定运行的最小 gas price 配置
- 开放验证人与链上质押/治理能力

### B. Web4 主权原语

- Owner / Policy / Session 分层授权模型
- 策略边界内委托与会话时效控制
- `/web4/*` 面向 Agent 的控制能力

### C. AI 结算原语

- Intent 生命周期（创建/提交/挑战/终局）
- 面向机器支付的 Vault 流程
- x402 风格机器支付能力

### D. 对外服务栈

- Faucet（测试币分发）
- Indexer（机器可读链概览/状态）
- Explorer（区块/交易/验证人可视化）
- AI / Web4 网关服务

### E. 运维可靠性

- 一键部署与一键验收脚本
- 写路径与 API 路径烟测脚本
- systemd 栈服务生命周期联动
- 验证人 watchdog 支持

## 5）仓库结构（Web4 相关）

- `chain/`
  - `cmd/ynxd`：链二进制入口
  - `scripts/v2_public_testnet_deploy.sh`：远端部署
  - `scripts/v2_public_testnet_verify.sh`：运维验收
  - `scripts/v2_public_testnet_smoke.sh`：写路径烟测
  - `scripts/v2_validator_bootstrap.sh`：验证人接入
  - `scripts/install_v2_stack_systemd.sh`：systemd 栈安装
- `infra/`
  - `faucet/`、`indexer/`、`explorer/`、`ai-gateway/`、`web4-hub/`
  - `openapi/ynx-v2-ai.yaml`、`openapi/ynx-v2-web4.yaml`
- `docs/en/`、`docs/zh/`
  - 对外加入文档、Web4 规范/API 文档

## 6）对外加入文档入口

- 英文：`docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md`
- 英文（验证节点，不进共识）：`docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`
- 英文（共识验证人，BONDED）：`docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`
- 中文：`docs/zh/V2_公开测试网加入手册.md`
- 中文（验证节点，不进共识）：`docs/zh/V2_验证节点加入手册.md`
- 中文（共识验证人，BONDED）：`docs/zh/V2_共识验证人加入手册.md`
- 英文索引：`docs/en/INDEX.md`
- 中文索引：`docs/zh/INDEX.md`

## 7）兼容与迁移说明

- 本版本以 `v2-web4` 为对外默认赛道。
- `v0` 文档仍保留在仓库，作为历史资料，不建议在网站默认导航展示。
- HTTPS 网站不要直接调用 `http://IP:PORT`。

## 8）发布前核查清单

1. `v2_public_testnet_verify.sh` 通过
2. `v2_public_testnet_smoke.sh` 通过
3. `indexer /ynx/overview` 返回 `track=v2-web4`
4. Explorer 持续更新区块高度
5. Faucet `/health` 绿色，发币接口可用
6. 至少 2 个验证人状态为 `BOND_STATUS_BONDED`

## 9）当前约束（公测网）

- 当前仍是公开测试网，存在参数调整或重置可能。
- 主网经济模型与风险控制不在本版本内最终锁定。
- 测试币仅用于测试。

## 10）总结

`ynxweb4` 是 YNX 首个“链运行时 + AI/Web4 原语 + 对外服务栈 + 验证人接入 + 中英文文档”完整整合的公开测试网发布线。
