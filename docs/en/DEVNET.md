# Devnet (Local) — Run and Deploy

This repo includes a **reference implementation** of YNX’s governance + treasury contracts and the `YN...` address format SDK.

## Prereqs

- Node.js (this repo was tested with Node 24.x)

## Install

```bash
npm install
```

## Run a local RPC node

In one terminal:

```bash
npm --workspace @ynx/contracts run devnet:node
```

This starts a local JSON-RPC node on `http://127.0.0.1:8545` with chain id `31337` (Hardhat default).

## Deploy the v0 system contracts

In another terminal:

```bash
npm --workspace @ynx/contracts run devnet:deploy
```

Deployment output is written to:

- `packages/contracts/deployments/devnet-31337.json`

## YN address CLI

```bash
npx ynx address encode 0x0000000000000000000000000000000000000000
npx ynx address decode <YN...>
```
