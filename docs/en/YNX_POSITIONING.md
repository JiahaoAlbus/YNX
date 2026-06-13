# YNX Positioning (EN)

Status: active  
Last updated: 2026-05-17
Canonical language: English

## One-line positioning

YNX is a **Web4 and AI-execution layer** with **EVM-compatible developer
access**, machine-payment workflows, and owner-policy-session controls for
human and agent execution.

Current public-testnet wording:

`YNX public testnet is live for developers and operators. Core RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub services are online. NYXT/anyxt is the fully usable public-testnet asset. Public wrapped-token contracts and bridge routes for BTC, ETH, BNB, USDT, and USDC are deployed on 9102 as testnet representations; production-grade external deposit/withdraw and official trading liquidity are not live yet.`

## What YNX Is And Is Not

YNX should currently be presented as:

- a live public-testnet execution layer;
- a policy-bounded AI/Web4 execution stack;
- a non-custodial infrastructure project that is still hardening.

YNX should not currently be presented as:

- a novel-consensus breakthrough;
- a fully decentralized validator network;
- a production bridge or production asset-custody stack;
- a mainnet-grade financial infrastructure network.

## Why users choose YNX

- Speed-first execution with low-latency public RPC, EVM wallet compatibility, and trading-oriented UX.
- EVM-native onboarding with low-friction tooling (wallets, contracts, RPC compatibility).
- AI settlement orientation: policy-bounded job lifecycle, result commits, challenge/slash, and vault-funded reward finalization now have both gateway and on-chain settlement rails.
- Governance transparency: operators can inspect governance and economics metadata through API.
- Fast operator rollout: profile-based runtime scripts for speed/stability tradeoff by topology.

## Against larger chains

YNX does not compete by claiming the largest liquidity today.  
YNX competes on:

- execution controls for humans and agents,
- session-scoped policy enforcement,
- AI/Web4 settlement rails,
- practical developer velocity,
- AI/Web4 workload readiness,
- observability of governance and operations,
- scalable validator onboarding when the product needs more decentralization.

YNX should not claim BTC/ETH/BNB/USDT/USDC production trading, mainnet-candidate
readiness, or decentralized-validator readiness until the relevant gates pass.

The strongest moat today is not generic chain assembly. The strongest moat today
is the policy/session execution model and the settlement/operator stack around
it.

## AI positioning

YNX should not sell AI as a generic chatbot feature or only as an "agent
permission" feature. The useful direction is broader:

`YNX Intelligence Layer: live chain intelligence, bridge/trading guidance, AI task execution, machine payments, owner policy controls, on-chain settlement, operational alerts, and developer support on top of YNX.`

The agent settlement sentence remains an important sub-capability:

`AI agents can act under owner-defined Web4 policy and settle work on YNX through verifiable job/vault/payment rails.`

Current public-testnet status:

- Web4 Hub: policies, sessions, identities, agents, intents, tool authorization, and audit logs.
- AI Gateway: vaults, jobs, result commits, challenge/finalize flow, x402-style resource payment, and stats.
- Intelligence API: `POST /ai/chat` and `GET /ai/intelligence/brief` expose live public-testnet context from the bridge, route registry, asset status, Web4 Hub, and AI settlement gateway.
- On-chain settlement: `YNXAISettlement` at `0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf`.

This is useful for chain operators, traders testing bridge routes, autonomous
tools, paid API calls, agent marketplaces, task bounties, and enterprise AI
execution budgets. The public testnet now has a live deterministic intelligence
mode and can switch to a configured LLM provider through runtime environment
variables. It is not yet a decentralized model-hosting network or production
AI-commerce mainnet.

References:

- `docs/en/PUBLIC_ASSET_STATUS.md`
- `docs/en/SPEED_FIRST_MULTI_ASSET_TRADING_PLAN.md`
- `docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md`
- `docs/en/FUNDRAISING_MEMO_2026_06_13.md`

## Machine-readable positioning endpoint

- `GET /ynx/overview`

Includes:

- governance metadata,
- value proposition flags,
- positioning statement and reasons.
