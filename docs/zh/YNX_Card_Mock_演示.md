# YNX Card Mock 演示

状态：active  
最后更新：2026-06-27

## 1. 这个 demo 证明什么

这个 demo 证明 YNX Card 已经不只是一个静态概念页。

它跑通的是完整 mock control loop：

- wallet bootstrap
- 钱包签名验证
- bootstrap-backed policy 创建
- session delegation
- bounded agent creation
- YNX Card Mock creation
- 规则内消费通过
- 对已通过授权登记 mock 结算
- 对剩余额度登记 mock 冲正
- 对已结算金额登记 mock 退款
- 规则外消费拒绝
- 授权结果和后续流水结果都有 audit evidence

所以重点不是“卡片 UI”，而是 YNX 已经有了给 Web4 钱包和 AI Agent 用的可编程消费控制面。

## 2. 本地运行

在仓库根目录执行：

```bash
./scripts/ynx_card_mock_demo.sh
```

脚本默认会启动一个临时本地 Web4 Hub，并把 JSON 证据写到：

```text
output/ynx_card_demo/<run-id>/
```

## 3. 脚本实际做了什么

1. 创建 demo 钱包
2. 请求 wallet bootstrap
3. 对 challenge 做签名
4. 完成 wallet bootstrap verify
5. 创建 wallet-backed policy
6. 签发受限 session
7. 创建受限 agent
8. 创建绑定同一 policy 的 YNX Card Mock
9. 跑一笔规则内消费并通过
10. 登记一笔 mock settlement
11. 登记一笔 mock reversal
12. 登记一笔 mock refund
13. 跑一笔规则外消费并拒绝
14. 拉取 card detail 和 audit 记录

## 4. 对已有 Web4 服务运行

```bash
YNX_CARD_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
./scripts/ynx_card_mock_demo.sh
```

只应在允许写入 demo 测试数据的环境里使用。

## 5. 边界

这个 demo 是刻意 mock-only 的：

- 没有真实卡组织通道
- 没有真实发卡服务商
- 没有真实用户资金
- 没有 PCI 敏感卡数据流程

它证明的是 programmable control logic，不是已经完成 live compliant card issuance。
