# YNX Diligence Consistency Audit

Status: active audit note  
Last updated: 2026-06-14  
Canonical language: English

## Purpose

This note records the most important consistency checks that a skeptical
investor is likely to perform across README, public docs, and live endpoints.

## 1. Bridge Readiness Terminology

Live endpoint checked on June 14, 2026:

- `GET https://rpc.ynxweb4.com/bridge/route-readiness`

Observed summary:

- `full_loop_tested = 5/5`
- `automatic_loop_ready = 4/5`

Required wording discipline:

- `automatic_loop_ready` means configuration and adapter readiness;
- strongest publicly observed automation evidence today is still concentrated on
  the Sepolia ETH and USDC routes;
- do not collapse readiness into production safety.

## 2. Validator Language

The strict public-testnet readiness gate proves:

- service availability;
- live validator set size;
- signing continuity;
- basic topology redundancy.

It does not prove:

- strong validator independence;
- production decentralization;
- governance neutrality across independent operators.

Therefore investor-facing material should use "public-testnet validator set live"
or "topology redundancy present", not broad decentralization claims.

## 3. Website Legal Disclosure Gap

Observed on June 14, 2026:

- `https://www.ynxweb4.com/privacy` returns the website shell
- `https://www.ynxweb4.com/terms` returns the website shell

Conclusion:

- legal content drafts exist in the repository;
- publication to standalone website routes remains an open blocker.

## 4. Token Policy Separation

Repository history still contains older v0 tokenomics drafts. Those drafts
should not be presented as the current financing term sheet.

Current financing-safe position:

- no founder-fee commitment should be assumed;
- future default founder fee policy should remain `0 bps` unless separately
  disclosed and approved;
- infrastructure revenue should be the underwriting story, not token extraction.

## 5. Practical Conclusion

YNX is already beyond concept stage, but investor confidence depends on keeping
three things aligned at all times:

1. live endpoint truth;
2. written diligence materials;
3. website-visible disclosure pages.
