# YNX Testnet Faucet (v0)

Status: v0  
Last updated: 2026-02-12  
Canonical language: English

## 1. Overview

The faucet provides small NYXT grants for testnet onboarding.

## 2. Run

```bash
cd infra/faucet
node server.js
```

## 3. Configuration

The faucet reads environment variables and optional `.env` files:

Search order:
- `FAUCET_ENV_FILE`
- `YNX_ENV_FILE`
- `infra/faucet/.env`
- repo root `.env`

Key variables:
- `FAUCET_KEY` (keyring account name)
- `FAUCET_CHAIN_ID`
- `FAUCET_NODE` (CometBFT RPC)
- `FAUCET_DENOM`
- `FAUCET_AMOUNT` (default `1000000000000000000`)
- `FAUCET_GAS_PRICES` (default `0anyxt`)
- `FAUCET_GAS_ADJUSTMENT` (default `1.2`)
- `FAUCET_RATE_LIMIT_SECONDS` (default `3600`)
- `FAUCET_MAX_PER_DAY` (default `3`)
- `FAUCET_PORT` (default `8080`)
- `FAUCET_HOME` (default `chain/.testnet`)
- `FAUCET_KEYRING` (default `os`)
- `YNXD_PATH` (default `chain/ynxd`)

## 4. HTTP API

- `GET /health`
- `POST /faucet`
- `GET /faucet` with an `address` query parameter
