# YNX v2 AI Settlement API (Draft)

Status: Active public-testnet API  
Last updated: 2026-06-06

## 1. Purpose

This document defines the first public API surface for the YNX v2 AI settlement workflow.

The API is designed for:

- AI task publishers
- AI worker operators
- verifiers/challengers
- indexers and explorers

The public testnet has two settlement layers:

- API layer: `https://ai.ynxweb4.com`
- On-chain rail: `YNXAISettlement` at `0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf`

Current public-testnet health:

```text
AI Gateway: https://ai.ynxweb4.com/health
Ready:      https://ai.ynxweb4.com/ready
On-chain:   enabled and ready
Jobs:       7 total, 5 finalized
Vaults:     6 total
Payments:   7 total
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

## 4. Suggested Endpoints

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
- `GET /x402/resource` — x402-style paywalled resource

## 5. Optional On-chain Mirroring

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

### 5.1 Create an on-chain-backed vault

```bash
curl -s https://ai.ynxweb4.com/ai/vaults \
  -H 'content-type: application/json' \
  -H "x-ynx-session: $SESSION" \
  -d '{
    "owner": "demo-owner",
    "policy_id": "policy_demo",
    "balance": 0,
    "max_per_payment": 50,
    "onchain": true,
    "onchain_value_wei": "100000000000000000",
    "onchain_max_per_payment_wei": "50000000000000000"
  }' | jq
```

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

### 5.2 Create an on-chain-backed AI job

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

## 6. Security Requirements

- Every state transition MUST be authorized by signer address.
- Challenge windows MUST be explicit and time-bounded.
- Reward release MUST happen only after finalization.
- Slash decisions MUST be reproducible from on-chain data.
- Vault spend MUST be bounded by per-payment and per-day limits.
- x402-style endpoints MUST return deterministic payment requirements when unpaid.
- Settlement actions MUST be audit-recorded.
- On-chain mode MUST run with a dedicated limited signer, not a human treasury key.

## 7. Rollout Policy

- v2 public testnet uses this API as integration contract.
- Breaking changes MUST increment version and include migration notes.
- Gateway-only settlement remains supported for low-risk demos.
- On-chain mirroring should be used for high-value or externally inspectable agent work.
