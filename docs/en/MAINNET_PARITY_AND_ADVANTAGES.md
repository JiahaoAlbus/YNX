# YNX Testnet-to-Mainnet Parity & Advantages

Status: active  
Last updated: 2026-02-17  
Canonical language: English

## 1) Product principle

YNX public testnet is designed to match planned mainnet behavior as much as possible.  
The intended difference is economic value (test tokens vs real-value assets), not a different protocol logic.

## 2) Parity checklist

- Same chain stack: Cosmos SDK + Cosmos EVM (`ynxd`)
- Same chain id family and EVM compatibility model
- Same fee routing parameters in genesis (`x/ynx` module)
- Same governance parameter surface (on-chain parameters and process)
- Same node interfaces: RPC, REST, EVM JSON-RPC, P2P
- Same operational stack: faucet, indexer, explorer, health checks

## 3) Current competitive position

YNX should be positioned against larger chains with these practical strengths:

- Governance-first transparency: public overview endpoint for governance and fee-routing metadata.
- Builder onboarding speed: copy/paste deployment playbooks and one-command checks.
- Early ecosystem leverage: low-friction entry for validators and app teams.
- EVM compatibility: direct migration path for Solidity tools and infra.

## 4) Public API for transparency

Indexer exposes:

- `/health`
- `/stats`
- `/ynx/overview` (chain + governance + fee-routing summary)

This endpoint is intended to make economic and governance parameters machine-readable for operators and integrators.

## 5) Upgrade policy

Server processes do not auto-update from Git by default.  
Recommended production behavior:

1. Pull tagged release.
2. Rebuild binary.
3. Restart systemd services.
4. Run `public_testnet_verify.sh`.

Use helper script:

`chain/scripts/server_upgrade_apply.sh`
