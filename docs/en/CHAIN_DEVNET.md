# YNX Chain — Local Devnet

This document describes how to run a single-node YNX devnet locally using the `ynxd` binary.

## Prereqs

- Go (this repo was tested with Go 1.25.x)
- (Optional) A working C toolchain if you want `cgo` builds.
  - The local devnet script defaults to `CGO_ENABLED=0` for portability.

## Build

```bash
cd chain
CGO_ENABLED=0 go build ./cmd/ynxd
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
- Build mode: `CGO_ENABLED=0` (override with `YNX_CGO_ENABLED=1`)

Dev key (for local testing only):

- `chain/scripts/localnet.sh` uses the standard Hardhat test mnemonic by default:
  - `test test test test test test test test test test test junk`
- Override via `YNX_MNEMONIC=...` when running the script.

## Connect EVM tooling

- Add a custom network in MetaMask / Rabby:
  - RPC URL: `http://127.0.0.1:8545`
  - Chain ID: `9001`
  - Currency symbol: `NYXT` (display)

## System contracts (EVM)

The chain can deploy the v0 system contracts deterministically during `InitGenesis` via `x/ynx`.

- `chain/scripts/localnet.sh` enables this by default.
- The script uses a dedicated deployer key (`deployer`) so validator gentx signing is not affected by EVM nonce/sequence increments.
  - Override the key name via `YNX_DEPLOYER_KEY=...`.

```bash
ynxd query ynx system-contracts --home chain/.localnet
```

Optional: reference deploy script (not required for the chain devnet):

```bash
npm --workspace @ynx/contracts run ynxdev:deploy
```
