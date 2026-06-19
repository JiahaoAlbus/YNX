# YNX Production Blocker Matrix

Status date: 2026-06-13

## Current Production Posture

- validators bonded: `4/4`
- public readiness gate: `PASS`
- bridge deposit-tested: `4/5`
- bridge release-evidence-observed: `5/5`
- automatic-loop-ready: `2/5`
- automatic-loop-observed: `2/5`

Important interpretation:

- `4/4 bonded` does not by itself prove strong validator independence;
- `4/5 deposit-tested` and `4/5 release-evidence-observed` do not mean
  `4/5 production-safe`;
- `automatic_loop_ready` means the route configuration and adapters are present;
- `automatic_loop_observed` means YNX has already observed automation through
  live watcher/release evidence rather than only configuration;
- this matrix should be read as testnet operational evidence, not as proof that
  YNX is already institution-grade infrastructure.

## Remaining Route Blockers

| Route | Current status | Missing production input | Why it is blocked |
|---|---|---|---|
| `btc-testnet-btc` | full-loop-tested, automatic-ready | repeated live automatic deposit/release evidence | BTC watcher and public-testnet release adapter are now configured, but this still should not be described as production-safe custody |
| `eth-sepolia-eth` | deposit-tested, not automatic | Sepolia lockbox owner signer in the live bridge service | The lockbox and watcher are live, but release remains pending signer because the lockbox owner key is not wired into the bridge service |
| `bnb-testnet-bnb` | route mapped, manual proof observed, not automatic | BSC lockbox deployment, testnet BNB funding for deployer | EVM lockbox automation path exists, but no BSC lockbox is configured yet, so it does not count as deposit-tested in the current readiness model |
| `tron-shasta-usdt` | full-loop-tested, automatic-ready | repeated live automatic deposit/release evidence | TRON watcher and public-testnet release adapter are now configured, but this still should not be described as production-safe custody |
| `eth-sepolia-usdc` | deposit-tested, not automatic | Sepolia lockbox owner signer in the live bridge service | The lockbox and watcher are live, but release remains pending signer because the lockbox owner key is not wired into the bridge service |

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

`YNX Web4 public testnet is live. We currently have 4/5 bridge routes deposit-tested, 5/5 routes with some form of public release proof, and 2/5 routes automatic-loop-ready on the current public-testnet adapter path. BTC testnet BTC and TRON Shasta USDT are automatic-ready today; Sepolia ETH and USDC still wait on the Sepolia lockbox owner signer, and BNB still waits on a BSC lockbox before it can count as deposit-tested in the current readiness model. The bridge should still be described as testnet architecture evidence rather than production custody infrastructure.`
