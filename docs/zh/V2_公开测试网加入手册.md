# YNX v2 公开测试网加入手册（Web4 赛道）

状态：active  
适用对象：体验用户、开发者、节点运营者、共识验证人候选者  
最后更新：2026-06-19

## 1. 手册目的

这是 YNX v2 公测网对外入口手册。

本页只负责帮助你选路径，完整步骤请进入对应手册。

## 1.1 如果你是从零开始（新机器直接打开本页）

干净 Linux 服务器最快路径：

```bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="$HOME/.local/bin:$PATH"
ynx join --role full-node
```

共识验证人候选路径：

```bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="$HOME/.local/bin:$PATH"
ynx join --role validator
```

当前公开测试网默认使用 state sync 加入。这是为了和现网状态兼容，新机器不再从旧 genesis 历史重放。

Windows 11 / 全新 Windows 机器路径：

1. 用**管理员身份**打开 PowerShell。
2. 执行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
irm https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx_windows.ps1 | iex
```

这个 Windows 安装器会做什么：

- 不会假装支持纯原生 Windows 节点，而是走 WSL2 + Ubuntu 的可信路径；
- 在 Ubuntu 内安装 `curl`、`git`、`jq`、`bash`；
- 在 WSL 里安装 YNX CLI；
- 额外执行 `ynx help` 和 `ynx join-plan --role full-node` 作为校验步骤。

边界说明：

- 对完全空白的 Windows 机器，第一次执行时可能会先触发 WSL / Ubuntu 安装，并要求重启，或者要求先完成 Ubuntu 首次用户名创建。
- 这些操作完成后，再执行一次上面的 PowerShell 命令，才能完成 YNX 安装。
- 当前我们只声明 **WSL 路线可用**；**不声明**原生非 WSL Windows 验证节点已支持。

手动备用路径：

```bash
sudo apt-get update -y
sudo apt-get install -y git curl jq build-essential ca-certificates
```

```bash
export YNX_REPO="$HOME/YNX"
if [ ! -d "$YNX_REPO/.git" ]; then
  git clone https://github.com/JiahaoAlbus/YNX.git "$YNX_REPO"
else
  cd "$YNX_REPO" && git pull --ff-only
fi
```

然后继续下面路径 A / B / C。

## 2. 网络基础信息

- 网络名：`YNX v2 Public Testnet (Web4 Track)`
- Cosmos Chain ID：`ynx_9102-1`
- EVM Chain ID：`0x238e`（十进制 `9102`）
- Denom：`anyxt`

公开端点：

- RPC：`https://rpc.ynxweb4.com`
- EVM RPC：`https://evm.ynxweb4.com`
- EVM WS：`wss://evm-ws.ynxweb4.com`
- REST：`https://rest.ynxweb4.com`
- Faucet：`https://faucet.ynxweb4.com`
- Indexer：`https://indexer.ynxweb4.com`
- Explorer：`https://explorer.ynxweb4.com`
- AI Gateway：`https://ai.ynxweb4.com`
- Web4 Hub：`https://web4.ynxweb4.com`

官方仓库：

- `https://github.com/JiahaoAlbus/YNX`

## 3. 先选路径

### 路径 A：普通用户 / 开发者（不需要服务器）

- 连接钱包
- 领取测试币
- 发第一笔交易
- 接入 EVM / RPC

快速检查：

```bash
curl -s https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network,.result.sync_info.latest_block_height'
```

```bash
curl -s -X POST https://evm.ynxweb4.com \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq
```

```bash
curl -s https://faucet.ynxweb4.com/health | jq
```

### 路径 B：加入验证节点（不进共识）

运行并同步节点，但不参与共识投票签名。

完整手册：

- `docs/zh/V2_验证节点加入手册.md`

### 路径 C：加入共识验证人（BONDED）

先有同步节点，再提交 `create-validator`，状态进入 `BOND_STATUS_BONDED`，参与投票签名。

完整手册：

- `docs/zh/V2_共识验证人加入手册.md`

## 4. 常见问题

### 这是主网吗？

不是。这是公开测试网，测试币不等于主网资产。

### “验证节点”和“共识验证人”区别是什么？

- 验证节点：只同步和转发链数据。
- 共识验证人：已 BONDED，参与出块投票签名。

### 能不能先跑节点再进共识？

可以，建议按这个顺序。

### 部署卡住了，能不能问 AI？

可以。公开入口：

- `https://www.ynxweb4.com/ai`

建议直接这样问：

```text
我正在一台全新的 [Linux/Windows] 机器上部署 YNX。
我执行了：<完整命令>
我预期：<预期结果>
我实际得到：<完整报错>
你只告诉我下一条命令，并说明这是本机环境问题、缺包问题，还是 YNX 侧问题。
```

边界：

- AI 页面是排障辅助入口，不等于保证所有部署问题都能自动修复。
- 验证节点和共识验证人加入，仍以本仓库手册和验证人手册为准。

## 5. 风险提示

- 公测网可能升级、重置或调参。
- 不要使用生产资产和生产密钥。
- 助记词/私钥必须离线保管。

## 6. 官方入口

- 仓库：`https://github.com/JiahaoAlbus/YNX`
- 浏览器：`https://explorer.ynxweb4.com`
- 网络概览：`https://indexer.ynxweb4.com/ynx/overview`
- AI 排障：`https://www.ynxweb4.com/ai`
