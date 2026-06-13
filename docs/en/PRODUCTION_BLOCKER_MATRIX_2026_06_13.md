# YNX Production Blocker Matrix

Status date: 2026-06-13

## Current Production Posture

- validators bonded: `4/4`
- public readiness gate: `PASS`
- bridge full-loop-tested: `5/5`
- automatic-loop-live: `2/5`

Important interpretation:

- `4/4 bonded` does not by itself prove strong validator independence;
- `5/5 full-loop-tested` does not mean `5/5 production-safe`;
- this matrix should be read as testnet operational evidence, not as proof that
  YNX is already institution-grade infrastructure.

## Remaining Route Blockers

| Route | Current status | Missing production input | Why it is blocked |
|---|---|---|---|
| `btc-testnet-btc` | full-loop-tested, not automatic | `depositAddress`, `BRIDGE_SOURCE_BTC_TESTNET_SIGNER` | BTC watcher and release adapter are implemented, but live deposit and signer config are still absent |
| `bnb-testnet-bnb` | full-loop-tested, not automatic | BSC lockbox deployment, testnet BNB funding for deployer | EVM lockbox automation path exists, but the deploy signer has zero BSC testnet gas and no lockbox is configured |
| `tron-shasta-usdt` | full-loop-tested, not automatic | `depositAddress`, `sourceContract`, `BRIDGE_SOURCE_TRON_SHASTA_SIGNER` | TRON watcher/release adapter exists, but live contract/address and signer config are still absent |

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

`YNX Web4 public testnet is live. We have 5/5 bridge routes full-loop tested, protected AI trade execution through Web4 session policy, and 2/5 routes already running automatic deposit/release loops. The remaining BTC, TRON, and BSC routes are adapter-level configuration blockers, but the bridge should still be described as testnet architecture evidence rather than production custody infrastructure.`
