# YNX 公开资产状态

状态：active  
最后更新：2026-05-31
范围：公开测试网 `ynx_9102-1`

## 当前答案

现在 YNX 公开测试网已完整可用的资产是：

| 资产 | 类型 | 单位 / 合约 | 状态 |
|---|---|---|---|
| `NYXT` | 原生 gas / staking / governance 资产 | base denom `anyxt`，18 位小数 | 已上线公开测试网 |
| `NYXT` | EVM ERC-20 系统合约 | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | 已上线公开测试网 |

用户现在可以在公开测试网上转 `anyxt` / `NYXT`，并用于 gas、质押、治理、faucet 和 EVM 测试流程。

测试网资产没有主网价值。

## 公开 wrapped asset route

公开测试网现在已经部署了第一批主流资产的 wrapped token 合约、bridge
gateway route，以及 bridge observer/relayer API。它们是公开测试网 wrapped
表示，不等于真实主网外部资产已经完成托管、可赎回或已有交易流动性。

Gateway：`0x3a2948da8f35b86dce1440ebfb56b8ae041cebfe`
Bridge service：`https://rpc.ynxweb4.com/bridge/*`

| 来源测试网资产 | Route | YNX wrapped token | 合约 | 小数位 | 公开测试网状态 |
|---|---|---|---|---:|---|
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | token + route + observer 已部署 |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | token + route + observer 已部署 |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | token + route + observer 已部署 |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | token + route + observer 已部署 |
| Circle Sepolia USDC | `eth-sepolia-usdc` | `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 | token + route + observer 已部署 |

Bridge service 暴露：

- `GET /bridge/health`
- `GET /bridge/ready`
- `GET /bridge/routes`
- `GET /bridge/source-status`
- `GET /bridge/route-checks`
- `GET /bridge/watchers`
- `POST /bridge/deposits/prove`
- `POST /bridge/watchers/scan`
- `POST /bridge/withdrawals/request`

EVM 源链 lockbox 合约 `YNXSourceLockbox` 已实现，可用于 Sepolia ETH、
Circle Sepolia USDC、BSC testnet BNB。部署到这些源链测试网只差测试网 gas，
接收地址：

```text
0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5
```

## 还没正式上线的能力

公开测试网现在还没有生产级真实主网 BTC、ETH、BNB、USDT、USDC 托管、赎回能力，也还没有官方交易流动性。

## 目标主流币清单

极速交易方向应优先做：

| 优先级 | 资产 | YNX 目标表示 | 来源路线 |
|---:|---|---|---|
| 1 | `BTC` | `wBTC.y` | 先做托管/MPC 路线，后续再做更去信任路线 |
| 2 | `ETH` | `wETH.y` | Ethereum bridge route |
| 3 | `BNB` | `wBNB.y` | BNB Smart Chain bridge route |
| 4 | `USDT` | `wUSDT.y` | 先 TRON，再 Ethereum/BSC |
| 5 | `USDC` | `wUSDC.y` | Ethereum/Base/Solana 视合作方支持决定 |

## 对外说“完整可交易”前必须具备

每个真实外部资产都需要：

- 公开测试网或主网上已部署 wrapped token 合约；`9102 测试网已完成`
- bridge gateway source chain + remote asset route；`9102 测试网已完成`
- deposit/withdraw 的观察者、签名者或验证路径；`测试网 bridge service 已就绪`
- EVM 源链 lockbox 和 watcher；`已实现，等待源链测试网 gas 部署`
- 稳定币 issuer/canonical token 校验；
- 流动性或做市计划；
- 单资产限额、暂停开关、监控和事故响应；
- 法律/合规对运营模型确认。

## 权威部署记录

公开测试网资产元数据在：

- `packages/contracts/deployments/public-testnet-9102.json`
- `packages/contracts/config/public-testnet-bridge-routes-9102.json`
- `packages/contracts/config/source-lockbox-testnet.json`
- `packages/contracts/deployments/public-mainstream-bridge-9102.json`
- `infra/bridge-service/config/testnet-routes.json`
