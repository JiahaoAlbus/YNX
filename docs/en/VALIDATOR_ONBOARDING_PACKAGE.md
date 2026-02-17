# YNX Validator Onboarding Package

Status: Active  
Last updated: 2026-02-17  
Canonical language: English

## 1. Network Parameters

- Chain ID: `ynx_9002-1`
- EVM Chain ID: `9002`
- Denom: `anyxt`
- Seed: `9edf41e71a5ba8bbc0a2b9026630bde1d56559c9@38.98.191.10:26656`
- RPC: `http://38.98.191.10:26657`
- JSON-RPC: `http://38.98.191.10:8545`
- Faucet: `http://38.98.191.10:8080`

Release assets:
- `https://github.com/JiahaoAlbus/YNX/releases/tag/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z`

## 2. Minimum Host Spec

Full node:
- 2 vCPU
- 4 GB RAM
- 100 GB SSD

Validator:
- 4 vCPU
- 8 GB RAM
- 200 GB SSD
- Stable public IP and low packet loss

## 3. Open Ports

- `26656/tcp` P2P
- `26657/tcp` RPC (optional for validator, required for public RPC nodes)
- `8545/tcp` JSON-RPC (only if this node is a public RPC node)

## 4. Install and Bootstrap Node

```bash
cd ~
git clone https://github.com/JiahaoAlbus/YNX.git
cd YNX/chain
go build -o ynxd ./cmd/ynxd
```

```bash
mkdir -p ~/.ynx-testnet/config
curl -L -o /tmp/ynx_bundle.tar.gz \
  https://github.com/JiahaoAlbus/YNX/releases/download/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z/ynx_testnet_ynx_9002-1_20260217T070016Z.tar.gz
curl -L -o /tmp/ynx_bundle.sha256 \
  https://github.com/JiahaoAlbus/YNX/releases/download/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z/ynx_testnet_ynx_9002-1_20260217T070016Z.sha256
shasum -a 256 -c /tmp/ynx_bundle.sha256
tar -xzf /tmp/ynx_bundle.tar.gz -C /tmp/ynx_bundle
cp /tmp/ynx_bundle/genesis.json ~/.ynx-testnet/config/genesis.json
cp /tmp/ynx_bundle/config.toml ~/.ynx-testnet/config/config.toml
cp /tmp/ynx_bundle/app.toml ~/.ynx-testnet/config/app.toml
```

Update `~/.ynx-testnet/config/config.toml`:
- `seeds = "9edf41e71a5ba8bbc0a2b9026630bde1d56559c9@38.98.191.10:26656"`
- `persistent_peers = "9edf41e71a5ba8bbc0a2b9026630bde1d56559c9@38.98.191.10:26656"`

Start node:

```bash
cd ~/YNX/chain
./ynxd start --home ~/.ynx-testnet --minimum-gas-prices 0anyxt
```

## 5. Validator Registration

Create operator key:

```bash
cd ~/YNX/chain
./ynxd keys add validator --keyring-backend os --key-type eth_secp256k1
```

Get addresses:

```bash
./ynxd keys show validator --keyring-backend os --bech acc -a
./ynxd keys show validator --keyring-backend os --bech val -a
```

Get consensus pubkey:

```bash
./ynxd comet show-validator --home ~/.ynx-testnet
```

Create `validator.json` and submit:

```json
{
  "pubkey": {"@type":"/cosmos.crypto.ed25519.PubKey","key":"REPLACE_WITH_OUTPUT_FROM_SHOW_VALIDATOR"},
  "amount": "1000000000000000000anyxt",
  "moniker": "ynx-validator",
  "identity": "",
  "website": "",
  "security": "",
  "details": "",
  "commission-rate": "0.10",
  "commission-max-rate": "0.20",
  "commission-max-change-rate": "0.01",
  "min-self-delegation": "1"
}
```

```bash
./ynxd tx staking create-validator ./validator.json \
  --chain-id ynx_9002-1 \
  --node http://38.98.191.10:26657 \
  --from validator \
  --keyring-backend os \
  --gas auto --gas-adjustment 1.2 --gas-prices 0.00000001anyxt \
  --yes
```

## 6. Required Submission to Coordinator

Send all of the following:
- Node moniker
- Node ID (`./ynxd comet show-node-id --home ~/.ynx-testnet`)
- P2P endpoint (`node_id@public_ip:26656`)
- Validator operator address (`ynxvaloper1...`)
- Validator account address (`ynx1...`)
- Country/region + hosting provider
- Security contact email
- Uptime commitment

## 7. Post-Join Validation

```bash
curl -s http://38.98.191.10:26657/status
./ynxd query staking validators --node http://38.98.191.10:26657
./ynxd query staking validator "$(./ynxd keys show validator --keyring-backend os --bech val -a)" --node http://38.98.191.10:26657
```
