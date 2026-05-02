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

Expected console shape:

```text
YNX AI/Web4 settlement demo
Run id: demo_<timestamp>
Web4: http://127.0.0.1:18091
AI:   http://127.0.0.1:18090

1. Created Web4 policy: policy_demo_<timestamp>
2. Issued bounded session key: session_demo_<timestamp>
3. Created AI payment vault: vault_demo_<timestamp>
4. Published AI job: job_demo_<timestamp>
5. Worker committed result hash: <sha256>
6. Finalized job and settled reward payment: pay_<id>
```

Evidence files:

```text
output/ai_web4_demo/<run-id>/01_policy.json
output/ai_web4_demo/<run-id>/02_session.json
output/ai_web4_demo/<run-id>/03_vault.json
output/ai_web4_demo/<run-id>/04_job_created.json
output/ai_web4_demo/<run-id>/05_job_committed.json
output/ai_web4_demo/<run-id>/06_job_finalized.json
output/ai_web4_demo/<run-id>/07_ai_stats.json
output/ai_web4_demo/<run-id>/08_web4_overview.json
```

## 4. Run against deployed services

```bash
YNX_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
AI_URL=https://ai.ynxweb4.com \
./scripts/ai_web4_settlement_demo.sh
```

This writes demo test data to the configured services. Use it only against testnet environments.

## 5. Website docs integration

The website must not embed this document as stale hardcoded content. It should sync this file from the YNX core repository during website build and serve it as an on-demand markdown document under:

```text
/docs/en/ai-web4-official-demo
```

Recommended website sync rule:

```text
sourcePath: docs/en/AI_WEB4_OFFICIAL_DEMO.md
publicPath: /docs/en/ai-web4-official-demo.md
route: /docs/en/ai-web4-official-demo
category: Start Here
tags: ai, web4, demo, settlement, policy, session, vault
```
