# YNX Public Testnet Launch Kit

Status: active  
Last updated: 2026-02-17  
Canonical language: English

## Public Endpoints

- RPC: `http://43.134.23.58:26657`
- EVM JSON-RPC: `http://43.134.23.58:8545`
- REST: `http://43.134.23.58:1317`
- gRPC: `43.134.23.58:9090`
- Faucet: `http://43.134.23.58:8080`
- Indexer: `http://43.134.23.58:8081`
- Explorer: `http://43.134.23.58:8082`

## Server Runtime (systemd)

- `ynx-node`
- `ynx-faucet`
- `ynx-indexer`
- `ynx-explorer`

## Single Verification Command

Run this from your local machine:

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.134.23.58 'cd ~/YNX && YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/public_testnet_verify.sh'
```

If output includes `PASS`, the public testnet stack is healthy on the host.

