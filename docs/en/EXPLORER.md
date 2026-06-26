# YNX Testnet Explorer (v0)

Status: v0+  
Last updated: 2026-06-26  
Canonical language: English

## 1. Overview

This is a lightweight explorer UI that reads from the local indexer API.

## 2. Run

```bash
cd infra/explorer
node server.js
```

## 3. Configuration

The explorer reads environment variables and optional `.env` files:

Search order:
- `EXPLORER_ENV_FILE`
- `YNX_ENV_FILE`
- `infra/explorer/.env`
- repo root `.env`

Key variables:
- `EXPLORER_PORT` (default `8082`)
- `EXPLORER_INDEXER` (default `http://127.0.0.1:8081`)

## 4. Usage

Open the explorer in a browser at the configured port.

Search supports:

- block heights
- validator consensus addresses
- transaction hashes
- chain addresses with lot/taint trace
- lot ids such as `lot_00000001`

Trace search results now also surface a public graph summary:

- linked address / lot / tx counts
- root-origin summary
- visible upstream/downstream lineage edges
- path previews across traced routes

Public explorer trace search is intentionally a preview surface:

- it uses redacted `graph_preview` data from the indexer search API
- it does not expose full lot-level transfer ids
- it does not expose `tainted_amount` fields in the public graph cards

Full graph reconstruction remains on the protected trace endpoint:

```bash
curl -s "https://indexer.ynxweb4.com/trace/graph?kind=address&target=ynx1...&direction=both&max_depth=4" \
  -H "x-ynx-trace-token: <protected-token>" | jq
```

This keeps the public explorer aligned with the underlying trace and forensics
layer instead of limiting the UI to flat trace snapshots.
