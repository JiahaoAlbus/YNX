# Testnet Services (v0)

Status: v0  
Last updated: 2026-02-13  
Canonical language: English

## 1. Start/Stop

Use the bundled scripts:

```bash
cd chain
./scripts/testnet_services_start.sh
./scripts/testnet_services_stop.sh
```

Services:
- YNX node (RPC 26657, JSON-RPC 8545)
- Faucet (8080)
- Indexer (8081)
- Explorer (8082)

## 2. Healthcheck

```bash
cd chain
./scripts/testnet_healthcheck.sh
```

## 3. Notes

- These scripts are for single-machine testnet operations only.
- For real decentralization, see `docs/en/TESTNET_OPS.md`.
