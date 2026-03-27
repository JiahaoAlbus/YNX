# YNX Audit Scope (Q1 2026)

Status: draft
Owner: Huangjiahao
Last Updated: 2026-03-27

## In Scope (Priority)

1. `chain/` core execution and authorization paths
2. `contracts/` critical contracts (token, staking, governance-related contracts)
3. Dual execution consistency checks (Cosmos/EVM surface)
4. Permission chain and delegation paths (`owner > policy > session > agent action`)

## Out of Scope (Current Phase)

1. Marketing/website frontend content pages
2. Non-critical tooling and scripts not touching security-sensitive execution paths
3. Compliance-only process docs (SOC 2 / ISO controls)

## Audit Objectives

- Identify high/critical vulnerabilities before mainnet decisions
- Validate access-control and privilege boundaries
- Validate asset safety in transfer/staking/state transitions
- Validate cross-surface consistency assumptions

## Requested Deliverables

- Written audit report with severity ranking
- Repro steps and remediation guidance
- Re-test confirmation for fixed findings
- Executive summary suitable for partner/investor sharing
