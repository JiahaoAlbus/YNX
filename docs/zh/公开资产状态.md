# YNX 公开资产状态

状态：active  
最后更新：2026-05-17  
范围：公开测试网 `ynx_9102-1`

## 当前答案

现在 YNX 公开测试网官方已上线的可用资产只有：

| 资产 | 类型 | 单位 / 合约 | 状态 |
|---|---|---|---|
| `NYXT` | 原生 gas / staking / governance 资产 | base denom `anyxt`，18 位小数 | 已上线公开测试网 |
| `NYXT` | EVM ERC-20 系统合约 | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | 已上线公开测试网 |

用户现在可以在公开测试网上转 `anyxt` / `NYXT`，并用于 gas、质押、治理、faucet 和 EVM 测试流程。

测试网资产没有主网价值。

## 还没正式上线的资产

公开测试网现在还没有官方真实 BTC、ETH、BNB、USDT、USDC 交易流动性。

仓库里已有通用桥框架，也有 `wBTC.y`、`wETH.y`、`wUSDT.y` 等 wrapped asset 的本地/devnet 记录，但这些是 `31337` 本地开发网部署记录，不能对外说成公开测试网或主网已可交易资产。

## 目标主流币清单

极速交易方向应优先做：

| 优先级 | 资产 | YNX 目标表示 | 来源路线 |
|---:|---|---|---|
| 1 | `BTC` | `wBTC.y` | 先做托管/MPC 路线，后续再做更去信任路线 |
| 2 | `ETH` | `wETH.y` | Ethereum bridge route |
| 3 | `BNB` | `wBNB.y` | BNB Smart Chain bridge route |
| 4 | `USDT` | `wUSDT.y` | 先 TRON，再 Ethereum/BSC |
| 5 | `USDC` | `wUSDC.y` | Ethereum/Base/Solana 视合作方支持决定 |

## 对外说“可交易”前必须具备

每个真实外部资产都需要：

- 公开测试网或主网上已部署 wrapped token 合约；
- bridge gateway source chain + remote asset route；
- deposit/withdraw 的观察者、签名者或验证路径；
- 稳定币 issuer/canonical token 校验；
- 流动性或做市计划；
- 单资产限额、暂停开关、监控和事故响应；
- 法律/合规对运营模型确认。

## 权威部署记录

公开测试网资产元数据在：

- `packages/contracts/deployments/public-testnet-9102.json`

