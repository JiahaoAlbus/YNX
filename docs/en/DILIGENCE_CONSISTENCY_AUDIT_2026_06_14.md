# YNX Diligence Consistency Audit

Status: active audit note  
Last updated: 2026-06-14  
Canonical language: English

## Purpose

This note records the most important consistency checks that a skeptical
investor is likely to perform across README, public docs, and live endpoints.

## Canonical Terminology Table

| Term | Strongest evidence today | Must not be described as | Remaining gate |
|---|---|---|---|
| `live` | public HTTPS endpoints and public-testnet services respond | mainnet, institution-ready, or audited production | keep runtime evidence and docs aligned |
| `public testnet` | chain `ynx_9102-1`, public endpoints, public operator workflows | commercial production network | validator, audit, legal, and DR gates |
| `tradable` | only limited public-testnet swap/testing flows where assets, liquidity, and route behavior are actually observable | general availability of real external assets | liquidity, risk controls, legal sign-off |
| `wrapped asset` | public-testnet representation minted on YNX from documented testnet route logic | licensed custody or redeemable mainnet claim | production custody, redemption, monitoring, legal review |
| `full_loop_tested` | operator-attested testnet deposit, mint, burn, and release proof chain exists | automatic or scale-proven production safety | repeated automation evidence and audit |
| `automatic_loop_ready` | route config, watchers, signer path, and adapters are configured | repeated public automation proof or production-safe bridge | observed automation and incident controls |
| `production` | not yet applicable as a network-wide claim | synonym for current public testnet | audit, reliability, persistence, legal, governance |
| `mainnet-candidate` | not yet applicable as of this audit | any currently live public-testnet state | readiness gates in full |
| `decentralization` | limited topology redundancy and a live validator set | strong validator independence claim | independent operators and control-distribution evidence |
| `non-custodial` | baseline product/company posture in current docs | guarantee that no operated bridge risk exists anywhere | counsel review and operational boundary enforcement |
| `settlement` | testnet job/vault/result/finalize flows and related contracts | regulated payment finality or fiat settlement claim | legal review and production controls |
| `compliance-ready` | documentation packet and identified workstreams exist | licensed, audited, or counsel-approved operation | entity, counsel, publication, and controls completion |

## 1. Bridge Readiness Terminology

Live endpoint rechecked on June 19, 2026:

- `GET https://rpc.ynxweb4.com/bridge/route-readiness`

Observed summary:

- `full_loop_tested = 5/5`
- `automatic_loop_ready = 2/5`

Required wording discipline:

- `automatic_loop_ready` means configuration and adapter readiness;
- current automatic-ready routes are BTC testnet BTC and TRON Shasta USDT on
  the public-testnet release-adapter path;
- Sepolia ETH and USDC remain deposit-tested but not automatic-ready because the
  Sepolia lockbox owner signer is not configured in the live bridge service;
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

## 3. Website Disclosure Status

Observed on June 14, 2026:

- `https://www.ynxweb4.com/privacy` and `/terms` are browser-reachable
  disclosure routes on the public site;
- raw HTTP fetch still returns the SPA shell, so publication should be judged
  by reachable rendered content rather than server-side static HTML alone.

Conclusion:

- website-visible disclosure routes now exist;
- the remaining blocker is not route existence, but the absence of a formed
  legal entity and entity-specific ownership/controller disclosures behind
  those project-stage pages.

## 4. Token Policy Separation

Repository history still contains older v0 tokenomics drafts. Those drafts
should not be presented as the current financing term sheet.

Current financing-safe position:

- no founder-fee commitment should be assumed;
- future default founder fee policy should remain `0 bps` unless separately
  disclosed and approved;
- infrastructure revenue should be the underwriting story, not token extraction.
- as of June 14, 2026, the live public indexer overview still exposes
  `fee_founder_bps = 1000`, so investors should expect an explicit explanation
  of why current testnet runtime state and financing posture are not identical.

## 5. Practical Conclusion

YNX is already beyond concept stage, but investor confidence depends on keeping
three things aligned at all times:

1. live endpoint truth;
2. written diligence materials;
3. website-visible disclosure pages and the repo text that describes them.
