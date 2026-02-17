# YNX / NYXT

YNX is a permissionless, EVM-compatible network targeting **sub-second user experience** (via preconfirmations) while preserving **open participation** and **fully on-chain governance**. NYXT is the native token (gas, staking, governance).

This repository contains:

- v0 protocol specs (canonical)
- v0 reference implementation (system contracts + SDK)
- base-chain MVP (`ynxd`) built on Cosmos SDK + Cosmos EVM

## Canonical Docs (English)

- `docs/en/INDEX.md` (start here)

## v0 Parameters (Locked)

- UX confirmation (preconfirm): **≤ 1s**
- Finality target: **5–8s**
- Execution: **EVM-compatible**, **gas** fee model
- Token: **NYXT**
- Genesis supply: **100,000,000,000 NYXT**
- Inflation: **2% / year** (70% validators+delegators, 30% treasury)
- Fee split: **40% burn / 40% validators / 10% treasury / 10% founder**
- Team allocation: **15%**, **1y cliff + 4y linear vesting** (on-chain, public)
- Treasury (genesis reserve): **40%** (spend via on-chain governance)
- Governance: proposer stake **1,000,000 NYXT**, deposit **100,000 NYXT**, voting **7d**, timelock **7d**

## Quickstart

```bash
npm install
npm test
```

Devnet:

```bash
# YNX chain devnet (node + JSON-RPC)
(cd chain && ./scripts/localnet.sh --reset)

# terminal 1
npm --workspace @ynx/contracts run devnet:node

# terminal 2
npm --workspace @ynx/contracts run devnet:deploy
```

YN address CLI:

```bash
npx ynx address encode 0x0000000000000000000000000000000000000000
npx ynx address decode <YN...>

# Preconfirm receipt verification (v0)
npx ynx preconfirm verify 0x<txHash> --rpc http://127.0.0.1:8545
```

## Public Testnet (Beginner Friendly)

### Choose your language

- English: `docs/en/PUBLIC_TESTNET_PLAYBOOK.md`
- 中文: `docs/zh/PUBLIC_TESTNET_PLAYBOOK.md`
- Slovensky: `docs/sk/PUBLIC_TESTNET_PLAYBOOK.md`

### Network

- Chain ID: `ynx_9002-1`
- RPC: `http://43.134.23.58:26657`
- EVM JSON-RPC: `http://43.134.23.58:8545`
- REST: `http://43.134.23.58:1317`
- Faucet: `http://43.134.23.58:8080`
- Explorer: `http://43.134.23.58:8082`

### Do I need to create a wallet?

- **Read/query only (check blocks, call RPC): NO**
- **Run a full node only (non-validator): NO**
- **Use faucet / send tx / become validator: YES**

### A) Quick check only (no install, no wallet)

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.sync_info.latest_block_height'
curl -s http://43.134.23.58:8545 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

### B) Run your own full node (Ubuntu 22.04+, no wallet required)

1) Install dependencies

```bash
sudo apt update
sudo apt install -y git curl jq build-essential
```

2) Install Go

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

3) Build binary

```bash
cd ~
git clone https://github.com/JiahaoAlbus/YNX.git
cd ~/YNX/chain
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd
```

4) Download latest testnet config bundle

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

5) Set peer and start

```bash
PEER='e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656'
sed -i -E "s#^seeds = .*#seeds = \"$PEER\"#" ~/.ynx-testnet/config/config.toml
sed -i -E "s#^persistent_peers = .*#persistent_peers = \"$PEER\"#" ~/.ynx-testnet/config/config.toml

cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt
```

6) Verify sync

```bash
curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

### C) Create wallet only when you need transactions/faucet/validator

```bash
cd ~/YNX/chain
./ynxd keys add wallet --keyring-backend os --key-type eth_secp256k1
./ynxd keys show wallet --keyring-backend os --bech acc -a
```

Faucet request:

```bash
curl -s "http://43.134.23.58:8080/faucet?address=<your_ynx1_address>"
```

### D) One-command full health check (for operators)

```bash
./chain/scripts/public_testnet_verify.sh
```

More docs:

- `docs/en/VALIDATOR_ONBOARDING_PACKAGE.md`
- `docs/en/PUBLIC_TESTNET_LAUNCHKIT.md`
