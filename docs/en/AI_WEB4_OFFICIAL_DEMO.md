# YNX AI/Web4 Official Demo

Status: active  
Last updated: 2026-05-02

## 1. What this demo proves

This demo shows that YNX AI/Web4 is not a chatbot wrapper. It is a bounded execution and settlement flow for AI agents:

- Web4 policy controls agent permissions and budget.
- Session keys let agents act within explicit limits.
- AI Gateway manages jobs, result commits, finalization, and reward settlement.
- Vaults provide machine-payment budgets.
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

## 3. Flow

1. Create a Web4 policy.
2. Issue a bounded session key.
3. Create an AI payment vault.
4. Publish an AI job.
5. Commit a worker result hash.
6. Finalize the job and settle reward from the vault.
7. Persist JSON evidence for each step.

## 4. Run against deployed services

```bash
YNX_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
AI_URL=https://ai.ynxweb4.com \
./scripts/ai_web4_settlement_demo.sh
```

This writes demo test data to the configured services. Use it only against testnet environments.

