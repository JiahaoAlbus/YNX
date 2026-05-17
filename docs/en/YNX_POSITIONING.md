# YNX Positioning (EN)

Status: active  
Last updated: 2026-05-17
Canonical language: English

## One-line positioning

YNX is a **speed-first Web4 execution and trading layer** with **EVM-compatible developer access**, machine-payment workflows, and owner-policy-session controls for human and agent execution.

Current public-testnet wording:

`YNX public testnet is live for developers and operators. Core RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub services are online. NYXT/anyxt is the fully usable public-testnet asset. Public wrapped-token contracts and bridge routes for BTC, ETH, BNB, USDT, and USDC are deployed on 9102 as testnet representations; production-grade external deposit/withdraw and official trading liquidity are not live yet.`

## Why users choose YNX

- Speed-first execution with low-latency public RPC, EVM wallet compatibility, and trading-oriented UX.
- EVM-native onboarding with low-friction tooling (wallets, contracts, RPC compatibility).
- AI settlement orientation: policy-bounded job lifecycle, result commits, challenge/slash, and vault-funded reward finalization now have both gateway and on-chain settlement rails.
- Governance transparency: operators can inspect governance and economics metadata through API.
- Fast operator rollout: profile-based runtime scripts for speed/stability tradeoff by topology.

## Against larger chains

YNX does not compete by claiming the largest liquidity today.  
YNX competes on:

- extreme execution speed and low-latency UX,
- practical developer velocity,
- curated mainstream-asset onboarding through wrapped BTC/ETH/BNB/stablecoin targets,
- AI/Web4 workload readiness,
- observability of governance and operations,
- scalable validator onboarding when the product needs more decentralization.

YNX should not claim BTC/ETH/BNB/USDT/USDC trading, mainnet-candidate readiness, or decentralized-validator readiness until the relevant gates pass.

## AI positioning

YNX should not sell AI as a generic chatbot feature. The useful AI angle is:

`AI agents can act under owner-defined Web4 policy and settle work on YNX through verifiable job/vault/payment rails.`

Current public-testnet status:

- Web4 Hub: policies, sessions, identities, agents, intents, tool authorization, and audit logs.
- AI Gateway: vaults, jobs, result commits, challenge/finalize flow, x402-style resource payment, and stats.
- On-chain settlement: `YNXAISettlement` at `0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf`.

This is useful for autonomous tools, paid API calls, agent marketplaces, task bounties,
and enterprise AI execution budgets. It is not enough to claim generalized AI
intelligence, decentralized model hosting, or production-grade AI commerce yet.

References:

- `docs/en/PUBLIC_ASSET_STATUS.md`
- `docs/en/SPEED_FIRST_MULTI_ASSET_TRADING_PLAN.md`
- `docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md`

## Machine-readable positioning endpoint

- `GET /ynx/overview`

Includes:

- governance metadata,
- value proposition flags,
- positioning statement and reasons.
