# YNX Infrastructure Role Map

Status date: 2026-06-13

## Live Server Roles

### `43.153.202.237` main server

- production validator
- public RPC / EVM / faucet / indexer / explorer
- AI gateway
- Web4 hub
- bridge service
- Caddy ingress

This is the main execution surface. It should stay focused on production traffic and core public services.

### `43.134.23.58` Singapore

- bonded validator
- independent ops observer
- snapshot-capable recovery peer

This node now generates periodic public-ops snapshots at:

- `/var/lib/ynx-ops-observer/latest.json`

It also keeps state snapshots to speed up validator recovery and reduce dependence on the main node.

### `43.162.100.54` Silicon Valley

- bonded validator
- kept as a lean consensus node

This node was disk-constrained and has been cleaned back to safe headroom. It should remain focused on validator duty.

### `43.164.132.81` Seoul

- bonded validator
- read replica candidate
- snapshot-capable peer

This node exposes read-facing chain ports and can act as a backup read surface or recovery source.

## Current Best Use

- main server: execution and public product surface
- Singapore: observation, snapshots, recovery support, validator duty
- Silicon Valley: stable validator only
- Seoul: validator + read replica + snapshots
