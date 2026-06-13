# YNX Production Blocker Matrix

Status date: 2026-06-13

## Current Production Posture

- validators bonded: `4/4`
- public readiness gate: `PASS`
- bridge full-loop-tested: `5/5`
- automatic-loop-ready: `4/5`
- automatic-loop-observed: `2/5`

Important interpretation:

- `4/4 bonded` does not by itself prove strong validator independence;
- `5/5 full-loop-tested` does not mean `5/5 production-safe`;
- `automatic_loop_ready` means the route configuration and adapters are present;
- `automatic_loop_observed` means YNX has already observed automation through
  live watcher/release evidence rather than only configuration;
- this matrix should be read as testnet operational evidence, not as proof that
  YNX is already institution-grade infrastructure.

## Remaining Route Blockers

| Route | Current status | Missing production input | Why it is blocked |
|---|---|---|---|
| `btc-testnet-btc` | full-loop-tested, automatic-ready, limited observed automation evidence | repeated live automatic deposit/release evidence | BTC watcher and release adapter are configured, but the public evidence packet is still thinner than the Sepolia routes |
| `bnb-testnet-bnb` | full-loop-tested, not automatic | BSC lockbox deployment, testnet BNB funding for deployer | EVM lockbox automation path exists, but the deploy signer has zero BSC testnet gas and no lockbox is configured |
| `tron-shasta-usdt` | full-loop-tested, automatic-ready, limited observed automation evidence | repeated live automatic deposit/release evidence | TRON watcher/release adapter is configured, but the public evidence packet is still thinner than the Sepolia routes |

## What Was Completed

- restored the validator set to `4/4` bonded validators
- re-ran production acceptance until `public_security_gate` and `public_testnet_extreme_readiness` were green
- kept `5/5 full-loop-tested` wording aligned with the actual route evidence
- deployed website production fixes and live ops visibility to `https://www.ynxweb4.com`

## Remaining Non-Route Blockers

- validator independence evidence is still too thin for strong decentralization
  wording;
- security process is improving, but public security contact and incident
  ownership are not yet organizationally mature;
- infra persistence and recovery posture still need further hardening before any
  production-grade claim;
- bridge routes remain the highest operational and trust surface in the stack.

## Sponsor-Safe Wording

Use this wording:

`YNX Web4 public testnet is live. We have 5/5 bridge routes full-loop tested, 4/5 routes automatic-loop-ready by current route configuration, and the strongest observed automatic public evidence today on the Sepolia ETH and USDC routes. The bridge should still be described as testnet architecture evidence rather than production custody infrastructure.`
