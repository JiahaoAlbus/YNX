# YNX AI/Web4 官方演示

状态：active  
最后更新：2026-05-02

## 1. 这个演示说明什么

这个 demo 用一个最小闭环说明 YNX 的 AI/Web4 不是“聊天机器人”，而是：

- Web4 policy 管住 AI Agent 的权限和预算；
- session key 让 Agent 可以在限制范围内自动执行；
- AI Gateway 负责 AI 任务、结果提交、挑战期和结算；
- vault 负责机器支付和奖励支出；
- audit / stats / overview 让执行过程可查。

一句话：

**用户给 AI Agent 一个有限授权，Agent 完成任务后，通过 YNX 的 AI 结算层自动付款。**

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

## 3. 演示流程

1. 创建 Web4 policy。
2. owner 签发带上限的 session key。
3. AI Gateway 创建 payment vault。
4. 用户发布 AI job。
5. AI worker 提交 result hash。
6. job finalize 后，从 vault 自动结算 reward。
7. 输出每一步 JSON 证据文件。

## 4. 用线上服务跑

如果要指向已部署的服务，可以显式传入 URL：

```bash
YNX_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
AI_URL=https://ai.ynxweb4.com \
./scripts/ai_web4_settlement_demo.sh
```

注意：线上执行会写入线上 Web4/AI Gateway 的测试数据，只应在测试网环境使用。

## 5. 对外解释口径

这个 demo 展示的是 YNX 的核心差异：

- 传统链主要结算人手动发起的交易；
- YNX 让 AI Agent 在 owner/policy/session 限制内自动执行；
- AI 任务有结果承诺、挑战窗口、最终结算和审计记录；
- 机器支付不是应用私有逻辑，而是 YNX Web4/AI 协议面的一部分。

