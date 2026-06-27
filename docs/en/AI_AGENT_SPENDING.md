# AI Agent Spending on YNX

Status: active  
Last updated: 2026-06-27

## 1. Core idea

YNX treats AI agent spending as a bounded execution problem, not as unlimited
wallet authority.

The control order is:

1. owner
2. policy
3. session
4. payment or card authorization attempt

## 2. Current forms

YNX currently has two spending-control shapes:

- AI settlement vault flows
- YNX Card Mock authorization flows

Vaults are strongest for machine-payment budgeting and AI job settlement.
YNX Card Mock is strongest for future card-like spend control and audit logic.

## 3. What is enforced

Current bounded-spending controls can include:

- allowed action types
- session TTL
- max ops
- session max spend
- policy max daily spend
- policy max total spend
- card per-txn, daily, and total limits
- merchant / MCC / country filters
- agent allowlists

## 4. Why this matters

The goal is not “let an agent hold a hot wallet and hope for the best.”

The goal is:

- explicit limits
- explicit approvals or declines
- clear audit trail
- future provider compatibility

## 5. Current boundary

This is not yet:

- full production custody
- live bank-card issuance
- unrestricted autonomous spending

It is a controlled spending and audit foundation that can later be connected to
real providers under legal and operational controls.
