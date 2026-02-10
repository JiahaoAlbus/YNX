# YNX Chain (MVP)

This directory contains the initial **YNX base-chain** implementation.

The MVP uses:

- **CometBFT** (BFT consensus + fast finality)
- **Cosmos SDK** (staking / governance / distribution modules)
- **Cosmos EVM** (EVM execution + JSON-RPC)

## Build

```bash
cd chain
go build ./cmd/ynxd
```

Binary:

- `chain/ynxd` (or `chain/cmd/ynxd/ynxd` depending on your build output)

## Local devnet

See:

- `docs/en/CHAIN_DEVNET.md`
