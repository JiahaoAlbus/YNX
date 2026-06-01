# YNX 公开资产状态

状态：active  
最后更新：2026-06-01
范围：公开测试网 `ynx_9102-1`

## 当前答案

现在 YNX 公开测试网已完整可用的资产是：

| 资产 | 类型 | 单位 / 合约 | 状态 |
|---|---|---|---|
| `NYXT` | 原生 gas / staking / governance 资产 | base denom `anyxt`，18 位小数 | 已上线公开测试网 |
| `NYXT` | EVM ERC-20 系统合约 | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | 已上线公开测试网 |
| `YUSD.test` | 合成测试稳定资产 | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172`，6 decimals | 已上线公开测试网；不可赎回 |

用户现在可以在公开测试网上转 `anyxt` / `NYXT`，并用于 gas、质押、治理、faucet 和 EVM 测试流程。

测试网资产没有主网价值。`YUSD.test` 不是 USDC、USDT、USD、电子货币、
银行存款或可赎回稳定币。它只是用于交易、跨链、AI 支付和 UX 测试的公开测试网合成单位。

## 公开 wrapped asset route

公开测试网现在已经部署了第一批主流资产的 wrapped token 合约、bridge
gateway route，以及 bridge observer/relayer API。它们是公开测试网 wrapped
表示，不等于真实主网外部资产已经完成托管、可赎回或已有交易流动性。

Gateway：`0x3a2948da8f35b86dce1440ebfb56b8ae041cebfe`
Bridge service：`https://rpc.ynxweb4.com/bridge/*`

| 来源测试网资产 | Route | YNX wrapped token | 合约 | 小数位 | 公开测试网状态 |
|---|---|---|---|---:|---|
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | token + route + observer 已部署 |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | 源链 lockbox + 充值 watcher + 提现 watcher 已上线 |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | token + route + observer 已部署 |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | token + route + observer 已部署 |
| Circle Sepolia USDC | `eth-sepolia-usdc` | `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 | 源链 lockbox + 充值 watcher + 提现 watcher 已上线 |

Bridge service 暴露：

- `GET /bridge/health`
- `GET /bridge/ready`
- `GET /bridge/routes`
- `GET /bridge/source-status`
- `GET /bridge/route-checks`
- `GET /bridge/watchers`
- `GET /bridge/withdrawal-watchers`
- `GET /bridge/withdrawals`
- `POST /bridge/deposits/prove`
- `POST /bridge/watchers/scan`
- `POST /bridge/withdrawal-watchers/scan`
- `POST /bridge/withdrawals/request`
- `POST /bridge/withdrawals/reconcile`

EVM 源链 lockbox 合约 `YNXSourceLockbox` 已实现。Sepolia lockbox 已上线：

```text
0x9b9913Ee3F99147856A19D7359A9fe5B7c8318C6
```

Sepolia ETH 和 USDC 已完成真实充值，并在 YNX 上铸出 `wETH.y` / `wUSDC.y`：

```text
Sepolia ETH deposit tx:  0xdbbf4ecdcdf059d745f8b88de12aa3141daa4502b5253a9bcbd21998b2e59bbc
YNX wETH.y mint tx:      0xf25af19868a90ff113987037c435f6c8cff2ef3ddd0c81272cde1af1714ff544
Sepolia USDC deposit tx: 0xd5cb82a03f7c12053e60783f03be2e16a32102154ba1f644e0284aaff2563c2c
```

提现 smoke test：

```text
YNX wUSDC.y approve tx:   0xe6836c7de8c2579356be5d9959de5ba37c4f28301005352172cdae3ae4016776
YNX wUSDC.y burn tx:      0x03113a31aeb2c2dc17c218e308168ce370d3ba82c26db69878987c5b2f97cb22
Sepolia USDC release tx:  0xccfde97839036479ca55265a07a2d3770982797bead02864cb72f06591105893
金额：                    0.01 wUSDC.y -> 0.01 Sepolia USDC
```

BSC testnet BNB 部署还需要给 bridge operator 地址补测试网 gas。
BNB 官方测试网水龙头还要求该地址在 BSC 主网持有至少 `0.002 BNB`：

```text
0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5
```

## 还没正式上线的能力

公开测试网现在还没有生产级真实主网 BTC、ETH、BNB、USDT、USDC 托管、赎回能力，也还没有官方交易流动性。

## 公开测试网交易 pilot

公开测试网已有最小 AMM pilot，可用于测试 swap：

| 交易池 | 合约 | 状态 |
|---|---|---|
| `wUSDC.y / YUSD.test` | `0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E` | 已上线；smoke swap 已实测 |
| `wETH.y / YUSD.test` | `0x84868c7554efB510964a7b54E4afcAE11275475c` | 已上线；已注入初始流动性 |

实测 swap tx：

```text
0x97662fd10fac494102180a5dbc2f26214a95aa003bf1be490d8edb0506243001
```

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
- deposit/withdraw 的观察者、签名者或验证路径；`Sepolia 测试网 bridge service 已就绪`
- EVM 源链 lockbox 和 watcher；`Sepolia 充值 + 提现已上线并实测，BSC testnet 等待 BNB/tBNB 资金`
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
