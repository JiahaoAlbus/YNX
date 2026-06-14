# YNX 公开资产状态

状态：active  
最后更新：2026-06-14
范围：公开测试网 `ynx_9102-1`

## 当前答案

现在 YNX 公开测试网当前可用的资产是：

| 资产 | 类型 | 单位 / 合约 | 状态 |
|---|---|---|---|
| `NYXT` | 原生 gas / staking / governance 资产 | base denom `anyxt`，18 位小数 | 已上线公开测试网 |
| `NYXT` | EVM ERC-20 系统合约 | `0x9416A8e0E635dF4452e05Bb0384dCfc58ff53E5B` | 已上线公开测试网 |
| `YUSD.test` | 合成测试稳定资产 | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172`，6 decimals | 已上线公开测试网；不可赎回 |

用户现在可以在公开测试网上转 `anyxt` / `NYXT`，并用于 gas、质押、治理、faucet 和 EVM 测试流程。

测试网资产没有主网价值。`YUSD.test` 不是 USDC、USDT、USD、电子货币、
银行存款或可赎回稳定币。它只是用于交易、跨链、AI 支付和 UX 测试的公开测试网合成单位。

4 个 bonded validators 当前在线，公开测试网验收脚本在当前托管环境中可以通过。

## 公开 wrapped asset route

公开测试网现在已经部署了第一批主流资产的 wrapped token 合约、bridge
gateway route，以及 bridge observer/relayer API。它们是公开测试网 wrapped
表示，不等于真实主网外部资产已经完成托管、可赎回或已有官方主网流动性。

Gateway：`0x3a2948da8f35b86dce1440ebfb56b8ae041cebfe`
Bridge service：`https://rpc.ynxweb4.com/bridge/*`

| 来源测试网资产 | Route | YNX wrapped token | 合约 | 小数位 | 公开测试网状态 |
|---|---|---|---|---:|---|
| BTC testnet BTC | `btc-testnet-btc` | `wBTC.y` | `0x1887Eb24feefB6538CBc2140B148ba831f313991` | 8 | 已通过 manual proof 完整闭环实测 |
| Sepolia ETH | `eth-sepolia-eth` | `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 | 已完成完整闭环实测：充值 + 提现释放 |
| BSC testnet BNB | `bnb-testnet-bnb` | `wBNB.y` | `0x1A4DC3435b6A090824765970521cb782262523Ef` | 18 | 已通过 manual proof 完整闭环实测 |
| TRON Shasta USDT | `tron-shasta-usdt` | `wUSDT.y` | `0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1` | 6 | 已通过 manual proof 完整闭环实测 |
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

BTC、BNB、TRON route 的 manual public-testnet full-loop 证据：

```text
BTC source proof:         0x2d4f3ac96c43828bed934bd8e376fff61a25c7711150a56895dcd759d1f9ce4d
YNX wBTC.y burn tx:       0xf9220fd505610668a724bb6ac40e4e17c992cbadb8764289ee57c072908739f8
BTC release proof:        0x5a6831822cf2c54a5583347abe96f9ff54893033bcdc23187610661426a5f210

BSC source proof:         0x631f4edabb7a8efed7248faf7dad91c39777bf25a136eac44eb4b08ac872fd31
YNX wBNB.y burn tx:       0xe13923bdcf6181b5e88f619c1e45f20e3d0f9e5e2d6f321d8223133e772ca208
BSC release proof:        0xf7d2c900390c1627c1de53d00bdbf0d0c2395383273ac279907df913d19342fe

TRON source proof:        0xd6ea9dc7777a5bb05ab47d610245c494a6c7b6686ff7e2ccb2b64037519767af
YNX wUSDT.y burn tx:      0x107d4d706672c7322d8ac66617aeb4076761e93844d46a7d88f3825e590bed3f
TRON release proof:       0xf02bc21e3b8522d784f67e2c17fbb26e91a7294f064957b7e5907b6372ce257c
```

当前 route readiness：

```text
GET /bridge/route-readiness
full_loop_tested: btc-testnet-btc, eth-sepolia-eth, bnb-testnet-bnb, tron-shasta-usdt, eth-sepolia-usdc
automatic_loop_ready: 需要 deposit address/source contract、BSC lockbox、测试网 release signer 全部配置
automatic_loop_observed: 当前最强的真实公开自动化证据主要集中在 Sepolia ETH 和 USDC
manual_loop_ready: none
mapped_route_only: none
```

截至 2026-06-14，公开 bridge readiness 应统一理解成：

- `5/5` routes `full_loop_tested`
- `4/5` routes `automatic_loop_ready`
- `2/5` routes 拥有最强的公开自动化实证：Sepolia ETH 和 Sepolia USDC
- `btc-testnet-btc`：automatic-ready，但公开自动化实证还偏少
- `tron-shasta-usdt`：automatic-ready，但公开自动化实证还偏少
- `bnb-testnet-bnb`：仍等待 BSC lockbox 部署和 testnet BNB 资金

full-loop-tested 证据链的意思是：

```text
外部测试网充值由 operator 验真
-> operator 调 /bridge/deposits/prove
-> bridge gateway 在 YNX 铸出 wrapped asset
-> 用户在 YNX burn wrapped asset
-> YNX burn watcher 排队提现
-> operator 在外部测试网释放资产，并用 /bridge/withdrawals/:id/mark-released 记录 release proof
```

这是 YNX 侧真实测试网审计链路，使用 operator-attested source proof 和
release 记录。Bridge service 现在已经实现 BTC testnet Blockstream watcher、
TRON Shasta TronGrid watcher、BSC testnet EVM lockbox 自动化路径，以及
测试网 signer-gated release adapter。某条 route 只有在 deposit address/contract、
必要的 lockbox、watcher scan、burn watcher、release signer 和 release cap 都
配置并健康时，才会被标记为 `automatic_loop_ready`。

尽调时必须强调：

- `automatic_loop_ready` 是配置和 adapter 就绪状态；
- 它强于纯 manual route，但弱于“已经多次公开观察到自动化闭环”；
- 投资人不应把 `automatic_loop_ready` 直接理解成 production-safe 或规模化已证明。

## 还没正式上线的能力

公开测试网现在还没有生产级真实主网 BTC、ETH、BNB、USDT、USDC 托管、赎回能力，也还没有官方交易流动性。

## 当前每个功能、实现方式和差距

| 功能区 | 现在能做什么 | 怎么实现 | 还差什么 |
|---|---|---|---|
| YNX L1 测试网 | 公链出块、EVM RPC、原生 `anyxt` gas、explorer/indexer/faucet | 腾讯云上的 `ynx-v2-node`、EVM JSON-RPC、REST/indexer/faucet 服务 | 主网级验证人多样性、SLO、灾备、安全审计 |
| wrapped 资产 | `wBTC.y`、`wETH.y`、`wBNB.y`、`wUSDT.y`、`wUSDC.y` 合约和 route | 9102 上的 `YNXBridgeGateway` + `YNXWrappedAsset` | 真实主网外部资产托管/赎回、治理和流动性 |
| Sepolia bridge | ETH/USDC 已完整闭环 | Sepolia `YNXSourceLockbox`、自动 deposit watcher、YNX mint、YNX burn watcher、Sepolia release | 更大金额测试、失败重放、监控、审计 |
| BTC/TRON bridge | manual evidence 已 full-loop-tested；自动 watcher/release adapter 已实现 | Blockstream/TronGrid watcher、YNX mint、YNX burn watcher、测试网 signer-gated release adapter | 配置线上 deposit address/contract/signer；生产级仍需 MPC/custody 策略 |
| BSC route | manual evidence 已 full-loop-tested；EVM lockbox 自动化路径已实现 | wBNB.y route 已部署，source chain 已配置；automatic PASS 需要 BSC testnet lockbox | 部署/配置 BSC testnet lockbox 和 source signer |
| 交易 | `wUSDC.y/YUSD.test`、`wETH.y/YUSD.test` 最小 AMM pilot；脚本支持继续 seed wBTC/wBNB/wUSDT 的 YUSD pair | 测试 AMM 合约 + 小额初始流动性 + AI quote/preflight/prepare/execute 检查 | 更深流动性、滑点、路由、风控、做市监控 |
| YUSD.test | 合成测试稳定资产可用 | 6 位 ERC-20 测试资产，用于交易、AI 支付、UX | 不可赎回；真实稳定币需要发行方/合规合作或明确保持测试资产 |
| AI Intelligence | `/ai/chat`、`/ai/intelligence/brief` 线上可用；`trade.execute` 是 protected action | AI Gateway 读取 bridge/Web4/AI 状态；quote/preflight/prepare 公开；execute 必须 Web4 policy/session + 测试网 agent signer | 更强模型、检索增强、告警自动化、未来 MPC/agent 授权 |
| AI settlement | vault/job/payment 和链上结算已实测 | AI Gateway + `YNXAISettlement` 合约 `0x87e8...2Fcf` | challenge/slash 治理、签名轮换、审计 |
| Web4 | policy、session、tool 授权、audit logs | Web4 Hub 根据 policy/session 限制授权 AI action | 用户级策略 UI、外部 SDK |
| 监控 | bridge full-loop 和 AI on-chain 定时探针 active | systemd timers：`ynx-public-bridge-full-loop.timer`、`ynx-public-ai-onchain.timer` | Pager/告警、SLO dashboard、事故 runbook |

## 公开测试网交易 pilot

公开测试网已有最小 AMM pilot，可用于测试 swap。这是测试证据，不足以支撑
“真实外部资产已经在 YNX 上普遍可交易”的对外说法：

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
