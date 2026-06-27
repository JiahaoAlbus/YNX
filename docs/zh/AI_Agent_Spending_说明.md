# YNX 上的 AI Agent Spending 说明

状态：active  
最后更新：2026-06-27

## 1. 核心思路

YNX 把 AI Agent Spending 当作一个“受限执行问题”，而不是给 agent 无限钱包权限。

控制顺序是：

1. owner
2. policy
3. session
4. payment 或 card authorization attempt

## 2. 当前两种形态

YNX 现在有两种 spending-control 形态：

- AI settlement vault 流程
- YNX Card Mock authorization 流程

Vault 更适合 machine-payment budget 和 AI job settlement。
YNX Card Mock 更适合未来卡支付式消费控制和审计逻辑。

## 3. 当前能约束什么

现在已经能表达的限制包括：

- allowed action types
- session TTL
- max ops
- session max spend
- policy max daily spend
- policy max total spend
- card 单笔 / 日 / 总限额
- merchant / MCC / country 过滤
- agent allowlist

## 4. 为什么这重要

目标不是“让 agent 拿着热钱包随便花”。

目标是：

- 显式限额
- 显式通过 / 拒绝
- 清晰 audit trail
- 未来可接真实 provider

## 5. 当前边界

这还不等于：

- 生产级托管
- 真实银行卡发行
- 无限自主消费

它现在是一个受控 spending + audit 基础层，未来才可以在法律和运营边界下接真实服务商。
