# YNX / NYXT

YNX is an open, EVM-compatible chain.  
NYXT is the native token used for gas, staking, and governance.

## Public testnet

- Chain ID: `ynx_9002-1`
- RPC: `http://43.134.23.58:26657`
- EVM RPC: `http://43.134.23.58:8545`
- REST: `http://43.134.23.58:1317`
- Faucet: `http://43.134.23.58:8080`
- Explorer: `http://43.134.23.58:8082`

Quick status check:

```bash
curl -s http://43.134.23.58:26657/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
```

## Choose your guide (jump by need)

- English full playbook: `docs/en/PUBLIC_TESTNET_PLAYBOOK.md`
- 中文完整手册: `docs/zh/PUBLIC_TESTNET_PLAYBOOK.md`
- Slovenský kompletný návod: `docs/sk/PUBLIC_TESTNET_PLAYBOOK.md`

## Do you need a wallet?

- Only querying RPC / running a non-validator full node: **No**
- Faucet / sending tx / validator operations: **Yes**

Create wallet only when needed:

```bash
cd ~/YNX/chain
./ynxd keys add wallet --keyring-backend os --key-type eth_secp256k1
./ynxd keys show wallet --keyring-backend os --bech acc -a
```

## Repository structure

- `chain/` — core chain implementation (`ynxd`, modules, scripts, proto)
- `packages/contracts/` — system contracts
- `packages/sdk/` — client SDK/CLI helpers
- `infra/` — faucet, indexer, explorer, monitoring
- `docs/en/` — canonical technical docs
- `docs/zh/` — Chinese operator/user playbook
- `docs/sk/` — Slovak operator/user playbook

## Operator commands

Full stack verification:

```bash
./chain/scripts/public_testnet_verify.sh
```

Server-local verification:

```bash
YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh
```

## Security note

Keep secrets out of Git:

- do not commit mnemonic/private keys
- do not commit `.env`
- rotate any key that was ever exposed
