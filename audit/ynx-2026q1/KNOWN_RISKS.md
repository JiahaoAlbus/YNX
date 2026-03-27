# YNX Known Risk Focus Areas

Status: draft
Owner: Huangjiahao
Last Updated: 2026-03-27

## Top Risk Areas

1. Authorization and delegation chain correctness
2. Asset safety across transfer/staking-related state transitions
3. Consistency between Cosmos-side and EVM-side execution assumptions
4. Privilege escalation or bypass in policy/session constrained flows
5. Settlement path correctness for AI/Web4 execution interfaces

## Explicit Non-Goals for Phase 1

- Full compliance attestation readiness (SOC 2 / ISO)
- Non-security UI/UX issues

## What We Most Want Auditors to Challenge

- Incorrect authorization checks under edge-case session states
- Unsafe state transition ordering that could lead to fund loss
- Replay/double-execution assumptions across execution surfaces
- Any path where delegated actors can exceed policy limits
