# YNX 定位与卖点（中文）

状态：active  
最后更新：2026-05-01

## 一句话定位

YNX 是一条 **AI-native Web4 公共执行网络**，提供 **EVM 兼容开发入口**、机器支付流程，以及 human / agent 执行所需的 owner-policy-session 控制模型。

当前公开测试网准确表述：

`YNX public testnet is live for developers and operators. Core RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub services are online. The network is still completing public P2P and validator redundancy before mainnet-candidate status.`

## 用户为什么选择 YNX

- EVM 工具链友好：钱包、合约、RPC 路线延续主流开发习惯。
- AI 任务结算导向：面向 AI/Agent 应用的任务、结果、挑战、结算流程。
- 治理透明：治理与费率参数可机器读取，不是黑箱运营。
- 运维复制快：脚本化部署与参数档位切换，便于扩容验证人。

## 与大链的差异

YNX 不以“当前最大流动性”作为卖点，核心差异在：

- 面向 AI/Web4 的链上结算能力，
- 保持 EVM 开发效率的同时追求更低延迟，
- 治理与经济参数可观测可验证，
- 验证人与开发者可持续开放接入。

在 `docs/zh/主网与行业级上线门禁.md` strict gate 通过前，不应宣称 mainnet-candidate 或 decentralized-validator readiness。

## 机器可读入口

- `GET /ynx/overview`

可返回：

- 治理地址与费率参数，
- 链定位与价值主张字段，
- 当前链运行概览。
