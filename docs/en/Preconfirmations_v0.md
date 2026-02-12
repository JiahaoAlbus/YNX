# Preconfirmations (v0) — `ynx_preconfirmTx` JSON-RPC

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Overview

YNX provides a v0 **preconfirmation** prototype via a chain-specific JSON-RPC method:

- Namespace: `ynx`
- Method: `ynx_preconfirmTx(txHash)`

The method returns a **signed receipt** that is intended for near-instant user experience (“UX confirmation”). It is
**NOT** finality.

## 1. Method

### 1.1 Request

`ynx_preconfirmTx` accepts one parameter:

- `txHash` (32-byte `0x...` transaction hash)

### 1.2 Response

The response is a JSON object with the following fields:

- `status` — `"pending"` or `"included"`
- `chainId` — Cosmos chain id string (e.g. `ynx_9001-1`)
- `evmChainId` — EIP-155 chain id (hex quantity)
- `txHash` — the transaction hash
- `targetBlock` — block height the signer is acknowledging
  - `"pending"`: `latest + 1` at the time of issuance
  - `"included"`: the actual inclusion height
- `issuedAt` — unix timestamp (seconds)
- `signer` — EVM address of the preconfirm signer
- `digest` — `keccak256` digest of the signed message
- `signature` — 65-byte secp256k1 signature (`r || s || v` where `v ∈ {0,1}`)

## 2. Digest format

The digest is computed as:

`keccak256( "YNX_TXCONFIRM_V0" || mode || chainIdLen || chainId || evmChainId || txHash || targetBlock || issuedAt )`

Where:

- `"YNX_TXCONFIRM_V0"` is the ASCII prefix (no null terminator)
- `mode` is a single byte:
  - `0x00` for `"pending"`
  - `0x01` for `"included"`
- `chainIdLen` is a big-endian `uint16` length of `chainId` in bytes
- `chainId` is the UTF-8 bytes of the Cosmos chain id
- `evmChainId` is a big-endian `uint64`
- `txHash` is 32 bytes
- `targetBlock` is a big-endian `uint64`
- `issuedAt` is a big-endian `uint64`

## 3. Verification

To verify a receipt:

1) Recompute the digest from the receipt fields.
2) Recover the public key / address from `(digest, signature)`.
3) Check `recovered == signer`.

If the chain operator publishes an allowlist of valid signer addresses, clients SHOULD also enforce that allowlist.

## 4. Node configuration

Preconfirmations are disabled by default.

Enablement:

- `YNX_PRECONFIRM_ENABLED=1`

Signer configuration (choose one):

- `YNX_PRECONFIRM_PRIVKEY_HEX=...` (32-byte hex private key, optional `0x` prefix)
- `YNX_PRECONFIRM_KEY_PATH=...` (file containing a hex private key)

Optional performance control:

- `YNX_PRECONFIRM_MEMPOOL_SCAN_LIMIT` (default: `2000`)

Key generation helper (node operator):

```bash
ynxd preconfirm keygen --home <node_home>
```

## 5. Security boundary

- A preconfirmation receipt is a **promise by a signer**, not a consensus guarantee.
- Finality is provided by consensus, not by preconfirmations.
- v0 uses an operator-configured signer; decentralization of the preconfirm path (committee / threshold signatures) is a
  future milestone.

