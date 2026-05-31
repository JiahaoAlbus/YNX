# YNX 极速优先多资产交易计划

状态：active  
最后更新：2026-05-17  
范围：战略方向与执行门禁

## 新方向

YNX 应定位为 **speed-first Web4 execution and trading layer**：

- 优先追求低延迟、高吞吐、极快确认体验和顺滑的 EVM 交易 UX；
- 去中心化作为安全层和结算层配置项，不作为第一卖点；
- 对外表述保持准确：公开测试网已上线，但真实多资产交易还要经过桥、流动性、安全和法律门禁。

## 产品目标

让主流资产通过 wrapped representations 在 YNX 上可用：

- `wBTC.y`
- `wETH.y`
- `wBNB.y`
- `wUSDT.y`
- `wUSDC.y`

第一阶段产品应该像一个极速交易执行场所，而不是普通“验证人去中心化故事”。

## 架构

1. **极速执行层**
   - 保持 EVM RPC 钱包兼容。
   - 优先优化 RPC、Indexer、Explorer、交易确认体验。
   - 增加 block time、RPC latency、indexer lag、用户可感知 finality 的 SLO 报告。

2. **桥与上市层**
   - 使用 `YNXBridgeGateway` 和 `YNXBridgeWrappedToken`。
   - 每个源链资产配置一个 route。
   - 测试网和早期 production preview 可先用 controlled signer/MPC attestation。
   - 高价值路线后续迁移到审计过的 threshold control 或更去信任验证。

3. **流动性层**
   - 围绕 `NYXT`、`wBTC.y`、`wETH.y`、`wBNB.y`、`wUSDT.y`、`wUSDC.y` 做精选池或 quote/RFQ 集成。
   - 没有真实 deposit/withdraw 和流动性前，不说“已可交易”。

4. **风险层**
   - 单资产 cap。
   - 暂停开关。
   - deposit confirmation threshold。
   - 大额提现延迟。
   - bridge signer、route、liquidity 故障监控。

## 执行阶段

### Phase 0 — 当前状态

- 公开测试网已上线。
- 官方可用资产：`NYXT` / `anyxt`。
- EVM-compatible surface 已上线。
- 桥框架已有代码。
- devnet 有桥资产记录，但公开测试网主流币资产还没上线。

### Phase 1 — 公开测试网 Wrapped Asset Pilot

目标资产：

- `wETH.y`
- `wBNB.y`
- `wUSDT.y`

必须完成：

- gateway 部署到公开测试网 `9102`；`已完成`
- wrapped tokens 部署；`已完成`
- route manifest 发布；`已完成`
- bridge observer/relayer API；`测试网 route service 已完成`
- EVM 源链 lockbox 和 watcher；`Sepolia 已上线并实测，BSC 等待 BNB/tBNB 资金`
- `YUSD.test` 合成测试资产；`已在 9102 上线`
- 测试 AMM 交易池；`wUSDC.y/YUSD.test 和 wETH.y/YUSD.test 已上线`
- explorer/indexer 显示资产；
- 如使用测试 mint，必须明确标注 synthetic test assets；
- 跑通 bridge smoke tests 并发布证据；`Sepolia ETH/USDC 充值和 YNX 铸币已实测`。

### Phase 2 — 交易 UX

必须完成：

- swap/quote 页面或 partner DEX route；
- 链上 AMM smoke swap；`YUSD.test -> wUSDC.y 已实测`
- public asset registry endpoint；
- explorer 支持余额和转账展示；
- asset status page 显示 live/degraded/paused；
- 对测试网/合成资产清晰标注风险。

### Phase 3 — Real-Value Production Preview

真实 BTC/ETH/BNB/USDT/USDC 对外宣称前必须完成：

- bridge contracts 和 signer operations 审计；
- custody/MPC 或 source-chain verification；
- 做市方或明确流动性；
- 非托管/运营桥责任的法律审查；
- incident response、pause、recovery drill。

## 当前可用对外表述

`YNX is a speed-first Web4 public testnet with EVM-compatible execution. NYXT/anyxt is the native public-testnet asset. YNX also has 9102 wrapped-token routes and a bridge observer/relayer API for BTC testnet, Sepolia ETH, BSC testnet BNB, TRON Shasta USDT, and Circle Sepolia USDC. Real mainnet BTC/ETH/BNB/USDT/USDC custody, redemption, and official liquidity are not live yet.`
