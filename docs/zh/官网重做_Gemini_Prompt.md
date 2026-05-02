# YNX Web4 官网重做 Gemini Prompt

状态：active  
最后更新：2026-05-02  
目标前端仓库：`https://github.com/JiahaoAlbus/ynx-web4-website-new`  
核心协议仓库：`https://github.com/JiahaoAlbus/YNX`

## 1. 使用方式

把下面整段 prompt 直接发给 Gemini，用于从头重做 YNX Web4 官网。

```text
你是高级前端工程师、交互设计师和 Web3/AI 技术文案负责人。

请从头重做 YNX Web4 官网，目标仓库是：

https://github.com/JiahaoAlbus/ynx-web4-website-new

不要使用旧仓库：

https://github.com/JiahaoAlbus/YNX-WEB4-website

核心协议仓库是唯一事实来源：

https://github.com/JiahaoAlbus/YNX

网站要像 Apple 产品发布页一样克制、丝滑、高级，但主题是技术基础设施产品。主配色必须是克莱因蓝和白色。

## 产品定位

YNX Web4 是给人类和 AI Agent 使用的公共执行网络。

统一使用这个定位：

- AI-native sovereign execution layer。
- EVM-compatible public testnet。
- Web4 权限顺序：Owner > Policy > Session Key > Agent Action。
- AI Gateway 负责 AI jobs、vaults、machine payments、x402-style resources、settlement。
- Web4 Hub 负责 wallet bootstrap、policies、sessions、identities、agents、intents、claims、challenges、finalization、audit。
- 公开测试网已上线。
- 主网还没有上线。

不要把 YNX AI 描述成聊天机器人，也不要说成 YNX 自己训练的大模型。YNX 的 AI 是 AI Agent 的执行、权限、支付、审计和结算基础设施。

## 必须保持一致的事实

全站必须统一：

- Public Testnet Chain ID: `ynx_9102-1`
- EVM Chain ID: `9102` / `0x238e`
- Denom: `anyxt`
- RPC: `https://rpc.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`
- 当前公开测试网有 4 个 bonded active validators。
- 测试币没有主网价值。
- 主网还没有上线。
- 主网前仍需完成：独立外部验证人、当前 provider/account 之外的额外 public RPC/sentry、真实告警/on-call、恢复演练、外部安全审计。

## 视觉方向

做成 Apple 风格的高端技术官网：

- 极简、克制、留白充分。
- 主色：克莱因蓝 + 白色。
- 深色区块只用于终端、代码、技术图或高对比章节。
- 字体清晰，层级强，正文易读。
- 色彩限制在白色、近黑、克莱因蓝、冷灰、浅蓝 tint、轻微 glass/blur。
- 不要普通 crypto neon。
- 不要紫色渐变 blob。
- 不要噪音背景。
- 不要 meme 风格。
- 不要一堆互不相关的卡片。

动效要求：

- 每一个动效都要服务理解，不要为了炫。
- 动效之间要有连接感：Hero、层级图、demo flow、endpoint cards、docs sidebar 的运动语言要一致。
- 使用 scroll reveal、parallax depth、shared timeline、hover lift、route transition。
- hierarchy diagram 要从 Owner 流到 Agent Action。
- demo flow 要像一条连续路径，而不是孤立卡片。
- endpoint cards hover 时只做细微浮起和光泽，不要夸张。
- 必须支持 `prefers-reduced-motion`。
- 用户不能等动画，内容要快速出现。

## 推荐技术栈

使用：

- React
- Vite
- TypeScript
- Tailwind CSS
- Framer Motion 或 Motion
- lucide-react
- react-router-dom
- react-markdown + GFM

如果仓库已有可用技术栈，优先保留。

## 必须有的页面

- `/`
- `/builders`
- `/validators`
- `/testnet`
- `/research`
- `/about`
- `/docs`
- `/docs/:language/:slug`

Vercel/static hosting 下深链接必须可用。

## 首页结构

首页必须包含：

1. Hero
   - 标题：`AI-Native Execution for Humans and Agents`
   - 或：`The Sovereign Execution Layer for Web4`
   - 副标题：`YNX is an EVM-compatible public testnet where humans, apps, and AI agents coordinate through policy-bounded execution, machine-payment vaults, and verifiable settlement.`
   - badges:
     - Public Testnet Live
     - EVM Chain ID 9102
     - AI Gateway Live
     - Web4 Hub Live
     - 4 Bonded Validators
   - CTA:
     - View Explorer
     - Run AI/Web4 Demo
     - Join Testnet
     - Become a Validator
     - Read Docs
     - GitHub

2. Sovereignty hierarchy
   - 可视化 `Owner > Policy > Session Key > Agent Action`。
   - 解释人类/DAO 保持最高主权，AI Agent 只能在限制内执行。

3. AI/Web4 settlement demo
   - 展示完整流程：
     1. Create Web4 policy
     2. Issue bounded session key
     3. Create AI payment vault
     4. Publish AI job
     5. Worker commits result hash
     6. Finalize job
     7. Reward settles from vault
     8. JSON evidence is written under `output/ai_web4_demo/<run-id>/`
   - 展示命令：
     ```bash
     ./scripts/ai_web4_settlement_demo.sh
     ```
   - 解释：
     `A user grants an AI agent bounded authority, the agent completes a job, and YNX settles the reward through the AI settlement layer.`
   - 中文：
     `用户给 AI Agent 一个有限授权，Agent 完成任务后，通过 YNX 的 AI 结算层自动付款。`

4. Live testnet status
   - 展示 chain id、EVM chain id、endpoints、验证人数量、服务健康链接。

5. Builder paths
   - EVM developers: Solidity、Hardhat、Foundry、EVM RPC。
   - AI agent developers: `/ai/jobs`、`/ai/vaults`、`/ai/payments`、`/x402/resource`。
   - Web4 architects: `/web4/policies`、`/web4/policies/:id/sessions`、`/web4/agents`、`/web4/intents`、`/web4/audit`。

6. Validator call
   - 需要外部验证人。
   - 使用 canonical install：
     ```bash
     curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
     export PATH="$HOME/.local/bin:$PATH"
     ynx join --role full-node
     ynx join --role validator
     ```

7. Security and readiness
   - High-assurance crypto model。
   - YNX ARES hybrid crypto。
   - Non-custodial boundary。
   - Launch-grade testnet runbook。
   - 明确主网未上线。

## Docs 架构：最重要

不要把所有 markdown 写死进前端 bundle。

必须实现从 YNX 核心仓库同步 docs 的机制。

新增：

`scripts/sync-docs-from-core.mjs`

脚本要求：

1. 如果有 `YNX_CORE_REPO_PATH`，优先从本地核心仓库读取。
2. 否则从 GitHub raw 拉取：
   `https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/<sourcePath>`
3. 把 markdown 写到：
   `public/docs/<language>/<slug>.md`
4. 生成：
   `public/docs/registry.json`
5. registry 字段：
   - `id`
   - `title`
   - `language`
   - `category`
   - `sourcePath`
   - `publicPath`
   - `description`
   - `tags`

更新 `package.json`：

```json
{
  "scripts": {
    "sync:docs": "node scripts/sync-docs-from-core.mjs",
    "prebuild": "npm run sync:docs",
    "predev": "npm run sync:docs"
  }
}
```

Docs 页面要求：

- 先加载 `/docs/registry.json`。
- 立即渲染 sidebar 和 category。
- 只 fetch 当前选中的 markdown。
- loading 时显示 skeleton，不要白屏。
- fetch 失败时显示明确错误，包含 `sourcePath` 和 `publicPath`。
- 支持 `/docs/:language/:slug` 深链接。
- 搜索只基于 registry metadata，必须即时响应。
- 不需要刷新页面。
- 移动端 sidebar 可折叠。
- 支持表格、代码块、链接、中文文件名、OpenAPI YAML。

## 必须同步的文档

English:

- `docs/en/AI_WEB4_OFFICIAL_DEMO.md`
- `docs/en/PUBLIC_TESTNET_STATUS_2026_05_02.md`
- `docs/en/TESTNET_LAUNCH_GRADE_RUNBOOK.md`
- `docs/en/EXTERNAL_VALIDATOR_ONBOARDING_PACKET.md`
- `docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md`
- `docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md`
- `docs/en/V2_HIGH_ASSURANCE_CRYPTO_MODEL.md`
- `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`
- `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
- `docs/en/YNX_v2_WEB4_API.md`
- `docs/en/WEB4_FOR_YNX.md`
- `docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md`
- `docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`
- `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`

Chinese:

- `docs/zh/AI_WEB4_官方演示.md`
- `docs/zh/WEB4_在YNX中的定义.md`
- `docs/zh/YNX_v2_WEB4_蓝图.md`
- `docs/zh/YNX_v2_WEB4_API_接口说明.md`
- `docs/zh/V2_公开测试网加入手册.md`
- `docs/zh/V2_验证节点加入手册.md`
- `docs/zh/V2_共识验证人加入手册.md`
- `docs/zh/V2_高保证加密与抗量子安全模型.md`
- `docs/zh/YNX_ARES_混合抗量子加密协议.md`
- `docs/zh/YNX_非托管商业与合规边界.md`
- `docs/zh/主网与行业级上线门禁.md`
- `docs/zh/项目非技术上线手续包.md`

OpenAPI:

- `infra/openapi/ynx-v2-ai.yaml`
- `infra/openapi/ynx-v2-web4.yaml`

## Docs 分类

- Start Here
  - Public Testnet Join Guide
  - AI/Web4 Official Demo
  - Builder Quickstart
  - Validator Onboarding

- AI / Web4
  - Web4 Definition
  - Web4 API
  - AI Settlement API
  - AI/Web4 Official Demo
  - Web4 Hub / AI Gateway OpenAPI

- Validators & Testnet Ops
  - Public Testnet Status 2026-05-02
  - Testnet Launch-Grade Runbook
  - External Validator Onboarding Packet
  - Validator Node Join Guide
  - Consensus Validator Join Guide

- Security
  - High Assurance Crypto Model
  - YNX ARES Hybrid Crypto Protocol
  - Non-Custodial Business and Compliance Boundary

- Mainnet Readiness
  - Mainnet and Industry Readiness Gates
  - Project Non-Technical Launch Packet

- Chinese Docs
  - 所有中文文档

## Builders 页面

必须包含：

- EVM quickstart。
- AI job/vault/payment/x402 API。
- Web4 policy/session/agent/intent/audit API。
- AI/Web4 demo command。
- Docs 和 GitHub 链接。

## Validators 页面

必须包含：

- 外部验证人招募。
- 当前 4 个 bonded active validators。
- 候选人检查：
  `scripts/validator_candidate_check.sh`
- 运行监控：
  `scripts/testnet_launch_grade_monitor.sh`
- canonical install commands。
- 测试币没有主网价值的提示。

## Testnet 页面

必须展示：

- Chain id。
- EVM chain id。
- Endpoints。
- Validator count。
- Service status cards。
- 主网未上线提示。
- 剩余外部工作。

## Research 页面

解释：

- Web4 不是 Web3 加 AI 前端。
- AI Agent 是一等网络参与者。
- 用户通过 intent 交互。
- 任务/结果/挑战/finalize 结算。
- 人类/DAO 对自主 agent 保持最高主权。

## 视觉与交互

- 主色：克莱因蓝 `#002FA7`、白色、ink black、cool grays。
- 字体栈：
  `Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", sans-serif`
- 只有 hero 用超大 display type。
- 技术章节信息密度高但清晰。
- 不要 card 套 card。
- 不要紫色/蓝紫渐变 blob。
- 不要随机装饰圆球。
- 使用 lucide icons。
- 动效必须连贯：
  - hero elements reveal in one timeline；
  - scroll sections use consistent stagger；
  - hierarchy diagram animates from Owner to Agent Action；
  - demo flow animates as one connected path；
  - endpoint cards have subtle hover lift and light reflection；
  - docs sidebar transitions smoothly；
  - route changes fade/slide consistently。
- 支持 `prefers-reduced-motion`。

## SEO

更新 `index.html`：

- Title:
  `YNX Web4 | Sovereign Execution Layer for AI Agents`
- Description:
  `YNX Web4 is an EVM-compatible public testnet for humans and AI agents, with policy-bounded execution, AI settlement, machine-payment vaults, and validator onboarding.`
- 删除 `Full Blood Testnet`。
- 使用专业 OG/Twitter metadata。

## README

重写 README：

- 说明这是官方 YNX Web4 website。
- 链接核心仓库。
- 说明 docs sync。
- 命令：
  ```bash
  npm install
  npm run sync:docs
  npm run dev
  npm run lint
  npm run build
  ```
- 本地 docs sync：
  ```bash
  YNX_CORE_REPO_PATH=/path/to/YNX npm run sync:docs
  ```

## 验证

运行：

```bash
npm install
npm run sync:docs
npm run lint
npm run build
```

如果有测试：

```bash
npm test
```

手动检查：

- `/`
- `/docs`
- `/docs/en/ai-web4-official-demo`
- `/docs/en/testnet-launch-grade-runbook`
- `/docs/en/external-validator-onboarding`
- `/docs/en/ares-hybrid-crypto`
- `/docs/zh/ai-web4-official-demo`
- `/builders`
- `/validators`
- `/testnet`

最终输出：

1. 修改了哪些文件。
2. 新 docs sync 脚本行为。
3. registry 输出路径。
4. markdown 输出路径。
5. Docs 加载慢/需要刷新问题的根因。
6. 修复方式。
7. lint/build/test 结果。
8. 剩余问题。
```

## 2. 设计依据

这份 prompt 按 Apple Human Interface Guidelines 的 motion、layout、typography 原则约束：

- 动效要提供上下文、反馈和连续性，不要只为了炫。
- 布局要自适应，避免裁切、遮挡和横向溢出。
- 字体层级要用字号、字重、颜色清楚表达。

