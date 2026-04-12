# YNX Public Testnet Launch Kit

Status: active  
Last updated: 2026-04-12  
Canonical language: English

## Public Endpoints

- RPC: `https://rpc.ynxweb4.com`
- EVM JSON-RPC: `https://evm.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- gRPC: `grpc.ynxweb4.com:443`
- Faucet: `https://faucet.ynxweb4.com`
- Indexer: `https://indexer.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- AI Gateway: `https://ai.ynxweb4.com`
- Web4 Hub: `https://web4.ynxweb4.com`

## Server Runtime (systemd)

- `ynx-v2-node`
- `ynx-v2-faucet`
- `ynx-v2-indexer`
- `ynx-v2-explorer`

## Single Verification Command

Run this from your local machine:

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@<SERVER_IP> 'cd ~/YNX && YNX_PUBLIC_HOST=127.0.0.1 ./chain/scripts/v2_public_testnet_verify.sh'
```

If output includes `PASS`, the public testnet stack is healthy on the host.
