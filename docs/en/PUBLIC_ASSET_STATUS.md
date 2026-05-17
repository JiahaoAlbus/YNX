# YNX Public Asset Status

Status: active  
Last updated: 2026-05-17  
Scope: public testnet `ynx_9102-1`

## Current Answer

Today, the public YNX testnet officially supports one live asset:

| Asset | Type | Unit / Contract | Status |
|---|---|---|---|
| `NYXT` | native gas / staking / governance asset | base denom `anyxt`, 18 decimals | live public testnet |
| `NYXT` | EVM ERC-20 system contract | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | live public testnet |

Users can transfer `anyxt`/`NYXT` on the public testnet and use it for gas,
staking, governance, faucet flows, and EVM-compatible test workflows.

Testnet assets have no mainnet value.

## Not Live Yet

The public testnet does **not** yet have official real BTC, ETH, BNB, USDT, or
USDC trading liquidity.

The repository includes a generic bridge framework and devnet onboarding records
for wrapped assets such as `wBTC.y`, `wETH.y`, and `wUSDT.y`, but those records
are local/devnet `31337` deployments. They must not be described as public
testnet or mainnet tradable assets.

## Target Mainstream Asset List

The speed-first trading direction should prioritize:

| Priority | Asset | Target YNX representation | Source routes |
|---:|---|---|---|
| 1 | `BTC` | `wBTC.y` | BTC custodial/MPC route first, trust-minimized route later |
| 2 | `ETH` | `wETH.y` | Ethereum bridge route |
| 3 | `BNB` | `wBNB.y` | BNB Smart Chain bridge route |
| 4 | `USDT` | `wUSDT.y` | TRON first, then Ethereum/BSC |
| 5 | `USDC` | `wUSDC.y` | Ethereum/Base/Solana route depending partner support |

## What Must Exist Before Public Trading Claims

For each real external asset, YNX needs:

- a deployed public-testnet or mainnet wrapped token contract;
- a bridge gateway route for the source chain and remote asset ID;
- an observer/signer or verification path for deposits and withdrawals;
- issuer/canonical-token checks for stablecoins;
- liquidity or market-making plan;
- per-asset risk limits, pause controls, monitoring, and incident response;
- legal/compliance sign-off for the operating model.

## Canonical Deployment Record

Public testnet asset metadata lives in:

- `packages/contracts/deployments/public-testnet-9102.json`

