# On-chain Governance & Treasury (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Normative Language

Normative keywords are per RFC 2119.

## 1. Governance Scope

YNX governance MUST control:

- Protocol upgrades (system contracts and core parameters)
- Parameter changes (fees, inflation, consensus parameters when applicable)
- Treasury spending (budgets, grants, security funding)

## 2. Voting Power (v0)

Voting power SHOULD be stake-weighted.

- One staked NYXT SHOULD equal one unit of voting power.
- Delegators SHOULD be able to vote directly; otherwise their voting power defaults to their validator’s vote (TBD).

## 3. Proposal Requirements

### 3.1 Proposer Stake

To submit a proposal, the proposer MUST have at least **1,000,000 NYXT** staked (bonded).

### 3.2 Proposal Deposit (anti-spam)

- Proposals MUST include a **100,000 NYXT** deposit.
- The deposit MUST remain locked until the vote concludes.
- If a proposal hits a “veto” threshold (see below), part or all of the deposit SHOULD be slashed; otherwise it SHOULD be returned.

## 4. Voting Timeline

- Voting period MUST be **7 days**.
- If a proposal passes, it MUST enter a timelock queue of **7 days** before execution.
- Execution MUST be on-chain (governance-controlled execution payload).

## 5. Pass/Fail Rules (v0 defaults)

To make v0 actionable, governance MUST define pass/fail thresholds. Defaults (adjustable by governance later):

- **Quorum**: at least **10%** of total active voting power MUST participate (excluding abstain).
- **Threshold**: proposals pass if **YES > 50%** of (YES + NO) votes.
- **Veto**: if **NO_WITH_VETO ≥ 33.4%** of total votes cast, the proposal fails and deposit is slashed per rules.

> Rationale: these defaults are widely used patterns in PoS governance. Parameter tuning can be done later, but v0 needs concrete thresholds.

## 6. Treasury Controls

- Treasury inflows MUST include the locked v0 shares from inflation and fees (see tokenomics).
- Treasury outflows MUST be executed only via governance proposals and timelocked execution.
- The system MUST provide transparent accounting for every treasury transfer (reason, recipient, amount, proposal reference).

## 7. Security Notes

Governance MUST be protected against:

- Low-participation capture (quorum)
- Malicious proposals (veto + deposit slashing + timelock)
- Fast-drain attacks (timelock and spend limits — TBD)

## 8. EVM-native execution (v0 reference)

YNX ships v0 EVM “system contracts” (Governor + Timelock + Treasury) and a chain-specific protocol precompile bridge.

- The canonical execution path for governance actions SHOULD be:
  - `YNXGovernor` proposal → `YNXTimelock` queue → on-chain execution.
- Protocol parameter changes (fee/inflation splits) are exposed to the EVM via:
  - `IYNXProtocol` precompile at `0x0000000000000000000000000000000000000810`
  - `updateParams(...)` MUST only be callable by the timelock (enforced by `msg.sender`).

See `docs/en/Protocol_Precompile_v0.md`.

## 9. Local development notes

For fast iteration on a local single-node devnet, `chain/scripts/localnet.sh` supports a dev-only mode that reduces the
voting period and timelock delay. See `docs/en/CHAIN_DEVNET.md`.
