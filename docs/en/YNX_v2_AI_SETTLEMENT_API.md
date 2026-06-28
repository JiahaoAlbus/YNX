# YNX v2 AI Intelligence and Settlement API (Draft)

Status: Active public-testnet API  
Last updated: 2026-06-06

## 1. Purpose

This document defines the first public API surface for the YNX v2 AI
Intelligence Layer and settlement workflow.

The API is designed for:

- users who want a live YNX status and bridge/trading assistant
- operators who need chain, bridge, Web4, and AI settlement diagnostics
- AI task publishers
- AI worker operators
- verifiers/challengers
- indexers and explorers

The public testnet has three AI layers:

- Intelligence API: live YNX context and chat at `https://ai.ynxweb4.com/ai/chat` and native streaming at `https://ai.ynxweb4.com/ai/chat/stream`
- Gateway settlement API: jobs, vaults, payments, x402, audit, and stats at `https://ai.ynxweb4.com`
- On-chain settlement rail: `YNXAISettlement` at `0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf`

Current public-testnet health:

```text
AI Gateway: https://ai.ynxweb4.com/health
Ready:      https://ai.ynxweb4.com/ready
On-chain:   enabled and ready
Jobs:       7 total, 5 finalized
Vaults:     6 total
Payments:   7 total
```

Public Intelligence endpoints:

```text
Brief:      https://ai.ynxweb4.com/ai/intelligence/brief
Chat:       POST https://ai.ynxweb4.com/ai/chat
Chat NDJSON: POST https://ai.ynxweb4.com/ai/chat/stream
Mode:       live deterministic by default; Ollama or external LLM when configured
```

Latest on-chain settlement evidence:

```text
Job:         job_public_onchain_20260606T053758Z
Vault tx:    0xd163ecab53a39d7a3f81631f1fce6d63dc5e9546056efe9c912dadcbd4611dd4
Job tx:      0x5399e55a19c6732bcc0627abdf14293a9a8c86edc960e2b494187f972154b26a
Commit tx:   0x9626e37e4fd51fd611aae120b07f4e9f2f4ee336716431837a9b3f6f968cb401
Finalize tx: 0xc9380f194927e15d0b7543a6ee8d7e5834e992a630501f4779aaca293f140ef2
```

## 2. Job Lifecycle

1. `created`: job posted with reward, deadline, and verification policy.
2. `committed`: worker submits result hash / attestation pointer.
3. `revealed`: optional reveal payload submitted.
4. `challenged`: challenger opens a dispute with stake.
5. `finalized`: reward payout or slash resolution.

## 3. Canonical Data Model

- `job_id` (string)
- `creator` (address)
- `worker` (address, optional before commitment)
- `vault_id` (string, optional funding source)
- `reward` (base denom amount)
- `stake` (base denom amount)
- `input_uri` (off-chain pointer)
- `result_hash` (hex)
- `attestation_uri` (optional)
- `status` (enum)
- `created_height` / `finalized_height`
- `payout_payment_id` (string, set when reward is settled from vault)

## 4. Intelligence Endpoints

- `GET /ai/intelligence/brief` — live YNX context from Bridge, route readiness, assets, Web4, and AI settlement state
- `POST /ai/chat` — live YNX assistant response
- `POST /ai/chat/stream` — NDJSON streaming response with per-request `requestId`, `meta`, `delta`, and `done` events

Example:

```bash
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  -d '{"message":"What is live on YNX now, and which assets can complete the bridge loop?"}' | jq
```

Response shape:

```json
{
  "ok": true,
  "mode": "live-deterministic",
  "model": "",
  "answer": "..."
}
```

Streaming response event shape:

```json
{"requestId":"chat_...","type":"meta","status":"started","mode":"llm:ollama"}
{"requestId":"chat_...","type":"delta","delta":"mock ","done":false}
{"requestId":"chat_...","type":"delta","delta":"answer","done":false}
{"requestId":"chat_...","type":"done","done":true,"mode":"llm:ollama","model":"qwen2.5:1.5b"}
```

When a runtime model is configured, the gateway keeps the same endpoint and
switches to LLM mode while preserving live YNX context in the prompt. The
official `answer` remains generated from deterministic live facts so route,
asset, and settlement status do not drift. Optional raw model text is returned
only when `include_model_answer` is set.

Supported runtime model modes:

```text
AI_LLM_PROVIDER=openai-responses
AI_LLM_API_KEY=<runtime-only key>
AI_LLM_MODEL=gpt-4o-mini

AI_LLM_PROVIDER=ollama
AI_LLM_BASE_URL=http://127.0.0.1:11434/api/chat
AI_LLM_MODEL=qwen2.5:1.5b
```

## 5. Settlement Endpoints

- `POST /ai/jobs` — create job
- `GET /ai/jobs/:id` — job detail
- `POST /ai/jobs/:id/commit` — commit result
- `POST /ai/jobs/:id/challenge` — open dispute
- `POST /ai/jobs/:id/finalize` — finalize settlement
- `GET /ai/stats` — aggregate metrics
- `POST /ai/vaults` — create machine-payment vault
- `GET /ai/vaults/:id` — vault detail
- `POST /ai/vaults/:id/deposit` — increase vault balance
- `POST /ai/payments/quote` — quote payment amount
- `POST /ai/payments/charge` — execute charge from vault
- `GET /ai/payments/:id` — payment detail (policy-scoped when Web4 enforcement is enabled)
- `GET /x402/resource` — x402-style paywalled resource

Protected accountability / forensics actions on the same gateway:

- `POST /ai/actions/run` with `action: "ai.trace.report"` — protected trace
  summary for an address, lot, or transaction target
- `POST /ai/actions/run` with `action: "ai.forensics.case.create"` — create a
  protected structured case from trace evidence
- `POST /ai/actions/run` with `action: "ai.forensics.case.review"` — append
  review notes or move case review/escalation state
- `GET /ai/forensics/cases?policy_id=...` — list policy-scoped cases
- `GET /ai/forensics/cases/:case_id?policy_id=...` — fetch one policy-scoped
  case

The forensics layer is defensive and evidence-oriented:

- it supports accountability, victim support, and operator/compliance review
- it does not grant transfer, seizure, or freeze authority by itself
- any stronger enforcement decision must go through a separate reviewed path

Architecture decision:

- this is the adopted V2 accountability / forensics strategy for YNX
- it extends the existing lot-lineage evidence layer instead of replacing it
- it should not be described as a permanent per-unit serial-number model for
  fungible assets
- stable provenance comes from lot anchors such as `issuance_id` and optional
  `deposit_batch_id`, plus exact/proportional lineage depending on whether
  merges or splits occurred

Current protected case-create request shape accepts:

- `policy_id`
- `kind`
- `target`
- optional `direction`
- optional `max_depth` or `maxDepth`
- optional `denom`
- optional `min_amount` or `minAmount`
- optional `min_tainted_amount` or `minTaintedAmount`
- optional `since_height` or `sinceHeight`
- optional `until_height` or `untilHeight`

Current protected case output includes:

- flow graph traversal
- comparative taint models
- entity attribution
- address clustering
- suspicious pattern detection
- evidence chain
- risk scoring
- dossier/action-queue output
- provenance anchors

Current persistence/runtime behavior:

- protected forensics cases persist in the AI gateway data store alongside jobs,
  vaults, payments, and audit logs
- case review state and review logs survive gateway restart
- `GET /health` and `GET /ready` expose persistence metadata plus aggregated
  forensic-case counts by review and escalation state for easier operator
  verification

## 6. Optional On-chain Mirroring

The AI Gateway can mirror high-value settlement actions into `YNXAISettlement`.
This is disabled by default for backward compatibility and can be enabled with:

```text
AI_ONCHAIN_ENABLED=1
AI_ONCHAIN_RPC_URL=https://evm.ynxweb4.com
AI_SETTLEMENT_CONTRACT=0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf
AI_ONCHAIN_PRIVATE_KEY=<runtime-only signer key>
AI_ONCHAIN_CONFIRMATIONS=1
```

Never commit `AI_ONCHAIN_PRIVATE_KEY`. The gateway signer becomes the on-chain
vault owner for mirrored vaults.

### 6.1 Create an on-chain-backed vault

```bash
curl -s https://ai.ynxweb4.com/ai/vaults \
  -H 'content-type: application/json' \
  -H "x-ynx-session: $SESSION" \
  -d '{
    "owner": "demo-owner",
    "policy_id": "policy_demo",
    "max_per_payment": 50,
    "onchain": true,
    "onchain_value_wei": "0",
    "onchain_max_per_payment_wei": "50000000000000000"
  }' | jq
```

Security note:

- vault creation is expected to create an empty vault
- funding should happen through `POST /ai/vaults/:id/deposit`
- direct positive `balance` bootstrap on create is disabled by default so local
  machine-payment balance cannot be injected by request body alone
- local deposit-based balance increases are also disabled by default unless you
  explicitly enable a dev/demo path such as `AI_ALLOW_LOCAL_VAULT_DEPOSITS=1`
- production funding should come from a verified deposit path, not from a bare
  request body that increments local accounting

When enabled, the response includes:

```json
{
  "vault": {
    "onchain": {
      "contract": "0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf",
      "vault_id": "0x...",
      "policy_hash": "0x...",
      "tx_hash": "0x..."
    }
  }
}
```

### 6.2 Create an on-chain-backed AI job

```bash
curl -s https://ai.ynxweb4.com/ai/jobs \
  -H 'content-type: application/json' \
  -H "x-ynx-session: $SESSION" \
  -d '{
    "creator": "demo-owner",
    "policy_id": "policy_demo",
    "vault_id": "vault_demo",
    "reward": "42",
    "reward_wei": "42000000000000000",
    "input_uri": "ipfs://task",
    "challenge_window_blocks": 0,
    "onchain": true
  }' | jq
```

If the vault is on-chain-backed, later `commit`, `challenge`, and `finalize`
actions are mirrored to the contract and their transaction hashes are written
back under `job.onchain`.

## 7. Security Requirements

- Every state transition MUST be authorized by signer address.
- Challenge windows MUST be explicit and time-bounded.
- Reward release MUST happen only after finalization.
- Slash decisions MUST be reproducible from on-chain data.
- Vault spend MUST be bounded by per-payment and per-day limits.
- x402-style endpoints MUST return deterministic payment requirements when unpaid.
- Settlement actions MUST be audit-recorded.
- On-chain mode MUST run with a dedicated limited signer, not a human treasury key.
- LLM mode MUST not receive private keys, faucet secrets, validator keys, or bridge signer material.
- Intelligence answers MUST clearly distinguish deployed testnet contracts/routes from production liquidity or external mainnet custody.

## 8. Rollout Policy

- v2 public testnet uses this API as integration contract.
- Breaking changes MUST increment version and include migration notes.
- Gateway-only settlement remains supported for low-risk demos.
- On-chain mirroring should be used for high-value or externally inspectable agent work.
