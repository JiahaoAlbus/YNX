# YNX Web4 Website Rebuild Prompt for Gemini

Status: active  
Last updated: 2026-05-02  
Target frontend repository: `https://github.com/JiahaoAlbus/ynx-web4-website-new`  
Core protocol repository: `https://github.com/JiahaoAlbus/YNX`

## 1. Use this prompt

Copy the prompt below into Gemini when rebuilding the YNX Web4 website from scratch.

```text
You are a senior frontend engineer, interaction designer, and Web3/AI technical copywriter.

Build a new YNX Web4 website from scratch in this repository:

https://github.com/JiahaoAlbus/ynx-web4-website-new

Do not use the old repository:

https://github.com/JiahaoAlbus/YNX-WEB4-website

Use the YNX core protocol repository as the canonical source of truth:

https://github.com/JiahaoAlbus/YNX

The website must be rebuilt as a polished Apple-quality product site for an AI-native sovereign execution layer. The primary colors are Klein blue and white.

## Product positioning

YNX Web4 is a public execution network for humans and AI agents.

Use this core message:

- AI-native sovereign execution layer.
- EVM-compatible public testnet.
- Web4 control order: Owner > Policy > Session Key > Agent Action.
- AI Gateway for AI jobs, vaults, machine payments, x402-style resources, and settlement.
- Web4 Hub for wallet bootstrap, policies, sessions, identities, agents, intents, claims, challenges, finalization, and audit.
- Public testnet is live. Mainnet is not live yet.

Do not describe YNX AI as a chatbot or a proprietary LLM model. YNX AI is execution, policy, payment, audit, and settlement infrastructure for AI agents.

## Required current facts

Keep these facts consistent across all pages:

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
- Current public testnet has 4 bonded active validators.
- Testnet tokens have no mainnet value.
- Remaining external work before mainnet: independent external validators, additional public RPC/sentry outside the current provider/account, real alerting/on-call, restore drill, and external security review.

## Design direction

Make the website feel like an Apple product launch page adapted to a technical infrastructure product:

- Minimal, confident, spacious.
- White and Klein blue as the dominant identity.
- Use dark sections only where they create contrast for technical diagrams or terminal/code surfaces.
- Use crisp typography, strong hierarchy, large confident headings, and readable body copy.
- Use a restrained palette: white, near-black ink, Klein blue, cool gray, subtle glass/blur materials, and very light blue tints.
- Avoid generic crypto neon, purple gradients, noisy 3D coins, meme styling, cluttered dashboards, and overdecorated cards.
- Use product-quality microinteractions: scroll-linked reveals, parallax depth, shared motion language, hover lift, smooth section transitions, subtle blur/material changes, and connected timeline motion.
- Motion must be purposeful, smooth, and spatially coherent. Each animation should help explain hierarchy, transition, causality, or state.
- Respect reduced-motion preferences and provide a graceful static version.
- Mobile must be first-class: no text overflow, no layout squeeze, no horizontal scroll, tappable controls at comfortable sizes.

Apple-inspired motion principles:

- Use motion to maintain continuity between states.
- Avoid gratuitous animation.
- Prefer smooth, physics-like easing.
- Keep transitions fast enough that users never wait for content.
- Coordinate section reveals so each element feels part of one system, not random independent animations.

## Recommended stack

Use:

- React
- Vite
- TypeScript
- Tailwind CSS
- Framer Motion or Motion
- lucide-react
- react-router-dom
- react-markdown with GFM support

If the repo already has a working stack, preserve it unless there is a strong reason to change.

## Required routes

Build these routes:

- `/`
- `/builders`
- `/validators`
- `/testnet`
- `/research`
- `/about`
- `/docs`
- `/docs/:language/:slug`

Deep links must work on Vercel/static hosting.

## Homepage structure

The home page must include:

1. Hero
   - Headline: `AI-Native Execution for Humans and Agents`
   - Alternative acceptable headline: `The Sovereign Execution Layer for Web4`
   - Subheadline: `YNX is an EVM-compatible public testnet where humans, apps, and AI agents coordinate through policy-bounded execution, machine-payment vaults, and verifiable settlement.`
   - Badges:
     - Public Testnet Live
     - EVM Chain ID 9102
     - AI Gateway Live
     - Web4 Hub Live
     - 4 Bonded Validators
   - CTAs:
     - View Explorer
     - Run AI/Web4 Demo
     - Join Testnet
     - Become a Validator
     - Read Docs
     - GitHub

2. Sovereignty hierarchy
   - Visualize `Owner > Policy > Session Key > Agent Action`.
   - Explain that users/DAOs remain sovereign while agents can act within bounded limits.

3. AI/Web4 settlement demo
   - Show the complete flow:
     1. Create Web4 policy
     2. Issue bounded session key
     3. Create AI payment vault
     4. Publish AI job
     5. Worker commits result hash
     6. Finalize job
     7. Reward settles from vault
     8. JSON evidence is written under `output/ai_web4_demo/<run-id>/`
   - Show this command:
     ```bash
     ./scripts/ai_web4_settlement_demo.sh
     ```
   - Explain:
     `A user grants an AI agent bounded authority, the agent completes a job, and YNX settles the reward through the AI settlement layer.`

4. Live testnet status
   - Show chain id, EVM chain id, endpoints, validator count, service health links.

5. Builder paths
   - EVM developers: Solidity, Hardhat, Foundry through EVM RPC.
   - AI agent developers: `/ai/jobs`, `/ai/vaults`, `/ai/payments`, `/x402/resource`.
   - Web4 architects: `/web4/policies`, `/web4/policies/:id/sessions`, `/web4/agents`, `/web4/intents`, `/web4/audit`.

6. Validator call
   - External validators wanted.
   - Use canonical install:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
     export PATH="$HOME/.local/bin:$PATH"
     ynx join --role full-node
     ynx join --role validator
     ```

7. Security and readiness
   - High-assurance crypto model.
   - YNX ARES hybrid crypto.
   - Non-custodial boundary.
   - Launch-grade testnet runbook.
   - Mainnet not live yet.

## Docs architecture: critical requirement

Do not hardcode all markdown into the app bundle.

Implement a docs sync system that pulls docs from the YNX core repo.

Add:

`scripts/sync-docs-from-core.mjs`

The script must:

1. Use local `YNX_CORE_REPO_PATH` if provided.
2. Otherwise fetch from GitHub raw:
   `https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/<sourcePath>`
3. Write markdown files into:
   `public/docs/<language>/<slug>.md`
4. Generate:
   `public/docs/registry.json`
5. Include registry fields:
   - `id`
   - `title`
   - `language`
   - `category`
   - `sourcePath`
   - `publicPath`
   - `description`
   - `tags`

Update `package.json`:

```json
{
  "scripts": {
    "sync:docs": "node scripts/sync-docs-from-core.mjs",
    "prebuild": "npm run sync:docs",
    "predev": "npm run sync:docs"
  }
}
```

The Docs page must:

- Load `/docs/registry.json` first.
- Render sidebar and categories immediately.
- Fetch only the selected markdown file.
- Show skeleton while loading.
- Show clear error state with `sourcePath` and `publicPath` if fetch fails.
- Support `/docs/:language/:slug` deep links.
- Search registry metadata instantly without blocking UI.
- Avoid white screens.
- Avoid needing refresh.
- Be responsive on mobile with collapsible sidebar.
- Support tables, code blocks, links, Chinese filenames, and OpenAPI YAML content.

## Required docs to sync

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

## Docs categories

Use this information architecture:

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
  - All Chinese docs

## Page requirements

### Builders

Make the Builders page practical. Include:

- EVM quickstart.
- AI job/vault/payment/x402 API surface.
- Web4 policy/session/agent/intent/audit API surface.
- AI/Web4 demo command.
- Links to Docs and GitHub.

### Validators

Include:

- External validator call.
- 4 bonded active validators today.
- Candidate preflight:
  `scripts/validator_candidate_check.sh`
- Launch monitor:
  `scripts/testnet_launch_grade_monitor.sh`
- Canonical install commands.
- Clear warning that testnet tokens have no mainnet value.

### Testnet

Show:

- Chain id.
- EVM chain id.
- Endpoints.
- Validator count.
- Service status cards.
- Mainnet-not-live warning.
- Remaining external work.

### Research

Explain:

- Web4 is not Web3 plus an AI frontend.
- AI agents are first-class network participants.
- Users interact through intent.
- Task/result/challenge/finalize settlement.
- Human/DAO sovereignty over autonomous agents.

## Visual and interaction requirements

- Primary palette: Klein blue `#002FA7`, white, ink black, cool grays.
- Use SF-like typography stack:
  `Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", sans-serif`
- Use large display type for hero only.
- Use dense but readable technical sections.
- Do not use nested cards or card-in-card layouts.
- Do not use purple/blue gradient blob backgrounds.
- Do not use random decorative orbs.
- Use visual assets or elegant technical diagrams, not generic crypto illustrations.
- Use lucide icons in buttons.
- Motion must be connected:
  - hero elements reveal in one timeline;
  - scroll sections use consistent stagger;
  - hierarchy diagram animates from Owner to Agent Action;
  - demo flow animates as one connected path;
  - endpoint cards have subtle hover lift and light reflection;
  - docs sidebar transitions smoothly;
  - route changes fade/slide consistently.
- Add `prefers-reduced-motion` handling.

## SEO and metadata

Update `index.html`:

- Title:
  `YNX Web4 | Sovereign Execution Layer for AI Agents`
- Description:
  `YNX Web4 is an EVM-compatible public testnet for humans and AI agents, with policy-bounded execution, AI settlement, machine-payment vaults, and validator onboarding.`
- Remove `Full Blood Testnet`.
- Use professional OG/Twitter metadata.

## README

Rewrite README for this frontend repo:

- State that this is the official YNX Web4 website.
- Link to core repo.
- Explain docs sync.
- Commands:
  ```bash
  npm install
  npm run sync:docs
  npm run dev
  npm run lint
  npm run build
  ```
- Local docs sync:
  ```bash
  YNX_CORE_REPO_PATH=/path/to/YNX npm run sync:docs
  ```

## Verification

Run:

```bash
npm install
npm run sync:docs
npm run lint
npm run build
```

If tests exist:

```bash
npm test
```

Manually verify:

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

Final response must include:

1. Changed files.
2. New docs sync script behavior.
3. Registry output path.
4. Markdown output path.
5. Docs loading issue root cause.
6. How it was fixed.
7. lint/build/test results.
8. Remaining issues, if any.
```

## 2. Design references

The prompt intentionally follows Apple Human Interface Guidelines principles for motion, layout, and typography:

- Motion should provide context, feedback, and continuity instead of distraction.
- Layout should adapt across devices and avoid clipping or overflow.
- Typography should use size, weight, and color to create hierarchy.

