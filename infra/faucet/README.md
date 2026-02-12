# YNX Testnet Faucet

Status: v0  
Canonical language: English

## Purpose

This service sends a small amount of NYXT to a requested address for testnet onboarding.

## Prereqs

- Node.js 18+
- A running YNX testnet node with RPC enabled
- `ynxd` built at `chain/ynxd`
- A funded faucet account in the chosen keyring backend

## Configuration

The faucet reads environment variables (and optional `.env` files).

Supported `.env` locations (first match wins):
- `FAUCET_ENV_FILE`
- `YNX_ENV_FILE`
- `infra/faucet/.env`
- repo root `.env`

Required runtime inputs:
- `FAUCET_KEY`: keyring account name used to send tokens
- `FAUCET_CHAIN_ID`: chain id of the running testnet
- `FAUCET_NODE`: CometBFT RPC URL
- `FAUCET_DENOM`: fee denom (NYXT base denom)

Optional controls:
- `FAUCET_AMOUNT` (default `1000000000000000000`)
- `FAUCET_GAS_PRICES` (default `0anyxt`)
- `FAUCET_GAS_ADJUSTMENT` (default `1.2`)
- `FAUCET_RATE_LIMIT_SECONDS` (default `3600`)
- `FAUCET_MAX_PER_DAY` (default `3`)
- `FAUCET_MAX_INFLIGHT` (default `1`)
- `FAUCET_DATA_DIR` (default `infra/faucet/data`)
- `FAUCET_PORT` (default `8080`)
- `FAUCET_HOME` (default `chain/.testnet`)
- `FAUCET_KEYRING` (default `os`)
- `YNXD_PATH` (default `chain/ynxd`)

## Run

```bash
cd infra/faucet
node server.js
```

## API

- `GET /health` — status and config summary
- `POST /faucet` — JSON body with a valid YNX bech32 or 0x hex address in the `address` field
- `GET /faucet?address=...` — convenience query param

Responses are JSON and include `txhash` on success.
