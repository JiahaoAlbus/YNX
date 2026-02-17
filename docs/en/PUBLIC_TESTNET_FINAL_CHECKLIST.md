# YNX Public Testnet Final Checklist

Status: Active  
Last updated: 2026-02-17  
Canonical language: English

## 1. Network Snapshot (Current)

- Chain ID: `ynx_9002-1`
- EVM Chain ID: `9002`
- Denom: `anyxt`
- Base Fee Mode: `no_base_fee = true`
- Latest checked height (local observer): `222328`

## 2. Public Endpoints

- RPC: `http://38.98.191.10:26657`
- JSON-RPC: `http://38.98.191.10:8545`
- gRPC: `38.98.191.10:9090`
- REST: `http://38.98.191.10:1317`
- Seed: `9edf41e71a5ba8bbc0a2b9026630bde1d56559c9@38.98.191.10:26656`
- Persistent Peer: `9edf41e71a5ba8bbc0a2b9026630bde1d56559c9@38.98.191.10:26656`
- Faucet: `http://38.98.191.10:8080`
- Explorer: `http://38.98.191.10:8082`
- Indexer: `http://38.98.191.10:8081`

## 3. Governance and Treasury Addresses

- Founder: `ynx1r6fyxax055jftss7cagde7zxm5pwtld55edy8l`
- Team Beneficiary: `ynx1qr95tc5q68p3fct8l86yypvhqhg8h5lfgv0y6n`
- Community Recipient: `ynx1pjg0ny0capuk0fuhapfv4xcmfczmht0fhas8pw`
- Treasury: `ynx1clg9fcxegaux56l2vrcczadmwg79hnjlppnpz4`
- Faucet Funding Address: `ynx1aet5xk9chswmsxj6chh434yp9zw2pgdzgmruxx`

## 4. Release Artifacts (Generated)

Release directory:
- `chain/.release/current`

Publish bundle files:
- `chain/.release/ynx_testnet_ynx_9002-1_20260217T070016Z.tar.gz`
- `chain/.release/ynx_testnet_ynx_9002-1_20260217T070016Z.sha256`
- `chain/.release/ynx_testnet_ynx_9002-1_20260217T070016Z_ANNOUNCEMENT.md`

Bundle contents include:
- `genesis.json`
- `config.toml`
- `app.toml`
- `network.json`
- `endpoints.json`
- `PUBLIC_TESTNET.md`
- `checksums.txt`

## 5. Published Download URLs

- Release page: `https://github.com/JiahaoAlbus/YNX/releases/tag/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z`
- Bundle URL: `https://github.com/JiahaoAlbus/YNX/releases/download/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z/ynx_testnet_ynx_9002-1_20260217T070016Z.tar.gz`
- SHA256 URL: `https://github.com/JiahaoAlbus/YNX/releases/download/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z/ynx_testnet_ynx_9002-1_20260217T070016Z.sha256`
- Announcement URL: `https://github.com/JiahaoAlbus/YNX/releases/download/testnet-ynx_testnet_ynx_9002-1_20260217T070016Z/ynx_testnet_ynx_9002-1_20260217T070016Z_ANNOUNCEMENT.md`

## 6. Operator Verification Commands

```bash
curl -s http://38.98.191.10:26657/status
curl -s -X POST -H "content-type: application/json" \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  http://38.98.191.10:8545
curl -s http://38.98.191.10:8080/health
curl -s http://38.98.191.10:8081/health
```

## 7. Public Open Ports (Inbound)

Open these TCP ports on host firewall and cloud security group:

- `26656` (P2P)
- `26657` (CometBFT RPC)
- `8545` (EVM JSON-RPC)
- `8080` (Faucet)
- `8081` (Indexer API)
- `8082` (Explorer)
- `9090` (gRPC, optional)
- `1317` (REST, optional)

## 8. Publish Sequence

1. Upload the three files from section 4 to a public location.
2. Replace link slots in section 5 with final URLs.
3. Publish the announcement markdown to your official channels.
4. Ask external operators to verify section 6 before joining.
