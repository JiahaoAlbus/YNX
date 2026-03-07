# YNX v2 Local Complete Runbook

Status: Active  
Last updated: 2026-03-07

This runbook is for local-only completion (no server deployment).

Canonical language for release-facing material is English.

## 1. Full local bring-up

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_local_complete.sh all
```

This performs:

1. v2 bootstrap
2. full stack start
3. verify + smoke
4. release bundle pack

## 2. Iteration commands

```bash
cd ~/Desktop/YNX/chain
./scripts/v2_local_complete.sh up
./scripts/v2_local_complete.sh compose-up
./scripts/v2_local_complete.sh verify-smoke
./scripts/v2_local_complete.sh pack
./scripts/v2_local_complete.sh company-pack
./scripts/v2_local_complete.sh down
```

## 3. Local multi-validator simulation

```bash
cd ~/Desktop/YNX/chain
YNX_VALIDATOR_COUNT=6 ./scripts/v2_local_complete.sh multinode
```

## 4. Local completion criteria

- `v2_public_testnet_verify.sh` returns `PASS`
- `v2_public_testnet_smoke.sh` returns `PASS`
- `v2_testnet_release.sh` generates bundle and checksums
- `v2_company_pack.sh` generates company handoff bundle and checksum
- multi-validator simulation starts and produces advancing heights
