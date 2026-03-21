# YNX v2 验证节点加入手册（不进共识）

状态：active  
类型：对外手册  
最后更新：2026-03-21

## 1. 适用范围

本手册用于“只加入验证节点、不进入共识投票”的场景。

建议先完成本手册，再进入共识手册：

- `docs/zh/V2_共识验证人加入手册.md`

## 2. 服务器基线

建议最低配置：

- 4 vCPU
- 8 GB RAM
- 120 GB SSD
- Ubuntu 22.04+

建议开放入站 TCP：

- `22`（SSH）
- `36656`（P2P）
- `36657`（RPC，可选，尽量默认不公网开放）

## 3. 从零准备环境

```bash
sudo apt-get update -y
sudo apt-get install -y git curl jq build-essential ca-certificates
```

安装 Go（仅当你需要本机编译 `ynxd` 时）：

```bash
if ! command -v go >/dev/null 2>&1; then
  curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz -o /tmp/go1.23.6.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go1.23.6.tar.gz
  echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
  export PATH=/usr/local/go/bin:$PATH
fi
go version
```

## 4. 获取 YNX 代码

```bash
export YNX_REPO="$HOME/YNX"
if [ ! -d "$YNX_REPO/.git" ]; then
  git clone https://github.com/JiahaoAlbus/YNX.git "$YNX_REPO"
else
  cd "$YNX_REPO" && git pull --ff-only
fi
```

## 5. 引导节点 home

```bash
cd "$YNX_REPO/chain"
export YNX_HOME="$HOME/.ynx-v2-validator"
./scripts/v2_validator_bootstrap.sh \
  --descriptor https://indexer.ynxweb4.com/ynx/network-descriptor \
  --role validator \
  --home "$YNX_HOME" \
  --moniker <你的节点名> \
  --reset
```

RPC 回退方式：

```bash
cd "$YNX_REPO/chain"
export YNX_HOME="$HOME/.ynx-v2-validator"
./scripts/v2_validator_bootstrap.sh \
  --rpc https://rpc.ynxweb4.com \
  --role validator \
  --home "$YNX_HOME" \
  --moniker <你的节点名> \
  --reset
```

## 6. 启动节点（手动）

```bash
cd "$YNX_REPO/chain"
./ynxd start \
  --home "$YNX_HOME" \
  --chain-id ynx_9102-1 \
  --minimum-gas-prices 0.000000007anyxt
```

## 7. 可选：配置 systemd 常驻

```bash
cat <<EOF | sudo tee /etc/systemd/system/ynx-validator-node.service
[Unit]
Description=YNX v2 Validator Node (non-consensus)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$YNX_REPO/chain
ExecStart=$YNX_REPO/chain/ynxd start --home $YNX_HOME --chain-id ynx_9102-1 --minimum-gas-prices 0.000000007anyxt
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now ynx-validator-node
sudo systemctl status ynx-validator-node --no-pager
```

## 8. 验证同步状态

```bash
curl -s http://127.0.0.1:36657/status | jq -r '.result.node_info.network,.result.sync_info.latest_block_height,.result.sync_info.catching_up'
```

```bash
curl -s http://127.0.0.1:36657/net_info | jq '.result.n_peers'
```

预期：

- Chain ID = `ynx_9102-1`
- `catching_up` 最终变为 `false`
- peers > 0

## 9. 常见问题

### `./scripts/v2_validator_bootstrap.sh` 报 `go` 不存在

先安装 Go（第 3 步），或者指定预编译 `ynxd`：

```bash
export YNX_BIN=/usr/local/bin/ynxd
```

### 没有 peers

- 检查防火墙 `36656`
- 检查 `config.toml` 是否写入 seeds / persistent peers

### 节点反复重启

```bash
sudo journalctl -u ynx-validator-node -f --no-pager
```

## 10. 下一步：进入共识

节点同步完成后，继续执行：

- `docs/zh/V2_共识验证人加入手册.md`
