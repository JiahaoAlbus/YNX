# YNX 项目非技术上线手续包

状态：active
最后更新：2026-05-01
规范语言：中文

## 1. 对外介绍

YNX 是一条 AI-native Web4 公共执行网络，提供 EVM 兼容开发入口、机器支付流程，以及 human / agent 执行所需的 owner-policy-session 控制模型。

当前准确对外表述：

`YNX public testnet is live for developers and operators. Core RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub services are online. The network is still completing public P2P and validator redundancy before mainnet-candidate status.`

## 2. YNX 不是什么

YNX 不应被描述为：

- 用户资产托管方；
- 中心化交易所；
- broker / dealer；
- 稳定币发行方；
- 消费者 KYC 服务商；
- 投资产品；
- 代币升值承诺。

## 3. 对外宣传规则

可以说：

- 公开测试网已上线；
- 公共服务可访问；
- Web4 和 AI settlement 流程可测试；
- EVM JSON-RPC 兼容可用；
- ARES SDK observe-mode 已有实现；
- 主网就绪受 P2P、验证人、审计、法律、治理门禁约束。

不能说：

- “永远无法破解”；
- “绝对抗量子”；
- “政府黑客不能破解”；
- “保证收益”；
- readiness gate 通过前不能说 “mainnet-ready”；
- 只有 1 个验证人时不能说 “decentralized validator network”。

## 4. 官网必须具备的页面

主网候选宣传前，官网应具备：

- 项目概览；
- 公开测试网状态；
- 开发者 quickstart；
- endpoint 列表；
- validator onboarding；
- security model；
- ARES crypto model summary；
- 非托管商业边界；
- 风险披露；
- terms of use；
- privacy policy；
- security contact / vulnerability disclosure。

## 5. 公司和运营手续

商业化前：

- 确定公司主体和司法辖区；
- 明确 security、ops、legal、finance、developer relations 负责人；
- 创建 security contact email；
- 创建 abuse/contact email；
- 创建事故响应升级渠道；
- 定义公共服务数据留存策略；
- 定义 API/SLA/private deployment 合同模板；
- 定义法币收入的税务和会计流程；
- 未经律师确认，不上线任何可能受监管的产品。

## 6. 部署手续摘要

当前基础设施基线：

- 腾讯云新加坡 canonical public stack；
- `ynxweb4.com` 下公网 HTTPS endpoints；
- P2P TCP `36656` 为节点连接端口；
- GCP 是历史归档，不应在当前对外表述中使用。

运维流程：

1. 从打 tag 的仓库状态部署或更新服务器。
2. 跑本地服务健康检查。
3. 采集公网 runtime evidence。
4. 跑 HTTPS 写路径烟测。
5. 跑 extreme readiness check。
6. 如果 P2P / validator gate 未通过，只能定位为 public testnet，不能定位为 mainnet-candidate。

## 7. 当前就绪文档

- `docs/zh/公开测试网完整验收报告_2026_05_01.md`
- `docs/zh/主网与行业级上线门禁.md`
- `docs/zh/YNX_非托管商业与合规边界.md`
- `docs/zh/V2_高保证加密与抗量子安全模型.md`
- `docs/zh/YNX_ARES_混合抗量子加密协议.md`

## 8. 创始人标准答案

YNX 是否碰用户资产？

- 不碰。用户自己保管私钥和资产。

YNX 是否做托管？

- 不做。基础项目保持非托管。

YNX 是否做交易所？

- 不做。YNX 不运营撮合引擎或交易所业务。

YNX 是否做稳定币？

- 不做。YNX 不发行或管理稳定币储备。

YNX 是否做 KYC？

- 基础协议公司不做消费者 KYC 主营业务。受监管合作方如有需要，由合作方在自己的合规体系下完成。

怎么赚钱？

- 托管 API、企业 Web4/AI 基建、私有部署、SLA 支持、验证人工具、监控、SDK/API access、审计/集成支持、治理批准的协议费。

NYXT 不值钱怎么办？

- 公司必须靠法币定价的 SaaS/API/support/private deployment 收入活下去。NYXT 是 utility alignment，不是唯一商业模式。

公司开在哪里？

- 当前务实默认：新加坡运营公司；如需要再加 foundation/governance entity；只有美国融资或美国企业销售成为核心时再考虑 Delaware C-Corp。
