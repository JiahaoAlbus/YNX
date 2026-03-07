# YNX v2 Security Model

Status: Active  
Last updated: 2026-03-07  
Canonical language: English

## 1. Security Priority

YNX v2 keeps Web3 sovereignty above Web4 autonomy.

Control order:

1. `owner`
2. `policy`
3. `session`
4. `agent action`

This is the non-negotiable control boundary for public testnet and future mainnet.

## 2. Identity and Key Boundary

- Root owner authority MUST remain external to delegated agent execution.
- Session credentials MUST be short-lived and bounded.
- Repository artifacts MUST NOT contain committed secrets, mnemonics, or private keys.
- Runtime key directories MUST stay outside Git-tracked configuration.

## 3. Policy Enforcement Boundary

Policies are the hard boundary between human/operator intent and autonomous execution.

Each policy may define:

- `max_total_spend`
- `max_daily_spend`
- `max_children`
- `replicate_cooldown_sec`
- capability allowlists

Owner authority may:

- pause a policy,
- resume a policy,
- revoke a policy,
- invalidate all dependent sessions.

## 4. Session Boundary

Sessions are delegated execution envelopes.

Each session must be bounded by:

- TTL
- operation count
- spend ceiling
- explicit capabilities

If a session exceeds its limits, execution must fail closed.

## 5. Agent Mutation Boundary

Self-update and replication are constrained features, not unrestricted code execution.

- Self-update is limited to allowlisted mutable fields.
- Replication is rate-limited and child-count-limited.
- Replication remains attributable to the parent policy and owner.
- Every mutation is audit-visible.

## 6. Machine Payment Boundary

Machine-payment flows use vaults rather than unlimited hot-wallet authority.

Vault controls:

- current balance
- max daily spend
- max per payment
- policy linkage

x402-style access is valid only after a tracked payment reference is accepted.

## 7. Public Testnet Operator Security

Before server rollout:

- local bootstrap must be reproducible,
- release bundle must be packable,
- OpenAPI contracts must exist for public services,
- watchdog and observability scripts must be present,
- ports and service topology must be explicit.

## 8. Mainnet Carry-Forward Rules

The public-testnet stack may move to mainnet candidate only if:

- no placeholder secrets remain,
- policy/session boundaries stay mandatory,
- release artifacts are reproducible,
- validator onboarding is deterministic,
- observability and incident handling are documented.
