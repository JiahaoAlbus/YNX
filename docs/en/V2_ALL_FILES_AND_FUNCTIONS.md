# YNX v2 Public Testnet - Files and Functions

Status: Active  
Last updated: 2026-03-07

## 1. Chain Scripts (`/chain/scripts`)

- `v2_testnet_bootstrap.sh`  
  Initializes v2 chain home, applies base config/profile.
- `v2_services_start.sh`  
  Starts local v2 stack (`ynxd`, faucet, indexer, explorer, ai-gateway, web4-hub).
- `v2_services_stop.sh`  
  Stops local v2 stack.
- `v2_public_testnet_verify.sh`  
  Read-path verification for chain + infra endpoints.
- `v2_public_testnet_smoke.sh`  
  Write-path smoke for Web4 + AI settlement + x402 flow.
- `v2_public_testnet_deploy.sh`  
  Remote deploy script (for later server migration).
- `install_v2_stack_systemd.sh`  
  Installs all v2 services as systemd units.
- `v2_testnet_release.sh`  
  Packs operator release artifacts (`ynxd`, `genesis/config/app`, descriptor, bootstrap scripts, role profiles, checksums).
- `v2_validator_bootstrap.sh`  
  One-command external node bootstrap from descriptor, bundle, or live RPC.
- `v2_role_apply.sh`  
  Applies canonical node role profile (`validator`, `full-node`, `public-rpc`).
- `v2_testnet_watchdog.sh`  
  v2 watchdog wrapper.
- `install_v2_watchdog_systemd.sh`  
  Installs v2 watchdog service with auto-restart.
- `v2_profile_apply.sh`  
  Applies consensus profile (`web4-fast-regional` / `web4-global-stable`).
- `v2_testnet_multinode.sh`  
  Local multi-validator simulation wrapper for v2.
- `v2_local_complete.sh`  
  One command entry for local completion workflow (`up/compose-up/verify/smoke/pack/company-pack/all`).
- `v2_local_compose.sh`
  Docker Compose orchestration for a full local v2 stack.
- `v2_ports_apply.sh`
  Applies the canonical v2 service ports to a local home directory.
- `v2_company_pack.sh`
  Builds the company-ready local handoff bundle.

## 2. Infra Services (`/infra`)

### AI Gateway (`/infra/ai-gateway`)
- `server.js`
  - AI jobs lifecycle
  - vault budget model
  - programmable charge
  - x402-style `402 -> pay -> access` endpoint

### Web4 Hub (`/infra/web4-hub`)
- `server.js`
  - wallet bootstrap/verify
  - policy/session authorization plane
  - identities/agents/intents
  - controlled self-update/replication
  - audit trail

### Indexer (`/infra/indexer/server.js`)
- Aggregates chain status and serves `/ynx/overview`, including Web4/AI capability flags.
- Also serves `/ynx/network-descriptor` for generic operator bootstrap metadata.

### Faucet (`/infra/faucet/server.js`)
- Controlled token dispenser with rate limiting and keyring-dir support.

### Explorer (`/infra/explorer/public/*`)
- UI rendering of chain status, validators, and overview metadata.

## 3. Core v2 Docs (`/docs/en`)

- `YNX_v2_WEB4_SPEC.md` — protocol-level v2 Web4 spec.
- `YNX_v2_AI_SETTLEMENT_API.md` — AI settlement and machine payment API contract.
- `YNX_v2_WEB4_API.md` — Web4 API endpoint reference.
- `V2_PUBLIC_TESTNET_PLAYBOOK.md` — operator deployment and operations.
- `V2_VALIDATOR_BOOTSTRAP.md` — validator join quickstart.
- `V2_SMOKE_AND_VERIFY.md` — verification and smoke workflows.
- `YNX_v2_EXECUTION_PLAN.md` — delivery workstreams and milestones.
- `WEB4_FOR_YNX.md` — Web4 interpretation in YNX.
- `V2_SECURITY_MODEL.md` — enforced owner/policy/session/vault boundaries.
- `V2_COMPANY_HANDOFF.md` — local-complete to company-rollout handoff set.

## 4. Chinese Docs (`/docs/zh`)

- `V2_公开测试网手册.md`
- `YNX_v2_WEB4_蓝图.md`
- `WEB4_在YNX中的定义.md`
- `YNX_v2_WEB4_API_接口说明.md`
- `V2_全部文件与功能说明.md`

## 5. OpenAPI Contracts (`/infra/openapi`)

- `ynx-v2-ai.yaml` — machine-readable AI settlement API contract.
- `ynx-v2-web4.yaml` — machine-readable Web4 API contract.
