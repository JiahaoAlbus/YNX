# Address Formats: `0x...` and `YN...` (v0)

Status: Draft  
Version: v0.1  
Last updated: 2026-02-09  
Canonical language: English

## 0. Normative Language

Normative keywords are per RFC 2119.

## 1. Goals

YNX MUST support:

- Maximum ecosystem compatibility (`0x...` canonical EVM addresses)
- A human-friendly display format (`YN...`) for UI/QR codes and user-facing flows

## 2. Canonical Address (EVM)

- Canonical addresses MUST be 20 bytes.
- The canonical string representation MUST be hex with `0x` prefix (40 hex chars).
- JSON-RPC APIs MUST accept and return the canonical format by default.

## 3. `YN...` Human-friendly Address

`YN...` addresses are an optional alias format intended for end users.

Requirements:

- The `YN...` format MUST map bijectively to a canonical 20-byte address.
- The `YN...` format MUST include a checksum or error-detection code.
- SDKs and explorer UI MUST provide conversion between `YN...` and `0x...`.

### 3.1 v0 Encoding (Reference)

For v0, the reference implementation uses:

- Visible prefix: ASCII `"YN"`
- Payload: `Base58Check( [1-byte version] || [20-byte canonical address] )`

This guarantees the `YN` prefix while keeping a compact, checksummed payload.
