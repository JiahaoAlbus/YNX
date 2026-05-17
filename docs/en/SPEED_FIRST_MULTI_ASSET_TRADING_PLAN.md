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
- Bridge framework exists in code.
- Devnet bridge records exist, but public-testnet mainstream assets are not live.

### Phase 1 — Public-Testnet Wrapped Asset Pilot

Target assets:

- `wETH.y`
- `wBNB.y`
- `wUSDT.y`

Required:

- deploy gateway to public testnet `9102`;
- deploy wrapped tokens;
- publish route manifest;
- add explorer/indexer asset display;
- add faucet-style test mints only if clearly labeled synthetic test assets;
- run bridge smoke tests and publish evidence.

### Phase 2 — Trading UX

Required:

- swap/quote interface or partner DEX route;
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

`YNX is a speed-first Web4 public testnet with EVM-compatible execution. The live public-testnet asset is NYXT/anyxt. Mainstream wrapped assets such as BTC, ETH, BNB, USDT, and USDC are planned trading targets, not live public-testnet assets yet.`

Incorrect today:

- `BTC/ETH/BNB are already tradable on YNX.`
- `YNX is a decentralized exchange.`
- `YNX custody is risk-free.`
- `Mainnet assets can be deposited today.`

