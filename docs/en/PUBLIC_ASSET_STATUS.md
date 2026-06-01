# YNX Public Asset Status

Status: active  
Last updated: 2026-06-01
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
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | token + route + observer deployed |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | full loop tested: deposit + withdrawal release |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | token + route + observer deployed |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | token + route + observer deployed |
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
mapped_route_only: btc-testnet-btc, bnb-testnet-bnb, tron-shasta-usdt
```

BSC testnet BNB deployment still requires testnet gas on the bridge operator
address. The BNB official testnet faucet also requires this address to hold
at least `0.002 BNB` on BSC mainnet:

```text
0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5
```

## Not Live Yet

The public testnet does **not** yet have production-grade real mainnet BTC,
ETH, BNB, USDT, or USDC custody, redemption, or official trading liquidity.

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
