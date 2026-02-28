# YNX v2 AI Settlement API (Draft)

Status: Draft  
Last updated: 2026-02-25

## 1. Purpose

This document defines the first public API surface for the YNX v2 AI settlement workflow.

The API is designed for:

- AI task publishers
- AI worker operators
- verifiers/challengers
- indexers and explorers

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

## 5. Security Requirements

- Every state transition MUST be authorized by signer address.
- Challenge windows MUST be explicit and time-bounded.
- Reward release MUST happen only after finalization.
- Slash decisions MUST be reproducible from on-chain data.
- Vault spend MUST be bounded by per-payment and per-day limits.
- x402-style endpoints MUST return deterministic payment requirements when unpaid.
- Settlement actions MUST be audit-recorded.

## 6. Rollout Policy

- v2 public testnet uses this API as integration contract.
- Breaking changes MUST increment version and include migration notes.
