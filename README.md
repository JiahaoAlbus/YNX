# YNX / NYXT

YNX is an open, EVM-compatible chain.  
NYXT is the native token for gas, staking, and governance.

## Public testnet endpoints

- Chain ID: `ynx_9002-1`
- RPC: `http://43.134.23.58:26657`
- EVM RPC: `http://43.134.23.58:8545`
- REST: `http://43.134.23.58:1317`
- Faucet: `http://43.134.23.58:8080`
- Explorer: `http://43.134.23.58:8082`
- Peer bootstrap: `e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656`

Mainnet-parity note:

- Public testnet targets the same protocol logic as planned mainnet.
- Primary difference is economic value (test assets vs real-value assets).

## Why choose YNX

YNX positioning:

- Governance-native EVM chain for real Web3 services.

Practical reasons to build on YNX:

- Mainnet-parity testnet workflow: what you test is what you launch.
- Governance and fee-routing transparency: machine-readable via `GET /ynx/overview`.
- Fast builder onboarding: copy/paste deployment playbooks and one-command verification.
- Open validator growth: rolling onboarding model for progressive decentralization.

## Jump by need

- I only want to check chain status → [Path A](#path-a-no-install-check-chain)
- I want to deploy my own full node (beginner copy/paste) → [Path B](#path-b-deploy-your-own-full-node-ubuntu-2204)
- I need a wallet + faucet tokens → [Path C](#path-c-create-wallet-and-request-faucet)
- I need validator application data → [Path D](#path-d-validator-application-data)
- I need safe validator onboarding (sync first, then join) → [Path G](#path-g-safe-validator-onboarding-for-scale)
- I need one-command consensus profile switch (speed/stability) → [Path H](#path-h-consensus-profile-switch-speedstability)
- I need one-command health verification → [Path E](#path-e-operator-health-check)
- I need upgrade/deploy to server safely → [Path F](#path-f-server-upgrade-deploy)

## Do I need to create a wallet first?

- Only query RPC / run non-validator full node: **No**
- Faucet / send tx / validator operations: **Yes**

## Path A: No install, check chain

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s http://43.134.23.58:8545 -H 'content-type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
curl -s http://43.134.23.58:8080/health
curl -s http://43.134.23.58:8081/ynx/overview | jq
curl -s http://43.134.23.58:8081/validators | jq '.latest_height, .total, .signed_count'
```

Watch blocks in real time:

```bash
while true; do h=$(curl -s http://43.134.23.58:26657/status | jq -r .result.sync_info.latest_block_height); echo "$(date '+%F %T') height=$h"; sleep 1; done
```

## Path B: Deploy your own full node (Ubuntu 22.04+)

Copy and run once:

```bash
cat <<'BASH' >/tmp/ynx_fullnode_bootstrap.sh
#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y git curl jq build-essential

if ! command -v go >/dev/null 2>&1; then
  curl -fsSL https://go.dev/dl/go1.23.6.linux-amd64.tar.gz -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
fi
export PATH=/usr/local/go/bin:$PATH
grep -q '/usr/local/go/bin' ~/.bashrc || echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc

if [ ! -d "$HOME/YNX/.git" ]; then
  git clone https://github.com/JiahaoAlbus/YNX.git "$HOME/YNX"
fi
cd "$HOME/YNX"
git pull --ff-only || true

cd "$HOME/YNX/chain"
CGO_ENABLED=0 go build -o ynxd ./cmd/ynxd

REL_API="https://api.github.com/repos/JiahaoAlbus/YNX/releases/latest"
BUNDLE_URL="$(curl -fsSL "$REL_API" | jq -r '.assets[] | select(.name|endswith(".tar.gz")) | .browser_download_url' | head -n1)"
SHA_URL="$(curl -fsSL "$REL_API" | jq -r '.assets[] | select(.name|endswith(".sha256")) | .browser_download_url' | head -n1)"

mkdir -p "$HOME/.ynx-testnet/config" /tmp/ynx_bundle
curl -fL "$BUNDLE_URL" -o /tmp/ynx_bundle.tar.gz
curl -fL "$SHA_URL" -o /tmp/ynx_bundle.sha256
(cd /tmp && shasum -a 256 -c ynx_bundle.sha256)
tar -xzf /tmp/ynx_bundle.tar.gz -C /tmp/ynx_bundle

cp /tmp/ynx_bundle/genesis.json "$HOME/.ynx-testnet/config/genesis.json"
cp /tmp/ynx_bundle/config.toml "$HOME/.ynx-testnet/config/config.toml"
cp /tmp/ynx_bundle/app.toml "$HOME/.ynx-testnet/config/app.toml"

PEER='e09b8e3fb963e7bd634520778846de6daaea4be6@43.134.23.58:26656'
sed -i -E "s#^seeds = .*#seeds = \"$PEER\"#" "$HOME/.ynx-testnet/config/config.toml"
sed -i -E "s#^persistent_peers = .*#persistent_peers = \"$PEER\"#" "$HOME/.ynx-testnet/config/config.toml"

echo "Bootstrap complete."
echo "Start node with:"
echo "cd $HOME/YNX/chain && ./ynxd start --home $HOME/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt"
BASH

bash /tmp/ynx_fullnode_bootstrap.sh
```

Start node:

```bash
cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --chain-id ynx_9002-1 --minimum-gas-prices 0anyxt
```

Verify local node:

```bash
curl -s http://127.0.0.1:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

## Path C: Create wallet and request faucet

```bash
cd ~/YNX/chain
./ynxd keys add wallet --keyring-backend os --key-type eth_secp256k1
ADDR=$(./ynxd keys show wallet --keyring-backend os --bech acc -a)
echo "$ADDR"
curl -s "http://43.134.23.58:8080/faucet?address=$ADDR"
./ynxd query bank balances "$ADDR" --node http://43.134.23.58:26657 --output json
```

## Path D: Validator application data

```bash
cd ~/YNX/chain
./ynxd keys add validator --keyring-backend os --key-type eth_secp256k1
./ynxd keys show validator --keyring-backend os --bech acc -a
./ynxd keys show validator --keyring-backend os --bech val -a
./ynxd comet show-node-id --home ~/.ynx-testnet
./ynxd comet show-validator --home ~/.ynx-testnet
```

Submit:

- `node_id@public_ip:26656`
- `ynxvaloper...`
- `ynx1...`
- region/provider/contact

## Path G: Safe validator onboarding (for scale)

Use this flow for adding many validators without repeatedly hitting `jailed/unbonding`.

Rule:
- Do **not** create-validator before local node is fully synced (`catching_up=false`).

Run:

```bash
cd ~/YNX/chain
./scripts/validator_onboard_safe.sh
```

Common production usage:

```bash
cd ~/YNX/chain
YNX_HOME=/root/.ynx-testnet2 \
YNX_KEY_NAME=validator2 \
YNX_KEYRING=test \
YNX_MONIKER=ynx-public-sg-2 \
YNX_NODE_RPC=http://43.134.23.58:26657 \
YNX_LOCAL_RPC=http://127.0.0.1:26657 \
./scripts/validator_onboard_safe.sh
```

What it enforces automatically:
- Waits until local sync completes.
- Verifies validator account is funded.
- Sends create-validator only after checks pass.
- Waits until validator becomes `BOND_STATUS_BONDED`.

## Path H: Consensus profile switch (speed/stability)

Use a profile to quickly switch between stable cross-continent settings and fast settings.

Profiles:
- `stable-fast` → `1s / 500ms / 1s`
- `cross-continent-safe` → `3s / 2s / 5s`

Local example:

```bash
cd ~/YNX/chain
./scripts/consensus_profile_apply.sh stable-fast
```

Server examples:

```bash
# node 1
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.134.23.58 \
'cd ~/YNX/chain && YNX_HOME=/home/ubuntu/.ynx-testnet YNX_SERVICE=ynx-node sudo -E ./scripts/consensus_profile_apply.sh stable-fast --restart'

# node 2
ssh -i ~/.ssh/ynx_tmp_key root@43.162.100.54 \
'cd /root/YNX/chain && YNX_HOME=/root/.ynx-testnet2 YNX_SERVICE=ynx-node2 ./scripts/consensus_profile_apply.sh stable-fast --restart'
```

Cluster one-command (apply both nodes + auto verify signed rate):

```bash
cd ~/YNX/chain
./scripts/consensus_profile_cluster_apply.sh stable-fast
```

## Path E: Operator health check

```bash
cd ~/YNX
./chain/scripts/public_testnet_verify.sh
```

On server local loopback:

```bash
YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh
```

## Path F: Server upgrade deploy

By default, server is **not** auto-updated from Git.  
Use controlled rollout with pull/build/restart/verify:

```bash
cd ~/YNX
./chain/scripts/server_upgrade_apply.sh ubuntu@43.134.23.58 /Users/huangjiahao/Downloads/Huang.pem
```

This script will:

- pull latest code
- rebuild `ynxd`
- restart `ynx-node` / `ynx-faucet` / `ynx-indexer` / `ynx-explorer`
- run full verification

## Full guides (3 languages)

- English: `docs/en/PUBLIC_TESTNET_PLAYBOOK.md`
- 中文: `docs/zh/PUBLIC_TESTNET_PLAYBOOK.md`
- Slovensky: `docs/sk/PUBLIC_TESTNET_PLAYBOOK.md`
- Mainnet parity & advantages: `docs/en/MAINNET_PARITY_AND_ADVANTAGES.md`
- Positioning (EN): `docs/en/YNX_POSITIONING.md`
- 定位与卖点（中文）: `docs/zh/YNX_定位与卖点.md`
- Releases 2 snapshot: `docs/en/RELEASES_2_CURRENT_STATUS.md`

## Repo modules

- `chain/` — core chain (`ynxd`, modules, scripts, proto)
- `packages/contracts/` — contracts
- `packages/sdk/` — SDK/CLI helpers
- `infra/` — faucet, indexer, explorer, monitoring
- `docs/` — docs and playbooks

## Security notes

- Never commit mnemonic/private keys.
- Never commit `.env`.
- Rotate any key that was exposed before.
