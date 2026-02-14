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
./scripts/testnet_release.sh --reset
```

This writes:

- `seeds.txt`
- `persistent_peers.txt`

## 4. Create a snapshot (optional)

If you want to publish a data snapshot (to speed up node sync), pass `--snapshot` and provide a running RPC endpoint:

```bash
export YNX_RPC="http://127.0.0.1:26657"
./scripts/testnet_release.sh --snapshot
```

The snapshot tarball is created under the release directory and recorded in `snapshot.txt`.

## 5. Recommended publication checklist

- Publish `genesis.json` and `network.json`
- Publish `seeds.txt` / `persistent_peers.txt` if available
- Publish checksums (`checksums.txt`)
- Publish snapshot tarball if available

## 6. Verify checksums

Node operators should verify:

```bash
shasum -a 256 -c checksums.txt
```
