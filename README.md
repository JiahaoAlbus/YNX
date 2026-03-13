# YNX / NYXT

YNX is an AI-native Web4 execution chain with an EVM-first developer surface.  
NYXT is the native asset for gas, staking, and governance.

## Overview

- Sovereignty model: `owner > policy > session key`
- AI settlement plane: `/ai/*`
- Web4 control plane: `/web4/*`
- Operator-ready bootstrap, release bundle, and public node onboarding
- Public testnet track: `v2-web4`

## Canonical Docs

- Canonical technical specs and operator runbooks are English-first.
- Documentation index: `docs/en/INDEX.md`
- Core spec: `docs/en/YNX_v2_WEB4_SPEC.md`
- Execution plan: `docs/en/YNX_v2_EXECUTION_PLAN.md`
- Public testnet playbook: `docs/en/V2_PUBLIC_TESTNET_PLAYBOOK.md`

## v2 Web4 track (active)

- Track name: `v2-web4`
- Product direction: AI-native Web4 chain
- Delivery mode: new chain-id + new genesis + separate rollout from v1
- Core docs: `docs/en/YNX_v2_WEB4_SPEC.md`, `docs/en/YNX_v2_EXECUTION_PLAN.md`, `docs/en/YNX_v2_AI_SETTLEMENT_API.md`

## Public testnet endpoints

v2 Web4 public testnet (recommended):

- Chain ID: `ynx_9102-1`
- RPC: `http://43.134.23.58:36657`
- EVM RPC: `http://43.134.23.58:38545`
- REST: `http://43.134.23.58:31317`
- Faucet: `http://43.134.23.58:38080`
- Indexer: `http://43.134.23.58:38081`
- Explorer: `http://43.134.23.58:38082`
- AI Gateway: `http://43.134.23.58:38090`
- Web4 Hub: `http://43.134.23.58:38091`

For HTTPS websites (for example `https://ynxweb4.com`), do not call raw `http://IP:PORT` endpoints from browser code.
Use HTTPS subdomain gateway endpoints instead:

- `https://rpc.<your-domain>`
- `https://evm.<your-domain>`
- `https://faucet.<your-domain>`
- `https://indexer.<your-domain>`
- `https://explorer.<your-domain>`
- `https://ai.<your-domain>`
- `https://web4.<your-domain>`

Gateway setup script:

```bash
cd ~/YNX/chain
./scripts/install_v2_caddy_subdomain_gateway.sh <your-domain> <tls-email>
```

v1 public testnet (legacy track):

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

- AI-native Web4 chain: Ethereum-grade developer UX with high-performance execution targets.

Practical reasons to build on YNX:

- EVM-compatible developer flow with low-latency profile options.
- AI settlement lifecycle API (`/ai/*`) with vault-based machine payments.
- Machine-readable governance and positioning via `GET /ynx/overview`.
- Operator-ready bootstrap scripts for faster network scaling.
- Web4 sovereignty model: `owner > policy > session key`.

## Jump by need

- I only want to check chain status → [Path A](#path-a-no-install-check-chain)
- I want to deploy my own full node (beginner copy/paste) → [Path B](#path-b-deploy-your-own-full-node-ubuntu-2204)
- I have no Linux server and want Docker on my own machine → [Path K](#path-k-run-a-full-node-with-docker-macoslinux)
- I want to bootstrap full YNX v2 Web4 stack locally → [Path L](#path-l-build-and-run-ynx-v2-web4-locally)
- I want production-style v2 public testnet deployment → [Path M](#path-m-v2-public-testnet-deploy-to-server)
- I want a one-command v2 validator bootstrap (public join) → [Path N](#path-n-v2-validator-bootstrap-public-join)
- I want end-to-end v2 write smoke test (AI + Web4) → [Path O](#path-o-v2-api-write-smoke-test)
- I want v2 watchdog as systemd auto-start service → [Path P](#path-p-v2-watchdog-systemd-auto-start)
- I want local-only complete v2 buildout (no server) → [Path Q](#path-q-local-only-complete-v2-buildout-no-server)
- I want local multi-validator v2 simulation → [Path R](#path-r-local-multi-validator-v2-simulation)
- I want Docker Compose for the full local v2 stack → [Path S](#path-s-local-v2-stack-with-docker-compose)
- I want a company-ready local handoff package → [Path T](#path-t-company-ready-local-handoff-package)
- I need a wallet + faucet tokens → [Path C](#path-c-create-wallet-and-request-faucet)
- I need validator application data → [Path D](#path-d-validator-application-data)
- I need safe validator onboarding (sync first, then join) → [Path G](#path-g-safe-validator-onboarding-for-scale)
- I need one-command consensus profile switch (speed/stability) → [Path H](#path-h-consensus-profile-switch-speedstability)
- I need freeze/tag + watchdog automation → [Path I](#path-i-freezetag-and-watchdog-automation)
- I need centralized monitoring panel deploy → [Path J](#path-j-centralized-monitoring-panel)
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

## Path K: Run a full node with Docker (macOS/Linux)

If you do not have a Linux VPS yet, run a synced YNX full node in Docker locally:

```bash
cd ~/Desktop/YNX/chain
./scripts/public_testnet_docker_node.sh up --reset
```

Check status:

```bash
cd ~/Desktop/YNX/chain
./scripts/public_testnet_docker_node.sh status
```

Follow logs:

```bash
cd ~/Desktop/YNX/chain
./scripts/public_testnet_docker_node.sh logs
```

Stop node:

```bash
cd ~/Desktop/YNX/chain
./scripts/public_testnet_docker_node.sh down
```

## Path L: Build and run YNX v2 Web4 locally

Bootstrap v2 chain runtime:

```bash
cd ~/YNX/chain
./scripts/v2_testnet_bootstrap.sh --reset
```

Start full v2 local stack (`ynxd + faucet + indexer + explorer + ai-gateway + web4-hub`):

```bash
cd ~/YNX/chain
./scripts/v2_services_start.sh
```

Check v2 chain + AI endpoints:

```bash
curl -s http://127.0.0.1:36657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height'
curl -s http://127.0.0.1:38081/ynx/overview | jq
curl -s http://127.0.0.1:38090/health | jq
curl -s http://127.0.0.1:38090/ai/stats | jq
curl -s http://127.0.0.1:38091/web4/overview | jq
```

Stop v2 local stack:

```bash
cd ~/YNX/chain
./scripts/v2_services_stop.sh
```

## Path M: v2 public testnet deploy to server

Deploy full v2 stack to a Linux server:

```bash
cd ~/YNX/chain
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset
```

Run deploy + write smoke in one pass:

```bash
cd ~/YNX/chain
./scripts/v2_public_testnet_deploy.sh ubuntu@<SERVER_IP> /path/to/key.pem --reset --smoke-write
```

Optional strict mode (force policy/session for write APIs):

```bash
ssh -i /path/to/key.pem ubuntu@<SERVER_IP> "echo 'WEB4_ENFORCE_POLICY=1' | sudo tee -a /etc/ynx-v2/env && sudo systemctl restart ynx-v2-web4-hub"
```

Run post-deploy verification:

```bash
cd ~/YNX/chain
ssh -i /path/to/key.pem ubuntu@<SERVER_IP> 'cd ~/YNX/chain && YNX_PUBLIC_HOST=127.0.0.1 ./scripts/v2_public_testnet_verify.sh'
```

Build validator bootstrap package:

```bash
cd ~/YNX/chain
./scripts/v2_testnet_release.sh
```

## Path N: v2 validator bootstrap (public join)

Preferred bootstrap from the public network descriptor:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --descriptor http://<V2_INDEXER_IP>:38081/ynx/network-descriptor \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --reset
```

Direct RPC fallback:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --rpc http://<V2_RPC_IP>:36657 \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --seeds '<seed_node_id@seed_ip:36656>' \
  --reset
```

Start node immediately after bootstrap:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh --rpc http://<V2_RPC_IP>:36657 --start
```

## Path O: v2 API write smoke test

Run full write-path checks (AI job lifecycle + Web4 intent lifecycle):

```bash
cd ~/YNX/chain
YNX_PUBLIC_HOST=<V2_SERVER_IP> ./scripts/v2_public_testnet_smoke.sh
```

## Path P: v2 watchdog systemd auto-start

Install v2 watchdog as a long-running service:

```bash
cd ~/YNX/chain
./scripts/install_v2_watchdog_systemd.sh
```

Follow watchdog logs:

```bash
sudo journalctl -u ynx-v2-watchdog -f --no-pager
```

## Path Q: local-only complete v2 buildout (no server)

Run full local completion pipeline:

```bash
cd ~/YNX/chain
./scripts/v2_local_complete.sh all
```

This includes:

- bootstrap
- full stack start
- verify + smoke
- release package build
- company handoff bundle

## Path R: local multi-validator v2 simulation

Run local multi-validator simulation before public expansion:

```bash
cd ~/YNX/chain
YNX_VALIDATOR_COUNT=6 ./scripts/v2_local_complete.sh multinode
```

## Path S: local v2 stack with Docker Compose

Build the local Linux binary/image and start the full v2 stack with Compose:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_local_compose.sh up
```

Follow logs:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_local_compose.sh logs
```

Stop the Compose stack:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_local_compose.sh down
```

## Path T: company-ready local handoff package

Build the local package that is intended for later company-operated rollout:

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_company_pack.sh
```

Package contents:

- release artifacts
- canonical English docs
- OpenAPI contracts
- environment template
- orchestration scripts

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

## Path I: Freeze/tag and watchdog automation

Freeze current public testnet state and create a timestamped git tag:

```bash
cd ~/YNX/chain
./scripts/testnet_freeze_tag.sh
```

Push the freeze tag:

```bash
cd ~/YNX/chain
PUSH_TAG=1 ./scripts/testnet_freeze_tag.sh
```

Run continuous health watchdog (stdout alerts):

```bash
cd ~/YNX/chain
./scripts/testnet_watchdog.sh
```

Run watchdog with webhook alerting:

```bash
cd ~/YNX/chain
ALERT_WEBHOOK_URL="https://your-webhook-endpoint" ./scripts/testnet_watchdog.sh
```

Install watchdog as systemd service (auto-start):

```bash
cd ~/YNX/chain
./scripts/install_watchdog_systemd.sh
```

If a node has no local indexer, disable signed-check for that node:

```bash
cd ~/YNX/chain
INDEXER_URL= ./scripts/install_watchdog_systemd.sh
```

## Path J: Centralized monitoring panel

Deploy Prometheus + Grafana on monitor node and auto-open local tunnel:

```bash
cd ~/YNX/chain
./scripts/monitoring_stack_deploy.sh
```

After deployment:
- Grafana: `http://127.0.0.1:13000`
- Prometheus: `http://127.0.0.1:19090`

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
- v2 protocol spec: `docs/en/YNX_v2_WEB4_SPEC.md`
- v2 execution plan: `docs/en/YNX_v2_EXECUTION_PLAN.md`
- v2 AI settlement API: `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
- v2 Web4 API reference: `docs/en/YNX_v2_WEB4_API.md`
- v2 public testnet playbook: `docs/en/V2_PUBLIC_TESTNET_PLAYBOOK.md`
- v2 validator bootstrap: `docs/en/V2_VALIDATOR_BOOTSTRAP.md`
- v2 verify + smoke: `docs/en/V2_SMOKE_AND_VERIFY.md`
- v2 local complete runbook: `docs/en/V2_LOCAL_COMPLETE_RUNBOOK.md`
- v2 all files/functions map: `docs/en/V2_ALL_FILES_AND_FUNCTIONS.md`
- v2 current status + node onboarding: `docs/en/V2_WEB4_STATUS_AND_NODE_ONBOARDING.md`
- Web4 definition (EN): `docs/en/WEB4_FOR_YNX.md`
- v2 中文蓝图: `docs/zh/YNX_v2_WEB4_蓝图.md`
- v2 中文公测手册: `docs/zh/V2_公开测试网手册.md`
- Web4 定义（中文）: `docs/zh/WEB4_在YNX中的定义.md`
- v2 Web4 API（中文）: `docs/zh/YNX_v2_WEB4_API_接口说明.md`
- v2 本地完整开发手册（中文）: `docs/zh/V2_本地完整开发运行手册.md`
- v2 全部文件与功能说明（中文）: `docs/zh/V2_全部文件与功能说明.md`
- Mainnet parity & advantages: `docs/en/MAINNET_PARITY_AND_ADVANTAGES.md`
- Positioning (EN): `docs/en/YNX_POSITIONING.md`
- 定位与卖点（中文）: `docs/zh/YNX_定位与卖点.md`
- Releases 2 snapshot: `docs/en/RELEASES_2_CURRENT_STATUS.md`
- Next-step execution plan: `docs/en/OPEN_TESTNET_NEXT_STEPS.md`
- Validator recruitment post (EN+中文): `docs/en/VALIDATOR_RECRUITMENT_POST.md`

## Repo modules

- `chain/` — core chain (`ynxd`, modules, scripts, proto)
- `packages/contracts/` — contracts
- `packages/sdk/` — SDK/CLI helpers
- `infra/` — faucet, indexer, explorer, monitoring, ai-gateway
- `docs/` — docs and playbooks

## Security notes

- Never commit mnemonic/private keys.
- Never commit `.env`.
- Rotate any key that was exposed before.
