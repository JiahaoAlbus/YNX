# YNX v2 Consensus Validator Join Guide (BONDED)

Status: active  
Type: external manual  
Last updated: 2026-04-19

## 1. Scope

This manual is for operators who already run a synced validator node and now want to join consensus (become `BOND_STATUS_BONDED`).

If you have not deployed a node yet, start here first:

- `docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md`

## 1.1 If you opened this page directly on a fresh server

Run this first from zero environment:

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

```bash
cd "$YNX_REPO/chain"
./ynxd start \
  --home "$YNX_HOME" \
  --chain-id ynx_9102-1 \
  --minimum-gas-prices 0.000000007anyxt
```

Then wait for `catching_up=false`, and continue from section 4 below.

## 2. Consensus vs node-only

- Node-only: syncs chain data, does not vote/sign blocks.
- Consensus validator: is BONDED and participates in voting/signing.

## 3. Preconditions

On your validator server:

1. Node process is running.
2. Node is synced (`catching_up=false`).
3. You have a validator account with testnet funds.

Sync check:

```bash
curl -s http://127.0.0.1:36657/status | jq -r '.result.sync_info.latest_block_height,.result.sync_info.catching_up'
```

## 4. Prepare validator key

```bash
cd ~/YNX/chain
export YNX_HOME="$HOME/.ynx-v2-validator"
./ynxd keys add validator \
  --home "$YNX_HOME" \
  --keyring-backend os \
  --key-type eth_secp256k1
```

Get account address:

```bash
VAL_ADDR=$(./ynxd keys show validator --home "$YNX_HOME" --keyring-backend os -a)
echo "$VAL_ADDR"
```

## 5. Fund validator account

Request faucet:

```bash
curl -s "https://faucet.ynxweb4.com/faucet?address=${VAL_ADDR}" | jq
```

Check balance:

```bash
./ynxd query bank balances "$VAL_ADDR" --node http://127.0.0.1:36657 -o json | jq
```

If balance is low, request faucet again after rate-limit window.

## 6. Submit `create-validator`

Build validator tx JSON:

```bash
PUBKEY=$(./ynxd comet show-validator --home "$YNX_HOME")
cat >/tmp/ynx-create-validator.json <<JSON
{
  "pubkey": $PUBKEY,
  "amount": "1000000000000000000anyxt",
  "moniker": "<YOUR_MONIKER>",
  "identity": "",
  "website": "",
  "security": "",
  "details": "YNX public testnet consensus validator",
  "commission-rate": "0.10",
  "commission-max-rate": "0.20",
  "commission-max-change-rate": "0.01",
  "min-self-delegation": "1"
}
JSON
```

Broadcast transaction:

```bash
./ynxd tx staking create-validator /tmp/ynx-create-validator.json \
  --from validator \
  --home "$YNX_HOME" \
  --keyring-backend os \
  --chain-id ynx_9102-1 \
  --node http://127.0.0.1:36657 \
  --gas 450000 --fees 450000000000000anyxt \
  --yes -o json
```

## 7. Verify BONDED status

Get operator address:

```bash
VALOPER=$(./ynxd keys show validator --home "$YNX_HOME" --keyring-backend os --bech val -a)
echo "$VALOPER"
```

Query your validator:

```bash
./ynxd query staking validator "$VALOPER" --node http://127.0.0.1:36657 -o json \
  | jq -r '.validator.description.moniker,.validator.status,.validator.tokens,.validator.jailed'
```

Expected status:

- `BOND_STATUS_BONDED`
- `jailed = false`

Global validator list check:

```bash
./ynxd query staking validators --node http://127.0.0.1:36657 -o json \
  | jq -r '.validators[] | [.description.moniker,.operator_address,.status,.tokens] | @tsv'
```

## 8. Optional reliability guard

Install watchdog service:

```bash
cd ~/YNX/chain
./scripts/install_v2_watchdog_systemd.sh
sudo systemctl status ynx-v2-watchdog --no-pager
```

## 9. Troubleshooting

### `insufficient fee`

Use non-zero gas price:

```bash
--gas 450000 --fees 450000000000000anyxt
```

### `account not found`

Account has no on-chain state yet. Request faucet first, then retry.

### Validator not BONDED

- Wait for tx to be included and re-query.
- Ensure node is synced.
- Ensure enough self-delegation amount.

### Validator got jailed

Check process uptime, network reachability, and disk pressure.

## 10. What to submit to YNX for public validator listing

- Moniker
- `valoper` address
- Server region
- Public contact channel
- Optional public RPC endpoint
