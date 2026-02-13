# Public Testnet Announcement (Template)

Status: v0  
Last updated: 2026-02-13  
Canonical language: English

## 1. Summary

YNX public testnet is live. This testnet focuses on fast blocks, full on-chain governance, and EVM compatibility.

## 2. Network Info

- Chain ID: `<chain-id>`
- EVM Chain ID: `<evm-chain-id>`
- Denom: `nyxt` (base: `anyxt`)

## 3. Genesis + Checksums

- Genesis: `<public-url-to-genesis.json>`
- Checksums: `<public-url-to-checksums.txt>`
- Network metadata: `<public-url-to-network.json>`
- Snapshot (optional): `<public-url-to-snapshot.tar.gz>`

## 4. Public Endpoints

- RPC: `<rpc-url>`
- JSON-RPC: `<jsonrpc-url>`
- gRPC: `<grpc-url>`
- REST: `<rest-url>`
- Explorer: `<explorer-url>`
- Faucet: `<faucet-url>`

## 5. P2P

- Seeds: `<nodeid@ip:26656, ...>`
- Persistent peers: `<nodeid@ip:26656, ...>`

## 6. Validator Onboarding

Validator operators should:

1) Download `genesis.json`
2) Configure `seeds` / `persistent_peers`
3) Start the node and wait for sync
4) Join with a validator transaction

## 7. Security Notes

- Use separate machines for validator and public RPC nodes
- Do not share keys or admin access across operators

## 8. Contacts

- Discord: `<invite>`
- Email: `<ops-email>`
