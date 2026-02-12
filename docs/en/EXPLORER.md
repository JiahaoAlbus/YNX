# YNX Testnet Explorer (v0)

Status: v0  
Last updated: 2026-02-12  
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
Search supports block heights and transaction hashes.
