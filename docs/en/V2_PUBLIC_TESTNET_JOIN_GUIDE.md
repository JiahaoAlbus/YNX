# YNX v2 Public Testnet Join Guide (Web4 Track)

Status: active  
Audience: public users, builders, node operators, consensus validator candidates  
Last updated: 2026-03-21

## 1. Purpose

This is the external entry guide for YNX v2 public testnet.

Use this page to quickly decide your path, then jump to the full manual.

## 1.1 If you opened this page on a fresh machine (from zero)

Run this baseline first, even if you are not sure which path you will choose:

```bash
sudo apt-get update -y
sudo apt-get install -y git curl jq build-essential ca-certificates
```

```bash
export YNX_REPO="$HOME/YNX"
if [ ! -d "$YNX_REPO/.git" ]; then
  git clone https://github.com/JiahaoAlbus/YNX.git "$YNX_REPO"
else
  cd "$YNX_REPO" && git pull --ff-only
fi
```

After this, continue with Path A / B / C below.

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

## 3. Choose your path

### Path A — User / Builder (no server)

- Connect wallet
- Get faucet test token
- Send first tx
- Build against EVM/RPC endpoints

Quick checks:

```bash
curl -s https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network,.result.sync_info.latest_block_height'
```

```bash
curl -s -X POST https://evm.ynxweb4.com \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq
```

```bash
curl -s https://faucet.ynxweb4.com/health | jq
```

### Path B — Join as validator node (non-consensus)

Run a synced node and serve network data, but do not vote in consensus.

Full manual:

- `docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`

### Path C — Join as consensus validator (BONDED)

Run a synced validator node and submit `create-validator` so your status is `BOND_STATUS_BONDED` and you vote/sign blocks.

Full manual:

- `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`

## 4. FAQ

### Is this mainnet?

No. This is public testnet. Test tokens are not mainnet assets.

### What is the difference between "validator node" and "consensus validator"?

- Validator node: syncs and relays chain data.
- Consensus validator: is BONDED and participates in block voting/signing.

### Can I start as node only, then join consensus later?

Yes. This is the recommended sequence.

## 5. Risk notice

- Public testnet can be upgraded/reset.
- Do not use production funds or production secrets.
- Keep mnemonic/private keys offline.

## 6. Support links

- Repo: `https://github.com/JiahaoAlbus/YNX`
- Explorer: `https://explorer.ynxweb4.com`
- Network overview: `https://indexer.ynxweb4.com/ynx/overview`
