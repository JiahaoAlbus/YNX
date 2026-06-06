# YNX Public Asset Status

Status: active  
Last updated: 2026-06-06
Scope: public testnet `ynx_9102-1`

## Current Answer

Today, the public YNX testnet has one fully usable live asset:

| Asset | Type | Unit / Contract | Status |
|---|---|---|---|
| `NYXT` | native gas / staking / governance asset | base denom `anyxt`, 18 decimals | live public testnet |
| `NYXT` | EVM ERC-20 system contract | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | live public testnet |
| `YUSD.test` | synthetic test stable asset | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172`, 6 decimals | live public testnet; not redeemable |

Users can transfer `anyxt`/`NYXT` on the public testnet and use it for gas,
staking, governance, faucet flows, and EVM-compatible test workflows.

Testnet assets have no mainnet value. `YUSD.test` is not USDC, USDT, USD,
e-money, a bank deposit, or a redeemable stablecoin. It is a synthetic
public-testnet unit for trading, bridge, AI-payment, and UX testing.

## Public Wrapped Asset Routes

The public testnet now has deployed wrapped-token contracts, bridge gateway
routes, and a bridge observer/relayer API for the first mainstream testnet
asset set. These are public-testnet wrapped representations, not claims that
real mainnet external assets are already custodied, redeemable, or liquid.

Gateway: `0x3a2948da8f35b86dce1440ebfb56b8ae041cebfe`
Bridge service: `https://rpc.ynxweb4.com/bridge/*`

| Source testnet asset | Route | YNX wrapped token | Contract | Decimals | Public-testnet status |
|---|---|---|---|---:|---|
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | manual proof loop ready |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | full loop tested: deposit + withdrawal release |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | manual proof loop ready; BSC funding still not prioritized |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | manual proof loop ready |
| Circle Sepolia USDC | `eth-sepolia-usdc` | `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 | full loop tested: deposit + withdrawal release |

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

Current route readiness:

```text
GET /bridge/route-readiness
full_loop_tested: eth-sepolia-eth, eth-sepolia-usdc
manual_loop_ready: btc-testnet-btc, bnb-testnet-bnb, tron-shasta-usdt
mapped_route_only: none
```

Manual loop ready means:

```text
external testnet deposit observed by operator
-> operator submits /bridge/deposits/prove
-> bridge gateway mints the YNX wrapped asset
-> user burns wrapped asset on YNX
-> YNX burn watcher queues withdrawal
-> operator releases the external testnet asset and records /bridge/withdrawals/:id/mark-released
```

This is a real testnet audit trail, but it is not yet automatic external-chain
custody. BTC and TRON still need automatic deposit watchers, external signing
policy, custody/MPC controls, and release automation before they can be called
production-grade bridge routes.

BSC testnet BNB deployment still requires testnet gas on the bridge operator
address. The BNB official testnet faucet also requires this address to hold
at least `0.002 BNB` on BSC mainnet:

```text
0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5
```

## Not Live Yet

The public testnet does **not** yet have production-grade real mainnet BTC,
ETH, BNB, USDT, or USDC custody, redemption, or official trading liquidity.

## Current Functionality and Gaps

| Area | What works now | How it is implemented | Remaining gap |
|---|---|---|---|
| YNX L1 testnet | Public chain, EVM RPC, native `anyxt` gas, explorer/indexer/faucet | `ynx-v2-node`, EVM JSON-RPC, REST/indexer/faucet services on Tencent Cloud | Mainnet-grade validator diversity, SLO hardening, security audit, disaster recovery |
| Wrapped assets | `wBTC.y`, `wETH.y`, `wBNB.y`, `wUSDT.y`, `wUSDC.y` contracts and YNX gateway routes | `YNXBridgeGateway` + `YNXWrappedAsset` on chain 9102 | External mainnet custody/redemption and governed liquidity |
| Sepolia bridge | ETH and USDC full-loop tested | Sepolia `YNXSourceLockbox`, automatic deposit watcher, YNX mint, YNX burn watcher, Sepolia release | More volume tests, monitoring, failure replay, audit |
| BTC/TRON bridge | Manual proof loop ready | Operator-verified deposit proof API, YNX mint, YNX burn watcher, manual external release proof | Automatic BTC/TRON watchers, MPC/signing policy, external release automation |
| BSC route | Wrapped route ready; manual proof loop ready | Route and wBNB.y contract deployed; source chain configured | BSC testnet funding if prioritized, lockbox deployment for automatic loop |
| Trading | Minimal AMM pilot for `wUSDC.y/YUSD.test` and `wETH.y/YUSD.test` | Test AMM contracts with small seeded liquidity | Order book/AMM depth, routing, slippage controls, market monitoring |
| YUSD.test | Synthetic stable test asset live | ERC-20 style test token for testnet pricing and AI payments | Not redeemable; real stablecoin needs issuer/regulated partner or a clearly synthetic non-redeemable test asset |
| AI Intelligence | Public `/ai/chat` and `/ai/intelligence/brief` live; server-local model enabled | AI Gateway reads bridge/Web4/AI state; Ollama `qwen2.5:1.5b` runs on server; official answer remains deterministic facts | Better model, retrieval tuning, operator commands, alerting actions |
| AI settlement | Vault/job/payment flow and on-chain settlement tested | AI Gateway + `YNXAISettlement` contract at `0x87e8...2Fcf` | Challenge/slash governance, signer rotation, deeper audit |
| Web4 | Policies, sessions, tool authorization, audit logs | Web4 Hub authorizes AI actions against policy/session limits | More user-facing policy UI and external developer SDK |
| Monitoring | Bridge full-loop probe and AI on-chain probe timers active | systemd timers: `ynx-public-bridge-full-loop.timer`, `ynx-public-ai-onchain.timer` | Pager/alert integration, SLO dashboards, incident runbooks |

## Public Testnet Trading Pilot

The public testnet has a minimal AMM pilot for test swaps:

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
