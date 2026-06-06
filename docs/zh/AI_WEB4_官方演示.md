# YNX AI/Web4 官方演示

状态：active  
最后更新：2026-06-06

## 1. 这个演示说明什么

这个 demo 说明 YNX 的 AI/Web4 不是娱乐聊天机器人，也不只是
“AI agent 权限与结算层”。YNX AI 在公开测试网上有两层能力：

- YNX Intelligence Layer：读取链、桥、route、资产、Web4、AI settlement 的实时状态，回答“现在能做什么、哪里卡住、下一步怎么接”；
- AI agent 执行与结算流：在 owner/policy/session 限制内执行任务，并通过 vault / job / payment / settlement 结算。

结算流证明：

- Web4 policy 管住 AI Agent 的权限和预算；
- session key 让 Agent 可以在限制范围内自动执行；
- AI Gateway 负责 AI 任务、结果提交、挑战期和结算；
- vault 负责机器支付和奖励支出；
- 公开测试网已经部署链上 AI settlement 合约；
- audit / stats / overview 让执行过程可查。

一句话：

**YNX AI 可以观察网络、解释当前交易/跨链/AI 状态，也可以让授权 AI Agent 完成任务并留下可审计的付款结算。**

## 2. 本地一键运行

从仓库根目录执行：

```bash
./scripts/ai_web4_settlement_demo.sh
```

脚本默认会启动本地临时 Web4 Hub 和 AI Gateway，数据写到：

```text
output/ai_web4_demo/<run-id>/
```

它不会污染公开测试网。

## 3. 公开测试网 AI Intelligence API

公开 AI 入口已经上线：

```bash
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  -d '{"message":"总结一下现在 YNX 的交易主线和 AI 状态。"}' | jq
```

默认是 live deterministic intelligence mode：它会读实时 YNX bridge、
route、asset、Web4、AI settlement 状态，再给出确定性回答。服务器配置
本地 Ollama 模型或外部 LLM provider 后，同一个接口会切换到 LLM 模式，
但仍然保留实时 YNX 上下文。为了避免模型把 route / 资产 / settlement
状态说错，官方 `answer` 由实时确定性上下文生成；如需查看模型原始补充，
请求里可以传 `include_model_answer: true`。

## 4. 公开测试网链上结算

公开测试网已经部署 `YNXAISettlement`：

```text
0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf
```

它支持：

- 绑定 policy hash 的 AI vault；
- AI job 创建，包含 reward 和 input hash；
- worker 提交 result hash 和 attestation URI；
- owner 进行 challenge / slash / cancel；
- finalize 后从 vault 向 worker 支付奖励。

AI Gateway 仍然是面向用户/API 的入口；链上合约负责让高价值 AI 任务的结算可验证。

## 5. 演示流程

1. 创建 Web4 policy。
2. owner 签发带上限的 session key。
3. AI Gateway 创建 payment vault。
4. 用户发布 AI job。
5. AI worker 提交 result hash。
6. job finalize 后，从 vault 自动结算 reward。
7. 输出每一步 JSON 证据文件。

## 6. 用线上服务跑

如果要指向已部署的服务，可以显式传入 URL：

```bash
YNX_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
AI_URL=https://ai.ynxweb4.com \
./scripts/ai_web4_settlement_demo.sh
```

注意：线上执行会写入线上 Web4/AI Gateway 的测试数据，只应在测试网环境使用。

## 7. 公开测试网实测证据

最新一次线上服务 demo：

```text
Run id: public_20260601T092925Z
Policy: policy_public_20260601T092925Z
Session: session_public_20260601T092925Z
Vault: vault_public_20260601T092925Z
Job: job_public_20260601T092925Z
Reward payment: pay_b4944350c053cb11
Result hash: 58a24ec7ed9d9f7b3d67dde6d711d408f88c30cbe8e8c8a9a2a4602e59fdfa47
```

线上 AI Gateway 当前统计：

```text
total_jobs: 6
total_vaults: 5
total_payments: 6
finalized_jobs: 4
```

最新一次线上链上结算 demo：

```text
Run id: public_onchain_20260606T053758Z
Policy: policy_public_onchain_20260606T053758Z
Session: session_public_onchain_20260606T053758Z
Vault: vault_public_onchain_20260606T053758Z
Job: job_public_onchain_20260606T053758Z
Reward payment: pay_4c49fd5155e98b0a
Result hash: b4ce44dfea5c975259fc59842ef41bfd003363eea870be6f96ebdcc580871a91
```

链上结算交易：

```text
Vault create tx: 0xd163ecab53a39d7a3f81631f1fce6d63dc5e9546056efe9c912dadcbd4611dd4
Job create tx:   0x5399e55a19c6732bcc0627abdf14293a9a8c86edc960e2b494187f972154b26a
Commit tx:       0x9626e37e4fd51fd611aae120b07f4e9f2f4ee336716431837a9b3f6f968cb401
Finalize tx:     0xc9380f194927e15d0b7543a6ee8d7e5834e992a630501f4779aaca293f140ef2
Contract:        0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf
```

链上 demo 后的 AI Gateway 统计：

```text
total_jobs: 7
total_vaults: 6
total_payments: 7
finalized_jobs: 5
```

## 8. 对外解释口径

这个 demo 展示的是 YNX 的核心差异：

- YNX AI 可以直接读公开测试网的 bridge、route、asset、Web4、AI gateway 状态；
- 传统链主要结算人手动发起的交易；
- YNX 让 AI Agent 在 owner/policy/session 限制内自动执行；
- AI 任务有结果承诺、挑战窗口、最终结算和审计记录；
- 机器支付不是应用私有逻辑，而是 YNX Web4/AI 协议面的一部分。

最准确的产品定位是：

```text
实时链上智能分析 + 跨链/交易引导 + AI 的有限授权 + 机器支付预算 + 可审计任务结算
```

它现在不是去中心化模型托管网络，也不是只做娱乐口号的 AI。公开测试网
已经有实时 AI Intelligence API、Web4 授权、AI vault/job/payment 和链上
settlement 证据。

## 9. 跑链上 demo

```bash
YNX_DEMO_USE_EXISTING=1 \
YNX_DEMO_ONCHAIN=1 \
WEB4_URL=https://web4.ynxweb4.com \
AI_URL=https://ai.ynxweb4.com \
./scripts/ai_web4_settlement_demo.sh
```

这会写入测试网数据，并通过配置好的 AI settlement signer 发送 YNX 公开测试网 EVM 交易。
