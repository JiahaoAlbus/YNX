# Public Testnet Release Bundle (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Purpose

This document describes how to produce a **public testnet release bundle** that can be published to validators and node operators.

The release bundle includes:

- `genesis.json`
- `config.toml` / `app.toml`
- network metadata (`network.json`)
- public endpoint metadata (`endpoints.json`)
- operator-ready access summary (`PUBLIC_TESTNET.md`)
- optional seeds / persistent peers files
- optional data snapshot

## 1. Prereqs

- A finalized genesis (see `docs/en/TESTNET_BOOTSTRAP.md`)
- A node home directory with config files (default: `chain/.testnet`)

## 2. Release bundle script

```bash
cd chain
./scripts/testnet_release.sh --reset
```

By default, the bundle is written under `chain/.release/` with the chain id and current date in the folder name.

The script auto-loads `.env` from repo root or `chain/.env` unless `YNX_ENV_FILE` is set.

## 3. Add seeds / peers

Export seed and peer lists as comma-separated strings (or set them in `.env`):

```bash
export YNX_SEEDS="nodeid@ip:26656,nodeid@ip:26656"
export YNX_PERSISTENT_PEERS="nodeid@ip:26656"
export YNX_RPC_ENDPOINT="http://<public-ip>:26657"
export YNX_JSONRPC_ENDPOINT="http://<public-ip>:8545"
export YNX_FAUCET_URL="http://<public-ip>:8080"
export YNX_FAUCET_ADDRESS="<bech32 faucet address>"
export YNX_EXPLORER_URL="http://<public-ip>:8082"
export YNX_INDEXER_URL="http://<public-ip>:8081"
./scripts/testnet_release.sh --reset
```

If endpoint variables are omitted, the script derives defaults from `YNX_RPC_ENDPOINT` host.

This writes:

- `seeds.txt`
- `persistent_peers.txt`
- `endpoints.json`
- `PUBLIC_TESTNET.md`

## 4. Create a snapshot (optional)

If you want to publish a data snapshot (to speed up node sync), pass `--snapshot` and provide a running RPC endpoint:

```bash
export YNX_RPC="http://127.0.0.1:26657"
./scripts/testnet_release.sh --snapshot
```

The snapshot tarball is created under the release directory and recorded in `snapshot.txt`.

## 5. Recommended publication checklist

- Publish `genesis.json` and `network.json`
- Publish `endpoints.json` and `PUBLIC_TESTNET.md`
- Publish `seeds.txt` / `persistent_peers.txt` if available
- Publish checksums (`checksums.txt`)
- Publish snapshot tarball if available

## 6. Verify checksums

Node operators should verify:

```bash
shasum -a 256 -c checksums.txt
```

## 7. Generate publish package

After generating `chain/.release/current`, create a publish-ready archive and announcement file:

```bash
cd chain
./scripts/testnet_publish_bundle.sh --in ./.release/current --out ./.release
```

The script outputs:

- `<archive>.tar.gz`
- `<archive>.sha256`
- `<archive>_ANNOUNCEMENT.md`

## 8. One-command finalize

To regenerate release artifacts and refresh the final public checklist in one run:

```bash
cd chain
./scripts/testnet_finalize_public.sh
```
