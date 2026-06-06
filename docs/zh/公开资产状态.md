# YNX 公开资产状态

状态：active  
最后更新：2026-06-06
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
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | manual proof 闭环 ready |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | 已完成完整闭环实测：充值 + 提现释放 |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | manual proof 闭环 ready；当前不优先补 BSC 资金 |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | manual proof 闭环 ready |
| Circle Sepolia USDC | `eth-sepolia-usdc` | `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 | 已完成完整闭环实测：充值 + 提现释放 |

Bridge service 暴露：

- `GET /bridge/health`
- `GET /bridge/ready`
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

YNX wETH.y approve tx:    0xf0b81210651625afc7d77d4b2ef887f88ae8a74c9269eb14a90b5e61b218d94c
YNX wETH.y burn tx:       0x1475b1d8f963462e386fad8f33a19ba2db35f16ca9970a6f2c3ed8c37fd145d6
Sepolia ETH release tx:   0x35eec0e6feda8a710f9083a237e8a582bd67eb87bce1e0c3ded378fa6331293a
金额：                    0.0001 wETH.y -> 0.0001 Sepolia ETH
```

当前 route readiness：

```text
GET /bridge/route-readiness
full_loop_tested: eth-sepolia-eth, eth-sepolia-usdc
manual_loop_ready: btc-testnet-btc, bnb-testnet-bnb, tron-shasta-usdt
mapped_route_only: none
```

manual_loop_ready 的意思是：

```text
外部测试网充值由 operator 验真
-> operator 调 /bridge/deposits/prove
-> bridge gateway 在 YNX 铸出 wrapped asset
-> 用户在 YNX burn wrapped asset
-> YNX burn watcher 排队提现
-> operator 在外部测试网释放资产，并用 /bridge/withdrawals/:id/mark-released 记录 release proof
```

这是真实测试网审计链路，但还不是自动外链托管。BTC / TRON 还需要自动
deposit watcher、外部签名策略、MPC/custody 控制和自动 release，才能称为
生产级 bridge route。

BSC testnet BNB 部署还需要给 bridge operator 地址补测试网 gas。
BNB 官方测试网水龙头还要求该地址在 BSC 主网持有至少 `0.002 BNB`：

```text
0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5
```

## 还没正式上线的能力

公开测试网现在还没有生产级真实主网 BTC、ETH、BNB、USDT、USDC 托管、赎回能力，也还没有官方交易流动性。

## 当前每个功能、实现方式和差距

| 功能区 | 现在能做什么 | 怎么实现 | 还差什么 |
|---|---|---|---|
| YNX L1 测试网 | 公链出块、EVM RPC、原生 `anyxt` gas、explorer/indexer/faucet | 腾讯云上的 `ynx-v2-node`、EVM JSON-RPC、REST/indexer/faucet 服务 | 主网级验证人多样性、SLO、灾备、安全审计 |
| wrapped 资产 | `wBTC.y`、`wETH.y`、`wBNB.y`、`wUSDT.y`、`wUSDC.y` 合约和 route | 9102 上的 `YNXBridgeGateway` + `YNXWrappedAsset` | 真实主网外部资产托管/赎回、治理和流动性 |
| Sepolia bridge | ETH/USDC 已完整闭环 | Sepolia `YNXSourceLockbox`、自动 deposit watcher、YNX mint、YNX burn watcher、Sepolia release | 更大金额测试、失败重放、监控、审计 |
| BTC/TRON bridge | manual proof 闭环 ready | operator 验证外链 tx 后提交 proof，YNX 铸币；burn 后 operator 记录外链 release proof | 自动 BTC/TRON watcher、MPC/签名策略、自动 release |
| BSC route | wrapped route ready；manual proof 闭环 ready | wBNB.y route 已部署，source chain 已配置 | 如果重新优先 BSC，需要 tBNB/BNB 资金和 source lockbox |
| 交易 | `wUSDC.y/YUSD.test`、`wETH.y/YUSD.test` 最小 AMM pilot | 测试 AMM 合约 + 小额初始流动性 | 深度、滑点、路由、风控、做市监控 |
| YUSD.test | 合成测试稳定资产可用 | 6 位 ERC-20 测试资产，用于交易、AI 支付、UX | 不可赎回；真实稳定币需要发行方/合规合作或明确保持测试资产 |
| AI Intelligence | `/ai/chat`、`/ai/intelligence/brief` 线上可用，服务器本地模型已接入 | AI Gateway 读取 bridge/Web4/AI 状态；服务器 Ollama `qwen2.5:1.5b`；官方 answer 用确定性事实生成 | 更强模型、检索增强、operator action、告警自动化 |
| AI settlement | vault/job/payment 和链上结算已实测 | AI Gateway + `YNXAISettlement` 合约 `0x87e8...2Fcf` | challenge/slash 治理、签名轮换、审计 |
| Web4 | policy、session、tool 授权、audit logs | Web4 Hub 根据 policy/session 限制授权 AI action | 用户级策略 UI、外部 SDK |
| 监控 | bridge full-loop 和 AI on-chain 定时探针 active | systemd timers：`ynx-public-bridge-full-loop.timer`、`ynx-public-ai-onchain.timer` | Pager/告警、SLO dashboard、事故 runbook |

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
- EVM 源链 lockbox 和 watcher；`Sepolia ETH + USDC 充值和提现均已上线并实测，BSC testnet 等待 BNB/tBNB 资金`
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
