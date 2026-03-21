# YNXWEB4 Release Notes

Release name: `ynxweb4`  
Track: `v2-web4`  
Status: public testnet active  
Release date: 2026-03-21

## 1) What this release is

`ynxweb4` is the consolidated Web4 public-testnet release for YNX.

It packages one coherent operator/runtime baseline:

- EVM-first chain runtime (`ynxd`) for `ynx_9102-1`
- AI settlement surface (`/ai/*`)
- Web4 sovereignty surface (`/web4/*`)
- Public service stack (`faucet`, `indexer`, `explorer`)
- Validator onboarding and consensus onboarding scripts
- Public join documentation (EN/ZH)

## 2) Network profile in this release

- Cosmos Chain ID: `ynx_9102-1`
- EVM Chain ID: `0x238e` (`9102`)
- Denom: `anyxt`
- Track label: `v2-web4`
- Sovereignty order: `owner > policy > session key > agent action`

## 3) Public endpoints (HTTPS)

- RPC: `https://rpc.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- EVM WS: `https://evm-ws.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`

## 4) Major capabilities delivered

### A. Chain + execution baseline

- Public chain runtime with EVM JSON-RPC enabled
- Minimum gas price profile for stable public-testnet operations
- Open validator model with chain-level staking and governance

### B. Web4 sovereignty primitives

- Owner / policy / session identity-control model
- Policy-bounded delegation and session-limited execution
- Agent-oriented control plane over `/web4/*`

### C. AI settlement primitives

- Intent lifecycle support (create/claim/challenge/finalize paths)
- Vault-oriented machine payment flow
- x402-style paid resource flow for machine-to-service payments

### D. Public operator stack

- Faucet service for test-token distribution
- Indexer service with machine-readable overview/status APIs
- Explorer service for blocks, validators, and tx visibility
- AI/Web4 gateway services for v2 surfaces

### E. Operations and reliability

- One-command deploy and verify scripts
- Public smoke tests for write-path and API-path verification
- Systemd stack wiring for node/service lifecycle consistency
- Watchdog support for validator operations

## 5) Repository map (Web4-relevant)

- `chain/`
  - `cmd/ynxd`: chain binary entry
  - `scripts/v2_public_testnet_deploy.sh`: remote deploy
  - `scripts/v2_public_testnet_verify.sh`: operator verification
  - `scripts/v2_public_testnet_smoke.sh`: write-path smoke
  - `scripts/v2_validator_bootstrap.sh`: public validator bootstrap
  - `scripts/install_v2_stack_systemd.sh`: stack systemd install
- `infra/`
  - `faucet/`, `indexer/`, `explorer/`, `ai-gateway/`, `web4-hub/`
  - `openapi/ynx-v2-ai.yaml`, `openapi/ynx-v2-web4.yaml`
- `docs/en/`, `docs/zh/`
  - public join guides and v2 Web4 specs/APIs

## 6) External docs for onboarding

- EN public testnet join: `docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md`
- EN validator node guide (non-consensus): `docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`
- EN consensus validator guide (BONDED): `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`
- ZH public testnet join: `docs/zh/V2_公开测试网加入手册.md`
- ZH validator node guide (non-consensus): `docs/zh/V2_验证节点加入手册.md`
- ZH consensus validator guide (BONDED): `docs/zh/V2_共识验证人加入手册.md`
- EN docs index: `docs/en/INDEX.md`
- ZH docs index: `docs/zh/INDEX.md`

## 7) Compatibility and migration notes

- This release baseline is `v2-web4`; public docs should prioritize v2 pages.
- Legacy `v0` docs remain in repository for historical reference, not for default website navigation.
- Public websites should avoid raw `http://IP:PORT` calls from HTTPS pages.

## 8) Validation checklist for this release

Run all checks before public announcement:

1. `v2_public_testnet_verify.sh` passes
2. `v2_public_testnet_smoke.sh` passes
3. `indexer /ynx/overview` returns `track=v2-web4`
4. Explorer loads and updates latest heights
5. Faucet `/health` is green and POST path sends test tokens
6. At least 2 validators are in `BOND_STATUS_BONDED`

## 9) Known constraints (current public testnet)

- Public testnet remains an experimental network; resets or parameter tuning may occur.
- Production economic assumptions (mainnet token economics/risk controls) are not final in this release.
- Users must treat all testnet assets as non-production assets.

## 10) Summary

`ynxweb4` is the first fully consolidated YNX Web4 public-testnet baseline: chain runtime + AI/Web4 primitives + public service stack + validator onboarding + public docs in one release line.
