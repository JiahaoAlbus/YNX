# YNX Testnet Indexer (v0)

Status: v0  
Last updated: 2026-02-12  
Canonical language: English

## 1. Overview

This indexer tails CometBFT RPC and stores block/tx summaries in JSONL files.  
It is designed for testnet operations and lightweight explorer APIs.

## 2. Run

```bash
cd infra/indexer
node server.js
```

## 3. Configuration

The indexer reads environment variables and optional `.env` files:

Search order:
- `INDEXER_ENV_FILE`
- `YNX_ENV_FILE`
- `infra/indexer/.env`
- repo root `.env`

Key variables:
- `INDEXER_RPC` (default `http://127.0.0.1:26657`)
- `INDEXER_PORT` (default `8081`)
- `INDEXER_POLL_MS` (default `1000`)
- `INDEXER_BACKFILL` (default `0`)
- `INDEXER_START_HEIGHT` (default `0`)
- `INDEXER_CACHE_SIZE` (default `500`)
- `INDEXER_TX_CACHE_SIZE` (default `2000`)
- `INDEXER_DATA_DIR` (default `infra/indexer/data`)
- `INDEXER_API_LIMIT` (default `20`)

## 4. Data layout

Files are written under `INDEXER_DATA_DIR`:
- `state.json`
- `blocks.jsonl`
- `txs.jsonl`

## 5. HTTP API

- `GET /health` — service status
- `GET /stats` — counters and cache sizes
- `GET /blocks?limit=20&before=height` — latest blocks
- `GET /blocks/height` — block by height
- `GET /txs?limit=20&height=height` — latest txs (optional height filter)
- `GET /txs/hash` — tx by hash
- `GET /metrics` — Prometheus metrics
