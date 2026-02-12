# Address Formats: `0x...` and `YN...` (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-12  
Canonical language: English

## 0. Normative Language

Normative keywords are per RFC 2119.

## 1. Goals

YNX MUST support:

- Maximum ecosystem compatibility (`0x...` canonical EVM addresses)
- A human-friendly display format (`YN...`) for UI/QR codes and user-facing flows
- Cosmos SDK bech32 account addresses for staking/governance (`ynx1...`)

## 2. Cosmos SDK Bech32 Addresses (`ynx1...`)

YNX is a Cosmos SDK chain and therefore uses bech32 addresses for core modules (bank, staking, distribution, governance).

Canonical prefixes:

- Account: `ynx1...`
- Validator operator: `ynxvaloper1...`
- Consensus: `ynxvalcons1...`

### 2.1 Relationship to `0x...`

YNX uses 20-byte addresses for accounts. The bech32 account address and the EVM `0x...` address represent the same 20
bytes in different encodings.

Reference conversion (node CLI):

```bash
cd chain

# 0x... -> ynx1...
./ynxd debug addr 0x0000000000000000000000000000000000000000

# ynx1... -> 0x...
./ynxd debug addr ynx1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqgrm2qr
```

### 2.2 How to generate your YNX address (founder / team / community)

Create a key in the local keyring and display the account address:

```bash
cd chain
./ynxd keys add founder --keyring-backend os --key-type eth_secp256k1
./ynxd keys show founder --keyring-backend os --bech acc -a
```

For test/dev workflows, you MAY use `--keyring-backend test` (insecure; do not use for production funds).

## 3. Canonical Address (EVM)

- Canonical addresses MUST be 20 bytes.
- The canonical string representation MUST be hex with `0x` prefix (40 hex chars).
- JSON-RPC APIs MUST accept and return the canonical format by default.

## 4. `YN...` Human-friendly Address

`YN...` addresses are an optional alias format intended for end users.

Requirements:

- The `YN...` format MUST map bijectively to a canonical 20-byte address.
- The `YN...` format MUST include a checksum or error-detection code.
- SDKs and explorer UI MUST provide conversion between `YN...` and `0x...`.

### 4.1 v0 Encoding (Reference)

For v0, the reference implementation uses:

- Visible prefix: ASCII `"YN"`
- Payload: `Base58Check( [1-byte version] || [20-byte canonical address] )`

This guarantees the `YN` prefix while keeping a compact, checksummed payload.
