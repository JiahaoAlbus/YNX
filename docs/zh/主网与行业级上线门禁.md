# YNX 主网与行业级上线门禁

状态：active
最后更新：2026-05-01
规范语言：中文

## 目标

本文定义 YNX 在使用“主网候选”“生产级”“机构级”等表述前必须满足的行业级门禁。

## Gate 1：公网服务可用性

必须满足：

- RPC、EVM JSON-RPC、REST、Faucet、Indexer、Explorer、AI Gateway、Web4 Hub 通过 HTTPS 可访问；
- chain ID 和 EVM chain ID 与公开文档一致；
- 验证期间区块高度持续增长；
- AI / Web4 readiness 返回 `ok=true`；
- indexer 高度接近链上最新高度。

验收命令：

```bash
./scripts/verify_submission_readiness.sh
```

## Gate 2：P2P 与验证人冗余

主网候选宣传前必须满足：

- canonical RPC `/net_info` 至少看到 `2` 个公开 peer；
- 至少 `4` 个验证人或验证人候选，跨至少 `2` 个地域；
- 公开 sentry/full node 至少跨 `2` 个故障域；
- 发布的 peer 节点 TCP `36656` 可达；
- 必要时双向配置 persistent peers；
- 验证人加入和应急替换流程有文档。

验收命令：

```bash
./scripts/public_testnet_extreme_readiness.sh
```

2026-05-01 当前状态：此门禁未通过。

## Gate 3：写路径完整度

必须满足：

- Web4 policy/session 生命周期可用；
- policy enforcement 能拒绝未授权写入；
- identity、agent、self-update、replication、intent、claim、challenge、finalize 可用；
- AI vault、job、commit、finalize、payout、x402 payment 可用；
- 高权限动作进入审计日志。

2026-05-01 当前状态：公网 HTTPS 写路径烟测通过。

## Gate 4：安全与密码学

必须满足：

- 仓库没有生产密钥；
- 运维密钥有保护和轮换流程；
- SDK 已具备 ARES observe mode；
- strict ARES 需要接入经过审计的后量子 provider 后才能主网强制启用；
- 治理、金库、升级、桥、root policy 在主网前必须由多签或阈值控制保护；
- 完成外部安全审计。

参考：

- `docs/en/V2_SECURITY_MODEL.md`
- `docs/en/V2_HIGH_ASSURANCE_CRYPTO_MODEL.md`
- `docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md`

## Gate 5：非托管商业与法律边界

必须满足：

- 对外 terms 明确 YNX 不托管用户资产；
- 不做交易所撮合；
- 不发行或管理稳定币储备；
- 基础协议公司不做消费者 KYC 主营业务；
- 受监管服务交给持牌合作方，或等律师确认后再做；
- 公司主体、会计税务、安全联系人、事故响应负责人明确。

参考：

- `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`
- `docs/en/PROJECT_NON_TECHNICAL_LAUNCH_PACKET.md`

## Gate 6：文档与对外表述

必须满足：

- 英文规范文档最新；
- 中文文档与实际运行状态一致；
- 官网不能再出现过期 GCP cluster 表述；
- 部署文档与腾讯云拓扑一致；
- 风险披露不能承诺币价、收益或“永远无法破解”；
- 最新 readiness report 已进入内部运维文档。

## Gate 7：上线决策

只有满足以下条件才能主网上线：

1. Gate 1–6 全部通过；
2. 律师确认运营模型；
3. 外部审计问题已修复或明确风险接受；
4. 验证人集合和 P2P 拓扑 strict readiness 通过；
5. 完成事故响应和回滚演练；
6. 治理批准主网参数。

在此之前，对外准确表述应为：

`YNX public testnet is live and usable, with service and workflow checks passing. Decentralized P2P and validator redundancy are still being completed before mainnet-candidate status.`
