# YNX 公测网完整上手手册（中文）

状态：active  
最后更新：2026-02-17

## 快速导航（按需求点击）

- 只想看链是否正常 → [路径 0](#路径-0不安装直接查看网络)
- 需要钱包地址 → [路径 1](#路径-1需要时再创建钱包)
- 需要领测试币 → [路径 2](#路径-2从-faucet-领取测试币)
- 想自己跑全节点 → [路径 3](#路径-3运行全节点)
- 想申请验证人 → [路径 4](#路径-4验证人申请需要的数据)
- 你是运维节点的人 → [路径 5](#路径-5运维健康检查与服务管理)
- 命令报错了 → [故障排查](#故障排查)

## 网络固定参数

- Chain ID：`ynx_9002-1`
- EVM Chain ID（hex）：`0x232a`
- Denom：`anyxt`
- 公网 RPC：`http://43.134.23.58:26657`
- 公网 EVM RPC：`http://43.134.23.58:8545`
- 公网 REST：`http://43.134.23.58:1317`
- Faucet：`http://43.134.23.58:8080`
- Explorer：`http://43.134.23.58:8082`
- Seed/Peer 引导：`e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656`

## 路径 0：不安装，直接查看网络

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s http://43.134.23.58:8545 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
curl -s http://43.134.23.58:8080/health
curl -s http://43.134.23.58:8081/ynx/overview | jq
```

实时看出块：

```bash
while true; do h=$(curl -s http://43.134.23.58:26657/status | jq -r .result.sync_info.latest_block_height); echo "$(date '+%F %T') height=$h"; sleep 1; done
```

## 路径 1：需要时再创建钱包

仅当你要领水、发交易、做验证人时才需要钱包。

```bash
cd ~/YNX/chain
./ynxd keys add wallet --keyring-backend os --key-type eth_secp256k1
./ynxd keys show wallet --keyring-backend os --bech acc -a
./ynxd debug addr $(./ynxd keys show wallet --keyring-backend os --bech acc -a)
```

## 路径 2：从 Faucet 领取测试币

```bash
ADDR="<你的ynx1地址>"
curl -s "http://43.134.23.58:8080/faucet?address=${ADDR}"
```

查余额（推荐）：

```bash
cd ~/YNX/chain
./ynxd query bank balances "$ADDR" --node http://43.134.23.58:26657 --output json
```

## 路径 3：运行全节点

### 3.1 安装依赖（Ubuntu 22.04+）

```bash
sudo apt update
sudo apt install -y git curl jq build-essential
```

### 3.2 安装 Go（如果没有）

```bash
if ! command -v go >/dev/null 2>&1; then
  curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
  export PATH=/usr/local/go/bin:$PATH
fi
go version
```

### 3.3 编译 `ynxd`

```bash
cd ~
git clone https://github.com/JiahaoAlbus/YNX.git
cd ~/YNX/chain
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd
```

### 3.4 下载最新公测网配置包

```bash
REL_API="https://api.github.com/repos/JiahaoAlbus/YNX/releases/latest"
BUNDLE_URL="$(curl -fsSL "$REL_API" | jq -r '.assets[] | select(.name|endswith(".tar.gz")) | .browser_download_url' | head -n1)"
SHA_URL="$(curl -fsSL "$REL_API" | jq -r '.assets[] | select(.name|endswith(".sha256")) | .browser_download_url' | head -n1)"

mkdir -p ~/.ynx-testnet/config /tmp/ynx_bundle
curl -fL "$BUNDLE_URL" -o /tmp/ynx_bundle.tar.gz
curl -fL "$SHA_URL" -o /tmp/ynx_bundle.sha256
(cd /tmp && shasum -a 256 -c ynx_bundle.sha256)
tar -xzf /tmp/ynx_bundle.tar.gz -C /tmp/ynx_bundle
cp /tmp/ynx_bundle/genesis.json ~/.ynx-testnet/config/genesis.json
cp /tmp/ynx_bundle/config.toml ~/.ynx-testnet/config/config.toml
cp /tmp/ynx_bundle/app.toml ~/.ynx-testnet/config/app.toml
```

### 3.5 配置 Peer 并启动

```bash
PEER='e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656'
sed -i -E "s#^seeds = .*#seeds = \"$PEER\"#" ~/.ynx-testnet/config/config.toml
sed -i -E "s#^persistent_peers = .*#persistent_peers = \"$PEER\"#" ~/.ynx-testnet/config/config.toml

cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt
```

### 3.6 验证同步

```bash
curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

## 路径 4：验证人申请需要的数据

先把节点跑起来，然后执行：

```bash
cd ~/YNX/chain
./ynxd keys add validator --keyring-backend os --key-type eth_secp256k1
./ynxd keys show validator --keyring-backend os --bech acc -a
./ynxd keys show validator --keyring-backend os --bech val -a
./ynxd comet show-node-id --home ~/.ynx-testnet
./ynxd comet show-validator --home ~/.ynx-testnet
```

提交给协调方：

- `node_id@公网IP:26656`
- `ynxvaloper...`
- `ynx1...`
- 地区/服务商/联系方式

## 路径 5：运维健康检查与服务管理

一条命令全检查：

```bash
cd ~/YNX
./chain/scripts/public_testnet_verify.sh
```

服务器本机检查：

```bash
YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh
```

systemd 状态：

```bash
sudo systemctl status ynx-node ynx-faucet ynx-indexer ynx-explorer --no-pager
```

实时日志：

```bash
sudo journalctl -u ynx-node -f
```

受控升级（默认不自动从 Git 更新）：

```bash
cd ~/YNX
./chain/scripts/server_upgrade_apply.sh ubuntu@43.134.23.58 /Users/huangjiahao/Downloads/Huang.pem
```

## 故障排查

- `go: command not found`：重新安装 Go，并 `export PATH=/usr/local/go/bin:$PATH`。
- `gas prices too low`：发交易时提高 gas price（例如 `0.000001anyxt`）。
- `account not found`：先领水/转账到该地址，再发交易。
- 外网访问 `connection refused/timeout`：检查云防火墙和安全组端口。
- `faucet ip_rate_limited`：触发限流，等待窗口结束或换来源 IP。

## 相关文档

- `docs/en/PUBLIC_TESTNET_LAUNCHKIT.md`
- `docs/en/VALIDATOR_ONBOARDING_PACKAGE.md`
