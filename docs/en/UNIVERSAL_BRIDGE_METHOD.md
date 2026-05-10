# Universal Bridge Method (TRON-style Multi-Asset Coverage)

Status: Draft  
Last updated: 2026-05-10

## Goal

Provide a general method so YNX can onboard many external assets (TRON/BSC/etc.) using one bridge framework, instead of building one-off logic per token.

## Core design

`YNXBridgeGateway` + `YNXBridgeWrappedToken` implements:

1. **Threshold signer attestation** for inbound deposits (`mintWithMappedAttestation`).
2. **Replay protection** via `depositId`.
3. **Per-asset route mapping**:
   - `wrappedTokenByRemoteAsset[remoteChainId][remoteAssetId] -> wrappedToken`
   - `remoteAssetIdByWrappedToken[wrappedToken][remoteChainId] -> remoteAssetId`
4. **Outbound burn requests** with explicit destination route (`burnForBridgeMapped`).
5. **Signer-set timelock rotation** (propose/apply flow) for operational safety.

## Canonical asset ID

Use a canonical string and hash it into `bytes32`:

- Example canonical: `tron:usdt:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t`
- `remoteAssetId = keccak256(utf8(canonical))`

This avoids hardcoding chain-specific address formats into on-chain storage.

## Why this is the generic method

To list a new remote token, we do not change bridge logic. We only:

1. deploy/select a wrapped token contract on YNX;
2. mark it supported (`setSupportedWrappedToken`);
3. add route mapping (`setBridgeRoute(remoteChainId, remoteAssetId, wrappedToken)`).

That is the same onboarding path for TRON assets, BSC assets, and future networks.

## Operational note

“Having all TRON tradable assets” is not instant by code alone. Production onboarding still needs:

- custody/observer support for that source chain,
- risk controls and monitoring,
- liquidity and market-making in YNX-side pools.

But with this design, adding each new asset is a config/listing workflow, not a new protocol rewrite.

## Dev script

`packages/contracts/scripts/deploy_bridge.ts` deploys gateway + wrapped token and writes a deployment file.

Example:

```bash
cd packages/contracts
BRIDGE_REMOTE_CHAIN_ID=728126428 \
BRIDGE_REMOTE_ASSET_CANONICAL='tron:usdt:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t' \
npm run ynxdev:bridge-deploy
```

## Bulk onboarding pipeline ("all-in" mode)

The repo now includes a two-step pipeline:

1. Generate TRON asset manifest from TronScan:

```bash
cd packages/contracts
TRON_MAX_ASSETS=500 \
TRON_MIN_HOLDERS=100 \
npm run bridge:tron-manifest
```

2. Bulk onboard assets onto YNX via the bridge gateway:

```bash
cd packages/contracts
BRIDGE_GATEWAY_ADDRESS=0xYourGatewayAddress \
BRIDGE_ASSET_MANIFEST_PATH=./deployments/tron-assets-manifest.json \
BRIDGE_MAX_ONBOARD=500 \
npm run ynxdev:bridge-onboard
```

Notes:

- Set `BRIDGE_DRY_RUN=true` to preview without deploying contracts.
- This is generic: any third-party list can be transformed into the same manifest format and onboarded by the same script.
