# YNX Card Mock 说明

状态：active mock surface  
最后更新：2026-06-27

## 1. 这是什么

YNX Card Mock 是 YNX 当前的可编程卡控层。

它不是一张真实银行卡，不是已经接入发卡服务商的成品，也不是隐藏托管产品。它的定位是：先把未来合规发卡接入前最关键的控制逻辑跑通：

- 在 owner policy 下创建 mock card
- 给 agent 有限消费权限
- 按 merchant / MCC / country / 单笔 / 日限额 / 总限额做规则判断
- 明确返回通过或拒绝
- 每一次创建、通过、拒绝、冻结、恢复都有审计记录

这意味着 YNX 现在已经能证明最重要的事情：

- 用户或操作员先定义消费规则
- AI Agent 只拿到有限权限
- 一笔消费请求必须同时通过 policy / session / card rule
- 系统会记录为什么通过，或者为什么拒绝

## 2. 当前模型

YNX Card Mock 建立在现有 Web4 control plane 之上：

1. owner
2. policy
3. session
4. card authorization attempt

消费路径是刻意分层的：

- session 必须有 `card.authorize`
- session 和 policy 的 spend ceiling 必须先允许
- 然后 card mock 规则再判断 merchant / MCC / country / amount
- 最后把结论写入 audit 和 authorization history

这样 Card 就不是一个孤立 demo，而是和 YNX 现有 Web4 / AI / audit 架构一致。

## 3. 现在已经能做什么

当前 Web4 Hub 已支持：

- `POST /web4/cards`
- `GET /web4/cards`
- `GET /web4/cards/:card_id`
- `POST /web4/cards/:card_id/authorize`
- `POST /web4/cards/:card_id/freeze`
- `POST /web4/cards/:card_id/resume`

当前规则控制包括：

- `require_agent`
- `allowed_agents`
- `allowed_merchants`
- `blocked_merchants`
- `allowed_mccs`
- `blocked_mccs`
- `allowed_countries`
- `blocked_countries`
- `max_per_txn`
- `max_daily_spend`
- `max_total_spend`

当前审计事件包括：

- `card.created`
- `card.authorized`
- `card.declined`
- `card.frozen`
- `card.resumed`

## 4. 它不是什么

YNX Card Mock 目前**不等于**：

- 真实发出的银行卡
- 已接通真实卡组织网络
- 已完成的 Visa / Mastercard / issuer processor 结算
- 已完成的 KYC / KYB
- 已完成的 chargeback 流程
- 已进入 PCI 敏感卡数据生产环境

所以最准确的对外说法应该是：

- YNX 已经有可编程 mock card control layer
- 但还没有 live compliant issuer integration

## 5. 为什么这很重要

YNX Card 真正有价值的地方，不是“做一个好看的卡片页面”，而是做面向 Web4 钱包和 AI Agent 的可编程消费控制层。

也就是说，方向应该是：

- 不是普通虚拟卡
- 而是 policy-bounded、可审计、可给 agent 使用的 spending control

## 6. 未来接真实服务商还需要什么

未来如果要把 YNX Card Mock 接到真实合规服务商，还需要：

- 法律实体和主体就绪
- issuer / program manager 合作关系
- KYC / KYB / sanctions / AML 流程
- 服务商 API 凭据和运营合同
- 安全的 PCI 范围卡数据处理设计
- 生产级对账、争议、退款、事故响应流程

所以当前 mock surface 的意义，是给未来真实接入打基础，而不是假装已经完成真实发卡。
