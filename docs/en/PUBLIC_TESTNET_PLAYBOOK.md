# YNX Public Testnet Playbook (EN)

Status: active  
Last updated: 2026-02-17

## Quick Navigation

- If you only want to check network status → [Path 0](#path-0-no-install-check-network)
- If you need a wallet address → [Path 1](#path-1-create-wallet-when-needed)
- If you need test tokens from faucet → [Path 2](#path-2-request-faucet-tokens)
- If you want to run a full node → [Path 3](#path-3-run-a-full-node)
- If you want to apply as validator → [Path 4](#path-4-validator-application-data)
- If you are running a production server → [Path 5](#path-5-operator-health-and-service-management)
- If something fails → [Troubleshooting](#troubleshooting)

## Network Constants

- Chain ID: `ynx_9002-1`
- EVM chain id (hex): `0x232a`
- Denom: `anyxt`
- Public RPC: `http://43.134.23.58:26657`
- Public EVM RPC: `http://43.134.23.58:8545`
- Public REST: `http://43.134.23.58:1317`
- Public Faucet: `http://43.134.23.58:8080`
- Public Explorer: `http://43.134.23.58:8082`
- Seed / peer bootstrap: `e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656`

## Path 0: No-install check network

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s http://43.134.23.58:8545 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
curl -s http://43.134.23.58:8080/health
```

Watch blocks in real time:

```bash
while true; do h=$(curl -s http://43.134.23.58:26657/status | jq -r .result.sync_info.latest_block_height); echo "$(date '+%F %T') height=$h"; sleep 1; done
```

## Path 1: Create wallet (when needed)

Use this only if you need faucet tokens, send txs, or validator ops.

```bash
cd ~/YNX/chain
./ynxd keys add wallet --keyring-backend os --key-type eth_secp256k1
./ynxd keys show wallet --keyring-backend os --bech acc -a
./ynxd debug addr $(./ynxd keys show wallet --keyring-backend os --bech acc -a)
```

## Path 2: Request faucet tokens

```bash
ADDR="<your_ynx1_address>"
curl -s "http://43.134.23.58:8080/faucet?address=${ADDR}"
curl -s "http://43.134.23.58:26657/abci_query?path=\"/cosmos.bank.v1beta1.Query/AllBalances\"&data=\"${ADDR}\""
```

Recommended balance check with local `ynxd`:

```bash
cd ~/YNX/chain
./ynxd query bank balances "$ADDR" --node http://43.134.23.58:26657 --output json
```

## Path 3: Run a full node

### 3.1 Install dependencies (Ubuntu 22.04+)

```bash
sudo apt update
sudo apt install -y git curl jq build-essential
```

### 3.2 Install Go (if missing)

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

### 3.3 Build binary

```bash
cd ~
git clone https://github.com/JiahaoAlbus/YNX.git
cd ~/YNX/chain
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd
```

### 3.4 Pull latest release bundle

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

### 3.5 Configure peers and start

```bash
PEER='e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656'
sed -i -E "s#^seeds = .*#seeds = \"$PEER\"#" ~/.ynx-testnet/config/config.toml
sed -i -E "s#^persistent_peers = .*#persistent_peers = \"$PEER\"#" ~/.ynx-testnet/config/config.toml

cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt
```

### 3.6 Verify your node

```bash
curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

## Path 4: Validator application data

Run your node first, then submit:

```bash
cd ~/YNX/chain
./ynxd keys add validator --keyring-backend os --key-type eth_secp256k1
./ynxd keys show validator --keyring-backend os --bech acc -a
./ynxd keys show validator --keyring-backend os --bech val -a
./ynxd comet show-node-id --home ~/.ynx-testnet
./ynxd comet show-validator --home ~/.ynx-testnet
```

Send to coordinator:

- `node_id@public_ip:26656`
- `ynxvaloper...`
- `ynx1...`
- region/provider/contact

## Path 5: Operator health and service management

One-command stack check:

```bash
cd ~/YNX
./chain/scripts/public_testnet_verify.sh
```

Server-local check:

```bash
YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh
```

Systemd status:

```bash
sudo systemctl status ynx-node ynx-faucet ynx-indexer ynx-explorer --no-pager
```

Live logs:

```bash
sudo journalctl -u ynx-node -f
```

## Troubleshooting

- `go: command not found` → re-run Go install, then `export PATH=/usr/local/go/bin:$PATH`.
- `gas prices too low` → increase sender gas price (example: `0.000001anyxt`).
- `account not found` → fund address from faucet first, then retry tx.
- `connection refused` from outside → check cloud security group / firewall open ports.
- `faucet ip_rate_limited` → wait for rate-limit window or use another IP.

## Related docs

- `docs/en/PUBLIC_TESTNET_LAUNCHKIT.md`
- `docs/en/VALIDATOR_ONBOARDING_PACKAGE.md`
