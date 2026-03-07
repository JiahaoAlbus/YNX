# YNX v2 Company Handoff

Status: Active  
Last updated: 2026-03-07  
Canonical language: English

## 1. Purpose

This document defines the local deliverable set that is expected before YNX v2 moves into company-operated public testnet rollout.

## 2. Canonical Package

The company-ready package is built with:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_company_pack.sh
```

The package contains:

- bootstrap release artifacts,
- canonical English specifications,
- operator runbooks,
- OpenAPI contracts,
- environment template,
- local and remote orchestration entrypoints.

## 3. Canonical Language Policy

- Canonical specifications and operator runbooks are English-first.
- Supplemental Chinese documents may exist for operator convenience.
- External validator and developer-facing references should point to the English set first.

## 4. Required Operational Entry Points

- `v2_local_complete.sh` — local completion flow
- `v2_local_compose.sh` — Docker Compose local stack
- `v2_testnet_multinode.sh` — local validator scale simulation
- `v2_public_testnet_deploy.sh` — remote deployment entry
- `v2_validator_bootstrap.sh` — external validator bootstrap

## 5. Required Public Surfaces

- CometBFT RPC
- EVM JSON-RPC
- REST
- Faucet
- Indexer
- Explorer
- AI Gateway
- Web4 Hub

## 6. Required Documentation Set

- protocol specification,
- execution plan,
- AI settlement API,
- Web4 API,
- public testnet playbook,
- local runbook,
- security model,
- file/function map.

## 7. Exit Condition for “Local Complete”

YNX v2 is considered locally complete for company handoff when:

- a single command can bootstrap the stack locally,
- a single command can package the release artifacts,
- a single command can generate the company handoff bundle,
- a multi-validator local simulation path exists,
- API contracts and operator documentation are committed.
