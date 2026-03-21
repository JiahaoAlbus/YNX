# YNX v2 Validator Node Join Guide (Non-Consensus)

Status: active  
Type: external manual  
Last updated: 2026-03-21

## 1. Scope

This manual is for operators who want to run a YNX validator node that syncs the network but does not yet join consensus voting.

Use this first, then move to the consensus manual later:

- `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`

## 2. Server baseline

Recommended minimum:

- 4 vCPU
- 8 GB RAM
- 120 GB SSD
- Ubuntu 22.04+

Open inbound TCP ports:

- `22` (SSH)
- `36656` (P2P)
- `36657` (RPC, optional; keep private unless needed)

## 3. Prepare environment from zero

```bash
sudo apt-get update -y
sudo apt-get install -y git curl jq build-essential ca-certificates
```

Install Go (required only if you will build `ynxd` locally):

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

## 4. Get YNX source code

```bash
export YNX_REPO="$HOME/YNX"
if [ ! -d "$YNX_REPO/.git" ]; then
  git clone https://github.com/JiahaoAlbus/YNX.git "$YNX_REPO"
else
  cd "$YNX_REPO" && git pull --ff-only
fi
```

## 5. Bootstrap node home

```bash
cd "$YNX_REPO/chain"
export YNX_HOME="$HOME/.ynx-v2-validator"
./scripts/v2_validator_bootstrap.sh \
  --descriptor https://indexer.ynxweb4.com/ynx/network-descriptor \
  --role validator \
  --home "$YNX_HOME" \
  --moniker <YOUR_MONIKER> \
  --reset
```

RPC fallback:

```bash
cd "$YNX_REPO/chain"
export YNX_HOME="$HOME/.ynx-v2-validator"
./scripts/v2_validator_bootstrap.sh \
  --rpc https://rpc.ynxweb4.com \
  --role validator \
  --home "$YNX_HOME" \
  --moniker <YOUR_MONIKER> \
  --reset
```

## 6. Start node (manual)

```bash
cd "$YNX_REPO/chain"
./ynxd start \
  --home "$YNX_HOME" \
  --chain-id ynx_9102-1 \
  --minimum-gas-prices 0.000000007anyxt
```

## 7. Optional: run as systemd service

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

## 8. Verify sync and health

```bash
curl -s http://127.0.0.1:36657/status | jq -r '.result.node_info.network,.result.sync_info.latest_block_height,.result.sync_info.catching_up'
```

```bash
curl -s http://127.0.0.1:36657/net_info | jq '.result.n_peers'
```

Expected:

- Chain ID = `ynx_9102-1`
- `catching_up` eventually becomes `false`
- peer count > 0

## 9. Troubleshooting

### `./scripts/v2_validator_bootstrap.sh` fails because `go` is missing

Install Go (step 3) or provide prebuilt binary:

```bash
export YNX_BIN=/usr/local/bin/ynxd
```

### No peers

- Re-check firewall for `36656`
- Ensure seed/persistent peers were written into `config.toml`

### Node keeps restarting

```bash
sudo journalctl -u ynx-validator-node -f --no-pager
```

## 10. Next step (join consensus)

After your node is fully synced, continue here:

- `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`
