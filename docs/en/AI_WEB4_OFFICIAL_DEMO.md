# YNX AI/Web4 Official Demo

Status: active  
Last updated: 2026-06-01

## 1. What this demo proves

This demo shows that YNX AI/Web4 is not a chatbot wrapper. It is a bounded execution and settlement flow for AI agents:

- Web4 policy controls agent permissions and budget.
- Session keys let agents act within explicit limits.
- AI Gateway manages jobs, result commits, finalization, and reward settlement.
- Vaults provide machine-payment budgets.
- The public testnet has an on-chain AI settlement rail for vault-funded jobs.
- Audit, stats, and overview endpoints make the workflow inspectable.

In one sentence:

**A user grants an AI agent bounded authority, the agent completes a job, and YNX settles the reward through the AI settlement layer.**

## 2. Run locally

From the repository root:

```bash
./scripts/ai_web4_settlement_demo.sh
```

The script starts temporary local Web4 Hub and AI Gateway processes and writes evidence to:

```text
output/ai_web4_demo/<run-id>/
```

It does not modify public testnet state by default.

## 3. Public testnet on-chain settlement

The public testnet includes `YNXAISettlement`:

```text
0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf
```

This contract supports:

- policy-hash-bound vaults funded with the native EVM gas asset;
- AI job creation with reward and input hash;
- worker result-hash commits plus attestation URI;
- owner challenge/slash/cancel controls;
- reward finalization from the vault to the worker.

The gateway remains the user-facing API layer. The contract is the verifiable
settlement rail for high-value agent work.

## 4. Flow

1. Create a Web4 policy.
2. Issue a bounded session key.
3. Create an AI payment vault.
4. Publish an AI job.
5. Commit a worker result hash.
6. Finalize the job and settle reward from the vault.
7. Persist JSON evidence for each step.

## 5. Run against deployed services

```bash
YNX_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
AI_URL=https://ai.ynxweb4.com \
./scripts/ai_web4_settlement_demo.sh
```

This writes demo test data to the configured services. Use it only against testnet environments.

## 6. Public Testnet Evidence

Latest public-service demo run:

```text
Run id: public_20260601T092925Z
Policy: policy_public_20260601T092925Z
Session: session_public_20260601T092925Z
Vault: vault_public_20260601T092925Z
Job: job_public_20260601T092925Z
Reward payment: pay_b4944350c053cb11
Result hash: 58a24ec7ed9d9f7b3d67dde6d711d408f88c30cbe8e8c8a9a2a4602e59fdfa47
```

Live public-testnet AI stats after the run:

```text
total_jobs: 6
total_vaults: 5
total_payments: 6
finalized_jobs: 4
```

The useful product position is not "AI chat on a chain." It is:

```text
bounded AI authority + machine-payment vaults + auditable job settlement
```

That means YNX AI is useful when an agent needs permission limits, budget
limits, result commitments, and reward settlement. It is not a replacement
for model hosting, general chat, or entertainment-only AI experiences.
