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

## Public Testnet Quickstart

### 1) Public endpoints (no setup needed)

- Chain ID: `ynx_9002-1`
- RPC: `http://43.134.23.58:26657`
- EVM JSON-RPC: `http://43.134.23.58:8545`
- REST: `http://43.134.23.58:1317`
- Faucet: `http://43.134.23.58:8080`
- Explorer: `http://43.134.23.58:8082`

Check latest block height:

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.sync_info.latest_block_height'
```

Check EVM chain id:

```bash
curl -s http://43.134.23.58:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
```

Request faucet tokens:

```bash
curl -s "http://43.134.23.58:8080/faucet?address=<your_ynx1_address>"
```

### 2) Run your own node (copy/paste, Ubuntu 22.04+)

Install dependencies:

```bash
sudo apt update
sudo apt install -y git curl jq build-essential
```

Install Go (if missing):

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

Build `ynxd`:

```bash
cd ~
git clone https://github.com/JiahaoAlbus/YNX.git
cd ~/YNX/chain
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd
```

Download latest public testnet bundle:

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

Set seed/persistent peer:

```bash
PEER='e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656'
sed -i -E "s#^seeds = .*#seeds = \"$PEER\"#" ~/.ynx-testnet/config/config.toml
sed -i -E "s#^persistent_peers = .*#persistent_peers = \"$PEER\"#" ~/.ynx-testnet/config/config.toml
```

Start node:

```bash
cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt
```

Verify your node:

```bash
curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

### 3) One-command full health check

```bash
./chain/scripts/public_testnet_verify.sh
```

Validator onboarding docs:

- `docs/en/VALIDATOR_ONBOARDING_PACKAGE.md`
- `docs/en/PUBLIC_TESTNET_LAUNCHKIT.md`
