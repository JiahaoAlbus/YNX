# YNX Public Asset Status

Status: active  
Last updated: 2026-06-19
Scope: public testnet `ynx_9102-1`

## Current Answer

Today, the public YNX testnet has three currently usable public-testnet assets:

| Asset | Type | Unit / Contract | Status |
|---|---|---|---|
| `NYXT` | native gas / staking / governance asset | base denom `anyxt`, 18 decimals | live public testnet |
| `NYXT` | EVM ERC-20 system contract | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | live public testnet |
| `YUSD.test` | synthetic test stable asset | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172`, 6 decimals | live public testnet; not redeemable |

Users can transfer `anyxt`/`NYXT` on the public testnet and use it for gas,
staking, governance, faucet flows, and EVM-compatible test workflows.

The validator set is live with 4 bonded validators, and current public-testnet
acceptance checks pass on the current hosted environment.

Testnet assets have no mainnet value. `YUSD.test` is not USDC, USDT, USD,
e-money, a bank deposit, or a redeemable stablecoin. It is a synthetic
public-testnet unit for trading, bridge, AI-payment, and UX testing.

## Public Wrapped Asset Routes

The public testnet now has deployed wrapped-token contracts, bridge gateway
routes, and a bridge observer/relayer API for the first mainstream testnet
asset set. These are public-testnet wrapped representations, not claims that
real mainnet external assets are already custodied, redeemable, or supported by
official mainnet liquidity.

Gateway: `0x3a2948da8f35b86dce1440ebfb56b8ae041cebfe`
Bridge service: `https://rpc.ynxweb4.com/bridge/*`

| Source testnet asset | Route | YNX wrapped token | Contract | Decimals | Public-testnet status |
|---|---|---|---|---:|---|
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | deposit and release evidence observed; current testnet auto-release path active |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | deposit tested; release evidence observed; automatic release still signer-gated |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | route mapped; manual proof and release evidence observed; BSC lockbox still unconfigured |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | deposit and release evidence observed; current testnet auto-release path active |
| Circle Sepolia USDC | `eth-sepolia-usdc` | `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 | deposit tested; release evidence observed; automatic release still signer-gated |

The bridge service exposes:

- `GET /health`
- `GET /ready`
- `GET /bridge/routes`
- `GET /bridge/source-status`
- `GET /bridge/route-checks`
- `GET /bridge/route-readiness`
- `GET /bridge/watchers`
- `GET /bridge/withdrawal-watchers`
- `GET /bridge/withdrawals`
- `POST /bridge/deposits/prove`
- `POST /bridge/watchers/scan`
- `POST /bridge/withdrawal-watchers/scan`
- `POST /bridge/withdrawals/request`
- `POST /bridge/withdrawals/reconcile`
- `POST /bridge/withdrawals/:id/mark-released`

The EVM source-chain lockbox contract is implemented as `YNXSourceLockbox`.
The Sepolia lockbox is live at:

```text
0x9b9913Ee3F99147856A19D7359A9fe5B7c8318C6
```

Live Sepolia ETH and USDC deposits have been minted on YNX as `wETH.y` and
`wUSDC.y`:

```text
Sepolia ETH deposit tx:  0xdbbf4ecdcdf059d745f8b88de12aa3141daa4502b5253a9bcbd21998b2e59bbc
YNX wETH.y mint tx:      0xf25af19868a90ff113987037c435f6c8cff2ef3ddd0c81272cde1af1714ff544
Sepolia USDC deposit tx: 0xd5cb82a03f7c12053e60783f03be2e16a32102154ba1f644e0284aaff2563c2c
```

Live withdrawal smoke tests:

```text
YNX wUSDC.y approve tx:   0xe6836c7de8c2579356be5d9959de5ba37c4f28301005352172cdae3ae4016776
YNX wUSDC.y burn tx:      0x03113a31aeb2c2dc17c218e308168ce370d3ba82c26db69878987c5b2f97cb22
Sepolia USDC release tx:  0xccfde97839036479ca55265a07a2d3770982797bead02864cb72f06591105893
Amount:                   0.01 wUSDC.y -> 0.01 Sepolia USDC

YNX wETH.y approve tx:    0xf0b81210651625afc7d77d4b2ef887f88ae8a74c9269eb14a90b5e61b218d94c
YNX wETH.y burn tx:       0x1475b1d8f963462e386fad8f33a19ba2db35f16ca9970a6f2c3ed8c37fd145d6
Sepolia ETH release tx:   0x35eec0e6feda8a710f9083a237e8a582bd67eb87bce1e0c3ded378fa6331293a
Amount:                   0.0001 wETH.y -> 0.0001 Sepolia ETH
```

Manual public-testnet full-loop tests for BTC, BNB, and TRON routes:

```text
BTC testnet source proof: 0x2d4f3ac96c43828bed934bd8e376fff61a25c7711150a56895dcd759d1f9ce4d
YNX wBTC.y approve tx:    0xe18096eef2fe477cdf0ba971fc1ba032d3628800c62f954124c59872a46319f3
YNX wBTC.y burn tx:       0xf9220fd505610668a724bb6ac40e4e17c992cbadb8764289ee57c072908739f8
BTC testnet release tx:   0x5a6831822cf2c54a5583347abe96f9ff54893033bcdc23187610661426a5f210
Amount:                   0.00000001 wBTC.y

BSC testnet source proof: 0x631f4edabb7a8efed7248faf7dad91c39777bf25a136eac44eb4b08ac872fd31
YNX wBNB.y approve tx:    0xeaeb39d1909acc4c44d877fd3e7e15645aeb2ffb50547a943e5d491939cf8df0
YNX wBNB.y burn tx:       0xe13923bdcf6181b5e88f619c1e45f20e3d0f9e5e2d6f321d8223133e772ca208
BSC testnet BNB release tx: 0xf7d2c900390c1627c1de53d00bdbf0d0c2395383273ac279907df913d19342fe
Amount:                   0.000000000000000001 wBNB.y

TRON Shasta source proof: 0xd6ea9dc7777a5bb05ab47d610245c494a6c7b6686ff7e2ccb2b64037519767af
YNX wUSDT.y approve tx:   0x25a9b46b9dfca348c0264d4c198b3cebc4fb916a728a8892f708b5cea1666dd1
YNX wUSDT.y burn tx:      0x107d4d706672c7322d8ac66617aeb4076761e93844d46a7d88f3825e590bed3f
TRON Shasta USDT release tx: 0xf02bc21e3b8522d784f67e2c17fbb26e91a7294f064957b7e5907b6372ce257c
Amount:                   0.000001 wUSDT.y
```

Current route readiness:

```text
GET /bridge/route-readiness
deposit_tested: btc-testnet-btc, eth-sepolia-eth, tron-shasta-usdt, eth-sepolia-usdc
release_evidence_observed: btc-testnet-btc, eth-sepolia-eth, bnb-testnet-bnb, tron-shasta-usdt, eth-sepolia-usdc
automatic_loop_ready: btc-testnet-btc, tron-shasta-usdt
bsc_gap: source_lockbox_unconfigured
mapped_route_only: BSC testnet BNB
```

As of 2026-06-19, the live bridge readiness posture is:

- `4/5` routes `deposit_tested`
- `5/5` routes show some form of public release evidence
- `2/5` routes `automatic_loop_ready`
- `btc-testnet-btc`: automatic-ready on the current public-testnet adapter path
- `tron-shasta-usdt`: automatic-ready on the current public-testnet adapter path
- `eth-sepolia-eth`: deposit-tested with release evidence, but automatic release still waits on the Sepolia lockbox owner signer
- `eth-sepolia-usdc`: deposit-tested with release evidence, but automatic release still waits on the Sepolia lockbox owner signer
- `bnb-testnet-bnb`: route mapping and manual release proof exist, but BSC lockbox deployment is still missing before it can count as deposit-tested or automatic-ready in the current readiness model

Current evidence boundaries mean:

```text
external testnet deposit observed by operator
-> operator submits /bridge/deposits/prove
-> bridge gateway mints the YNX wrapped asset
-> user burns wrapped asset on YNX
-> YNX burn watcher queues withdrawal
-> operator releases the external testnet asset and records /bridge/withdrawals/:id/mark-released
```

This is a real YNX-side public-testnet audit trail using operator-attested
source proof and release records. The bridge service now has automatic watcher
adapters for BTC testnet and TRON Shasta, reuses EVM lockbox automation for BSC
testnet once a BSC lockbox is configured, and exposes signer-gated testnet
release adapters. As of June 19, 2026, `automatic_loop_ready` is earned only
where deposit watcher, burn watcher, and release adapter are all active
together. Sepolia ETH and USDC currently have deposit-test and release evidence
but remain short of automatic readiness because the Sepolia lockbox owner signer
is not configured on the live service. BSC still lacks the source lockbox.

Important diligence note:

- `automatic_loop_ready` is a configuration and adapter-readiness state;
- it is stronger than manual-only support, but weaker than repeated public
  observed automation evidence;
- investors should not collapse `automatic_loop_ready` into "production-safe"
  or "fully proven at scale".

## Not Live Yet

The public testnet does **not** yet have production-grade real mainnet BTC,
ETH, BNB, USDT, or USDC custody, redemption, or official trading liquidity.

## Current Functionality and Gaps

| Area | What works now | How it is implemented | Remaining gap |
|---|---|---|---|
| YNX L1 testnet | Public chain, EVM RPC, native `anyxt` gas, explorer/indexer/faucet | `ynx-v2-node`, EVM JSON-RPC, REST/indexer/faucet services on Tencent Cloud | Mainnet-grade validator diversity, SLO hardening, security audit, disaster recovery |
| Wrapped assets | `wBTC.y`, `wETH.y`, `wBNB.y`, `wUSDT.y`, `wUSDC.y` contracts and YNX gateway routes | `YNXBridgeGateway` + `YNXWrappedAsset` on chain 9102 | External mainnet custody/redemption and governed liquidity |
| Sepolia bridge | ETH and USDC full-loop tested | Sepolia `YNXSourceLockbox`, automatic deposit watcher, YNX mint, YNX burn watcher, Sepolia release | More volume tests, monitoring, failure replay, audit |
| BTC/TRON bridge | Full-loop-tested with manual evidence; automatic watcher/release adapters implemented | Blockstream/TronGrid watcher lanes, YNX mint, YNX burn watcher, signer-gated testnet release adapter | Configure live deposit addresses/contracts/signers; future MPC/custody policy for production |
| BSC route | Full-loop-tested with manual evidence; EVM lockbox automation path implemented | Route and wBNB.y contract deployed; source chain configured; BSC lockbox config required for automatic PASS | Deploy/configure BSC testnet lockbox and source signer |
| Trading | Minimal AMM pilot for `wUSDC.y/YUSD.test` and `wETH.y/YUSD.test`; deploy script can seed wBTC/wBNB/wUSDT YUSD pairs when addresses/liquidity are provided | Test AMM contracts with small seeded liquidity and AI quote/preflight/prepare/execute checks | More depth, routing, slippage controls, market monitoring |
| YUSD.test | Synthetic stable test asset live | ERC-20 style test token for testnet pricing and AI payments | Not redeemable; real stablecoin needs issuer/regulated partner or a clearly synthetic non-redeemable test asset |
| AI Intelligence | Public `/ai/chat`, `/ai/chat/stream`, and `/ai/intelligence/brief` live; server-local model enabled; `trade.execute` is protected | AI Gateway reads bridge/Web4/AI state; quote/preflight/prepare are public; chat supports request-scoped NDJSON streaming; execute requires Web4 policy/session and a configured testnet agent signer | Better model, retrieval tuning, alerting actions, future MPC/agent authorization |
| AI settlement | Vault/job/payment flow and on-chain settlement tested | AI Gateway + `YNXAISettlement` contract at `0x87e8...2Fcf` | Challenge/slash governance, signer rotation, deeper audit |
| Web4 | Policies, sessions, tool authorization, audit logs | Web4 Hub authorizes AI actions against policy/session limits | More user-facing policy UI and external developer SDK |
| Monitoring | Bridge full-loop probe and AI on-chain probe timers active | systemd timers: `ynx-public-bridge-full-loop.timer`, `ynx-public-ai-onchain.timer` | Pager/alert integration, SLO dashboards, incident runbooks |

## Public Testnet Trading Pilot

The public testnet has a minimal AMM pilot for test swaps. This is useful test
evidence, not a basis for broad "real external assets are tradable on YNX"
claims:

| Pair | Contract | Status |
|---|---|---|
| `wUSDC.y / YUSD.test` | `0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E` | live; smoke swap tested |
| `wETH.y / YUSD.test` | `0x84868c7554efB510964a7b54E4afcAE11275475c` | live; initial liquidity seeded |

Smoke swap tx:

```text
0x97662fd10fac494102180a5dbc2f26214a95aa003bf1be490d8edb0506243001
```

## Target Mainstream Asset List

The speed-first trading direction should prioritize:

| Priority | Asset | Target YNX representation | Source routes |
|---:|---|---|---|
| 1 | `BTC` | `wBTC.y` | BTC custodial/MPC route first, trust-minimized route later |
| 2 | `ETH` | `wETH.y` | Ethereum bridge route |
| 3 | `BNB` | `wBNB.y` | BNB Smart Chain bridge route |
| 4 | `USDT` | `wUSDT.y` | TRON first, then Ethereum/BSC |
| 5 | `USDC` | `wUSDC.y` | Ethereum/Base/Solana route depending partner support |

## What Must Exist Before Full Public Trading Claims

For each real external asset, YNX needs:

- a deployed public-testnet or mainnet wrapped token contract; `done on 9102 testnet`
- a bridge gateway route for the source chain and remote asset ID; `done on 9102 testnet`
- an observer/signer or verification path for deposits and withdrawals; `Sepolia testnet bridge service ready`
- EVM source-chain lockbox and watcher; `Sepolia ETH + USDC deposit and withdrawal live and tested, BSC testnet awaiting BNB/tBNB funding`
- issuer/canonical-token checks for stablecoins;
- liquidity or market-making plan;
- per-asset risk limits, pause controls, monitoring, and incident response;
- legal/compliance sign-off for the operating model.

## Canonical Deployment Record

Public testnet asset metadata lives in:

- `packages/contracts/deployments/public-testnet-9102.json`
- `packages/contracts/config/public-testnet-bridge-routes-9102.json`
- `packages/contracts/config/source-lockbox-testnet.json`
- `packages/contracts/deployments/public-mainstream-bridge-9102.json`
- `infra/bridge-service/config/testnet-routes.json`
