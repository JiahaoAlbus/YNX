# Roadmap (v0)

Status: Draft  
Last updated: 2026-02-09  
Canonical language: English

## Principle

“Build everything” is possible only if we respect dependency order:

1) Base chain stability  
2) On-chain governance + treasury  
3) Order modules (identity/org/arbitration)  
4) Scaling layers and broader ecosystem

## Phase 1 — Devnet (Base Chain MVP)

- EVM execution + gas accounting
- PoS validator lifecycle, delegation, rewards, slashing (baseline)
- Preconfirm prototype (≤ 1s UX target direction)
- Finality prototype (5–8s target direction)
- Minimal JSON-RPC, indexer, explorer
- NYXT basic token, staking interfaces

## Phase 2 — Public Testnet

- On-chain governance v0: proposals, voting, timelock, execution
- Treasury flows live (inflation + fee shares)
- Dual address format support in SDK/explorer/UI
- Security review, monitoring, incident runbooks (baseline)

## Phase 3 — Mainnet

- Hardened operations, audits, bug bounties
- Decentralization plan for preconfirm path (progressively permissionless)
- Ship one official scaling/execution domain reference implementation

## Phase 4 — “Order-State” Modules

Ship in this dependency order (parallel teams are OK):

1) Treasury & budget system (continuous improvements)
2) Subject registry + organizations/roles
3) Arbitration framework (opt-in hooks, appeal window, execution hooks)

