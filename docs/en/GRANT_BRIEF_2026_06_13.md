# YNX Web4 Public Testnet Grant Brief

## Project

YNX Web4 Public Testnet is a live testnet for protected AI-driven onchain execution, cross-chain test-asset routing, and Web4 session-policy authorization.

Current support boundary:

- YNX is still a project, not a publicly announced legal operating entity;
- this brief is therefore optimized for grants, sponsorships, and other
  project-stage infrastructure support.

## Problem

AI agents can trigger onchain and cross-system actions faster than human operators can review them. Without policy-bound execution, session controls, and testnet-grade routing infrastructure, teams are forced to choose between automation and safety.

## Solution

YNX combines:

- Web4 session authorization for agent actions
- policy-protected `trade.execute`
- AI preflight and settlement flows
- public testnet bridge routing across multiple ecosystems
- observable readiness and health surfaces for operators and builders

## Live Evidence As Of June 13, 2026

- public website live at `https://www.ynxweb4.com`
- protected network status API live at `https://www.ynxweb4.com/api/network/status`
- core public services live:
  - RPC
  - EVM RPC
  - REST
  - gRPC
  - faucet
  - indexer
  - explorer
  - AI gateway
  - Web4 hub
- validator set restored to 4 bonded validators on the live public testnet
- public acceptance gates green on the current public-testnet environment:
  - `public_security_gate`: `PASS=66 WARN=0 FAIL=0`
  - `public_testnet_extreme_readiness`: `PASS=41 WARN=0 FAIL=0`
  - `public_bridge_full_loop_probe`: `PASS=58 WARN=2 FAIL=0`
  - `public_ai_onchain_settlement_probe`: `PASS=16 FAIL=0`
  - `public_uptime_slo_probe`: passed

## Public Wording

Use this wording consistently:

`YNX Web4 public testnet is live. We currently have 4/5 bridge routes deposit-tested, 5/5 routes with some form of public release proof, and 2/5 routes that are fully automatic on the current public-testnet adapter path. Sepolia ETH and USDC still remain signer-gated for automatic release, and BNB still remains blocked by the missing BSC lockbox from counting as deposit-tested or automatic-ready. The bridge should still be described as testnet-scope readiness work, not production-safe bridge capacity.`

## Why Funding Helps Now

The architecture is already live on public testnet. The next bottlenecks are
operational hardening, documentation publication, and adapter completion, not
concept validation.

Funding would accelerate:

- Sepolia release-signer completion and BSC lockbox completion
- production monitoring and incident automation
- validator and infra redundancy
- external security review and audit preparation
- developer docs and builder onboarding
- legal, privacy, and company-readiness implementation

What this brief does not imply:

- not a claim that YNX is already equity-ready as a standard operating company;
- not a claim that custody, regulated trading, or audited production controls
  are already live.

## 30 / 60 / 90 Day Use Of Funds

### 30 days

- finish production-critical adapter and operator blockers that improve
  developer usability and reliability
- stabilize route automation evidence and dashboards
- publish updated builder walkthroughs

### 60 days

- expand policy templates for agent execution
- improve operator tooling and route observability
- add external validator onboarding support

### 90 days

- complete audit-oriented hardening pass
- broaden ecosystem integrations
- prepare a stronger mainnet-readiness evidence packet

## Best-Fit Grant Targets

- Ethereum Foundation Ecosystem Support Program: open infra, safe agent execution, testnet automation
- Base funding programs: builder-facing agent execution demo and ecosystem compatibility
- Gitcoin Grants: public-goods infra, open docs, testnet tooling, AI action safety layer

## Scope Discipline

YNX should not depend on BNB Chain or BSC-specific support to justify funding.
The BSC/BNB route can remain optional technical backlog, but the primary grant
story should stand on Web4 policy enforcement, AI settlement, public
infrastructure, and operator-grade testnet tooling.
