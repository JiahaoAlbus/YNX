# YNX Speed-First Multi-Asset Trading Plan

Status: active  
Last updated: 2026-05-17  
Scope: strategic direction and execution gates

## Direction

YNX should position itself as a **speed-first Web4 execution and trading layer**:

- optimize for low latency, fast finality perception, high-throughput execution,
  and smooth EVM-compatible trading UX;
- treat decentralization as a configurable safety and settlement layer, not the
  first product promise;
- keep public claims precise: public testnet is live, but real multi-asset
  trading is gated by bridge, liquidity, security, and legal readiness.

## Product Goal

Make mainstream assets usable on YNX through wrapped representations:

- `wBTC.y`
- `wETH.y`
- `wBNB.y`
- `wUSDT.y`
- `wUSDC.y`

The first public product should feel like a fast trading execution venue on YNX,
not a generic validator-decentralization story.

## Architecture

1. **Fast execution layer**
   - Keep EVM RPC fast and wallet-compatible.
   - Prioritize low-latency RPC, indexer, explorer, and transaction confirmation UX.
   - Add benchmark/SLO reporting for block time, RPC latency, indexer lag, and
     user-visible finality.

2. **Bridge/listing layer**
   - Use `YNXBridgeGateway` and `YNXBridgeWrappedToken`.
   - Add one route per source asset.
   - Start with controlled signer/MPC attestations for testnet and early
     production preview.
   - Move high-value routes toward audited threshold controls or trust-minimized
     verification when ready.

3. **Liquidity layer**
   - Launch curated pools or RFQ/quote integrations for `NYXT`, `wBTC.y`,
     `wETH.y`, `wBNB.y`, `wUSDT.y`, and `wUSDC.y`.
   - Do not claim an asset is tradable until there is actual liquidity and a
     functioning deposit/withdraw path.

4. **Risk layer**
   - Per-asset caps.
   - Pause controls.
   - Deposit confirmation thresholds.
   - Withdrawal delay for large transfers.
   - Monitoring and alerting for bridge signer, route, and liquidity failures.

## Execution Phases

### Phase 0 — Current State

- Public testnet live.
- Official tradable asset: `NYXT` / `anyxt`.
- EVM-compatible surface live.
- Bridge gateway, wrapped tokens, and testnet source routes are live on 9102.
- Bridge observer/relayer service is implemented for BTC testnet, Sepolia,
  BSC testnet, TRON Shasta, and Circle Sepolia USDC.
- EVM source-chain lockbox contract and watcher are live for Sepolia ETH
  and Circle Sepolia USDC. Sepolia ETH and USDC deposits have been minted
  on YNX as `wETH.y` and `wUSDC.y`.
- BSC testnet BNB lockbox deployment is gated by BSC funding for
  `0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5`.

### Phase 1 — Public-Testnet Wrapped Asset Pilot

Target assets:

- `wETH.y`
- `wBNB.y`
- `wUSDT.y`

Required:

- deploy gateway to public testnet `9102`; `done`
- deploy wrapped tokens; `done`
- publish route manifest; `done`
- deploy bridge observer/relayer API; `done for testnet route service`
- deploy EVM source-chain lockbox and watcher; `Sepolia live and tested, BSC awaiting BNB/tBNB funding`
- deploy `YUSD.test` synthetic test asset; `done on 9102`
- deploy test AMM pairs; `wUSDC.y/YUSD.test and wETH.y/YUSD.test live`
- add explorer/indexer asset display;
- add faucet-style test mints only if clearly labeled synthetic test assets;
- run bridge smoke tests and publish evidence; `Sepolia ETH/USDC deposits and YNX mints tested`

### Phase 2 — Trading UX

Required:

- swap/quote interface or partner DEX route;
- on-chain AMM smoke swap; `YUSD.test -> wUSDC.y tested`
- public asset registry endpoint;
- balances and transfers in explorer;
- asset status page showing live/degraded/paused;
- clear risk labels for testnet/synthetic assets.

### Phase 3 — Real-Value Production Preview

Required before real BTC/ETH/BNB/USDT/USDC claims:

- audited bridge contracts and signer operations;
- custody/MPC or trust-minimized source-chain verification;
- market makers or committed liquidity;
- legal review for non-custodial vs operated bridge responsibilities;
- incident response, pause, and recovery drill.

## Public Wording

Correct today:

`YNX is a speed-first Web4 public testnet with EVM-compatible execution. NYXT/anyxt is the native public-testnet asset. YNX also has 9102 wrapped-token routes and a bridge observer/relayer API for BTC testnet, Sepolia ETH, BSC testnet BNB, TRON Shasta USDT, and Circle Sepolia USDC. Real mainnet BTC/ETH/BNB/USDT/USDC custody, redemption, and official liquidity are not live yet.`

Incorrect today:

- `Mainnet BTC/ETH/BNB are already trustlessly native on YNX.`
- `YNX is a decentralized exchange.`
- `YNX custody is risk-free.`
- `Mainnet assets can be deposited today.`
