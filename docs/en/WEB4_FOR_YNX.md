# What Web4 Means in YNX v2

Status: Active  
Last updated: 2026-02-25

## 1. Definition Used by YNX

In YNX v2, **Web4** means:

- AI agents as first-class network participants
- user intent-driven interaction (not only manual wallet clicks)
- decentralized settlement and governance for AI-native applications
- persistent on-chain accountability for autonomous actions
- sovereignty-preserving autonomy (`owner > policy > session key`)

## 2. Four Core Mechanisms Implemented in v2 Track

1. **Wallet as identity**
   - `/web4/wallet/bootstrap`
   - `/web4/wallet/verify`
   - wallet bootstrap is auditable and linked to policy/session controls

2. **Autonomous continuation with bounded resources**
   - policy-level spend ceilings (`max_total_spend`, `max_daily_spend`)
   - session-level operation and spend ceilings (`max_ops`, `max_spend`)
   - owner pause/resume/revoke for hard stop

3. **Machine payment rails**
   - vault primitives: `/ai/vaults*`
   - programmable charge flow: `/ai/payments/charge`
   - x402-style paywall surface: `/x402/resource`

4. **Controlled self-modification and replication**
   - self-update: `/web4/agents/:id/self-update` (allowlisted fields)
   - replication: `/web4/agents/:id/replicate` with policy limits (`max_children`, cooldown)
   - complete action trail via `/web4/audit`

## 3. Web4 Primitives in YNX

- Identity primitive: agent/operator identity registry
- Agent primitive: capability-declared AI service endpoints
- Intent primitive: user/application intent objects
- Claim primitive: machine-execution claims with hashes/proofs
- Challenge primitive: dispute period before settlement
- Finalization primitive: deterministic payout/slash resolution

## 4. Why This Is Different from “Web3 + AI UI”

YNX v2 treats AI coordination and settlement as protocol-level workflows instead of only off-chain app logic.

## 5. Public API Surface

- AI settlement gateway: `/ai/*`
- Web4 coordination hub: `/web4/*`
- Chain and governance metadata: `/ynx/overview`
