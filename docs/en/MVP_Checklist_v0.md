# Baseline L1 Capability Checklist (v0)

Status: Draft  
Last updated: 2026-02-09  
Canonical language: English

YNX must match the baseline capabilities of a “normal chain” before the differentiated order modules can succeed.

## A. Base Chain

- P2P networking and node roles (full node / validator / archive)
- Reproducible genesis and network parameterization (devnet/testnet)
- Consensus finality implementation + performance plan
- State sync and snapshots (reasonable catch-up time)
- Mempool and anti-spam controls (fee policy, rate limits, DoS mitigation)

## B. Accounts & Assets

- EVM-compatible account model and signature verification
- NYXT native token, staking, and vesting contracts
- Standard contract interfaces (ERC-20/721/1155 as needed by ecosystem)

## C. Execution & Fees

- EVM execution, logs/events, deployment and call support
- Gas accounting and fee split enforcement (burn/validators/treasury)
- Extension point for stake-to-fee credits (optional future)

## D. Staking & Validators

- Validator onboarding, minimum self-bond, delegation and unbonding
- Rewards distribution (inflation + fee shares)
- Slashing for equivocation and safety violations, plus clear rules

## E. Developer UX

- JSON-RPC + WebSocket subscriptions (main tooling compatibility)
- Explorer for blocks/tx/contracts/events/governance/treasury
- Testnet faucet, deployment templates, SDKs and examples
- Dual address format support (`0x...` and `YN...`)

## F. Governance & Treasury

- Full on-chain governance v0
- Treasury accounting and governance-controlled outflows
- Budgeting workflows to reduce governance fatigue

## G. Security & Operations

- Monitoring/alerting, incident response plan
- Audits and bug bounty before mainnet
- Governance guardrails (timelocks, veto, emergency policies)

## H. Scaling & Cross-domain (optional in v0)

- One official reference scaling/execution domain
- Clear security boundary for bridges and cross-domain messaging

