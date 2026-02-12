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
- JSON-RPC APIs: `eth,net,web3,ynx`
- Build mode: `CGO_ENABLED=0` (override with `YNX_CGO_ENABLED=1`)

Dev key (for local testing only):

- `chain/scripts/localnet.sh` uses the standard Hardhat test mnemonic by default:
  - `test test test test test test test test test test test junk`
- Override via `YNX_MNEMONIC=...` when running the script.

Optional genesis address overrides (useful when testing fee revenue routing):

- `YNX_FOUNDER_ADDRESS=ynx1...` (defaults to local validator)
- `YNX_TEAM_BENEFICIARY=ynx1...` (defaults to local validator)
- `YNX_COMMUNITY_RECIPIENT=ynx1...` (defaults to local validator)

## Fast local blocks (dev-only)

`chain/scripts/localnet.sh` tunes CometBFT timeouts for a fast single-node experience (target ~1s blocks).

These settings are for local development only and are NOT a recommendation for production networks.

## Preconfirmations (v0 prototype)

The localnet script enables the `ynx_preconfirmTx` JSON-RPC method by default and generates a dedicated signer key at:

- `chain/.localnet/config/ynx_preconfirm.key`

Multi-signer dev mode (optional):

```bash
YNX_DEV_PRECONFIRM_SIGNER_COUNT=3 YNX_DEV_PRECONFIRM_THRESHOLD=2 ./scripts/localnet.sh --reset
```

This generates:

- `chain/.localnet/config/preconfirm/signer_1.key` ...

The node is started with:

- `YNX_PRECONFIRM_ENABLED=1`
- `YNX_PRECONFIRM_KEY_PATH=.../ynx_preconfirm.key`

In multi-signer mode, the script uses:

- `YNX_PRECONFIRM_KEY_PATHS=.../signer_1.key,...`
- `YNX_PRECONFIRM_THRESHOLD=...`

Example call:

```bash
curl -s http://127.0.0.1:8545 \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"ynx_preconfirmTx","params":["0x<txHash>"]}' | jq
```

Notes:

- This is a **UX confirmation** signal, not finality.
- The receipt is signed and verifiable (see `docs/en/Preconfirmations_v0.md`).

## Fast governance (dev-only)

By default, v0 governance parameters target production-like settings (7 day voting + 7 day timelock).

For local iteration, `chain/scripts/localnet.sh` supports a fast governance mode:

```bash
YNX_DEV_FAST_GOV=1 ./scripts/localnet.sh --reset
```

Overrides (optional):

- `YNX_DEV_VOTING_DELAY_BLOCKS` (default: `1`)
- `YNX_DEV_VOTING_PERIOD_BLOCKS` (default: `60`)
- `YNX_DEV_TIMELOCK_DELAY_SECONDS` (default: `30`)
- `YNX_DEV_PROPOSAL_THRESHOLD` (default: `1e18`)
- `YNX_DEV_PROPOSAL_DEPOSIT` (default: `1e18`)
- `YNX_DEV_QUORUM_PERCENT` (default: `1`)

E2E governance demo (proposal → vote → queue → execute `IYNXProtocol.updateParams(...)`):

```bash
npm --workspace @ynx/contracts run ynxdev:governance-e2e
```

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
- If you do not have a community recipient at genesis, you may omit `system.community_recipient_address`; it defaults to the deployer address.

```bash
ynxd query ynx system-contracts --home chain/.localnet
```

The v0 system contracts include `domain_inbox` (execution-domain commitments inbox).

Demo: register a domain + submit a commitment to the system `domain_inbox`:

```bash
npm --workspace @ynx/contracts run ynxdev:domain-inbox-demo
```

## Protocol governance precompile (EVM)

YNX exposes a chain-specific protocol precompile:

- Address: `0x0000000000000000000000000000000000000810`
- Interface: `IYNXProtocol`

It provides:

- `getParams()` / `getSystemContracts()` (views)
- `updateParams(...)` (timelock-restricted transaction)

See `docs/en/Protocol_Precompile_v0.md`.

Optional: reference deploy script (not required for the chain devnet):

```bash
npm --workspace @ynx/contracts run ynxdev:deploy
```
