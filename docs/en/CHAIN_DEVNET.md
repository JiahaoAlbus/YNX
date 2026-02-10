# YNX Chain — Local Devnet

This document describes how to run a single-node YNX devnet locally using the `ynxd` binary.

## Prereqs

- Go (this repo was tested with Go 1.25.x)
- A working C toolchain (Cosmos EVM builds require cgo)
  - On macOS, make sure Xcode Command Line Tools are installed and the Xcode license is accepted.

## Build

```bash
cd chain
go build ./cmd/ynxd
```

## Run

Use the helper script:

```bash
./scripts/localnet.sh --reset
```

Defaults:

- Home: `chain/.localnet`
- Chain ID: `ynx_9001-1`
- EVM Chain ID (EIP-155): `9001`
- Gas denom: `anyxt` (display denom: `nyxt`, 18 decimals)
- JSON-RPC: `http://127.0.0.1:8545`

Dev key (for local testing only):

- `chain/scripts/localnet.sh` uses the standard Hardhat test mnemonic by default:
  - `test test test test test test test test test test test junk`
- Override via `YNX_MNEMONIC=...` when running the script.

## Connect EVM tooling

- Add a custom network in MetaMask / Rabby:
  - RPC URL: `http://127.0.0.1:8545`
  - Chain ID: `9001`
  - Currency symbol: `NYXT` (display)

## Deploy system contracts (EVM)

With the chain running:

```bash
npm --workspace @ynx/contracts run ynxdev:deploy
```

Deployment output:

- `packages/contracts/deployments/devnet-9001.json`
