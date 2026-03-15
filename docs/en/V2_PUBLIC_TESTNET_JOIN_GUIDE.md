# YNX v2 Public Testnet Join Guide (Web4 Track)

Status: active  
Audience: public users, builders, and external validators  
Last updated: 2026-03-14

## 1. What this guide is for

This is the external join guide for YNX v2 public testnet.

Use this page if you want to:

- connect a wallet,
- get test tokens,
- send a first transaction,
- build against YNX endpoints,
- join as a validator.

This guide intentionally excludes internal operator deployment runbooks.

## 2. Network basics

- Network name: `YNX v2 Public Testnet (Web4 Track)`
- Cosmos Chain ID: `ynx_9102-1`
- EVM Chain ID: `0x238e` (decimal `9102`)
- Denom: `anyxt`

Public endpoints:

- RPC: `https://rpc.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- EVM WS: `wss://evm-ws.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`

Official repository:

- `https://github.com/JiahaoAlbus/YNX`

## 3. Quick start (non-technical)

1. Install a wallet that supports custom EVM/Cosmos networks.
2. Add YNX testnet with the values above.
3. Open faucet and request `anyxt`.
4. Send a small test transaction.
5. Open explorer and verify your transaction hash.

## 4. Builder quick start

Use these endpoints first:

- EVM JSON-RPC: `https://evm.ynxweb4.com`
- RPC status: `https://rpc.ynxweb4.com/status`
- Network overview: `https://indexer.ynxweb4.com/ynx/overview`

Minimal check examples:

```bash
curl -s https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network'
```

```bash
curl -s -X POST https://evm.ynxweb4.com \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq
```

```bash
curl -s https://faucet.ynxweb4.com/health | jq
```

## 5. Validator join (public)

Minimum suggested server:

- 4 vCPU
- 8 GB RAM
- 120 GB SSD
- Ubuntu 22.04+

Open inbound TCP ports:

- `22`
- `36656` (P2P)
- `36657` (RPC, optional public)

Clean-server prerequisites (required once):

```bash
sudo apt-get update -y
sudo apt-get install -y git curl jq build-essential ca-certificates
```

```bash
if [ ! -d "$HOME/YNX/.git" ]; then
  git clone https://github.com/JiahaoAlbus/YNX.git "$HOME/YNX"
else
  cd "$HOME/YNX" && git pull --ff-only
fi
```

`v2_validator_bootstrap.sh` builds `ynxd` if no binary exists.
For cleaner onboarding on restricted servers, pre-provide a binary and use `YNX_BIN`:

```bash
export YNX_BIN=/usr/local/bin/ynxd
```

If you must build from source, pin toolchain/proxy first:

```bash
export GOTOOLCHAIN=go1.23.6
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
```

Join using descriptor (preferred):

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --descriptor https://indexer.ynxweb4.com/ynx/network-descriptor \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --reset
```

RPC fallback:

```bash
cd ~/YNX/chain
./scripts/v2_validator_bootstrap.sh \
  --rpc https://rpc.ynxweb4.com \
  --role validator \
  --home ~/.ynx-v2-validator \
  --moniker <YOUR_MONIKER> \
  --reset
```

Check validator status:

```bash
./ynxd query staking validators --node https://rpc.ynxweb4.com -o json | jq -r '.validators[] | [.description.moniker,.status] | @tsv'
```

## 6. Health checks

```bash
curl -s https://indexer.ynxweb4.com/ynx/overview | jq
```

```bash
curl -s https://ai.ynxweb4.com/health | jq
```

```bash
curl -s https://web4.ynxweb4.com/web4/overview | jq
```

## 7. FAQ

### Is this mainnet?

No. This is a public testnet. Test tokens are not mainnet assets.

### Who should use this guide?

Users, builders, and external validators.

### Where are operator deployment docs?

Operator runbooks remain in internal/ops documents, not in this join guide.

## 8. Risk notice

- Public testnet can be upgraded or reset.
- Never use production secrets on testnet.
- Keep seed phrases and private keys offline.

## 9. Support links

- Repo: `https://github.com/JiahaoAlbus/YNX`
- Explorer: `https://explorer.ynxweb4.com`
- Indexer overview: `https://indexer.ynxweb4.com/ynx/overview`
