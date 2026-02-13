# Public Testnet Operations (v0)

Status: v0  
Last updated: 2026-02-13  
Canonical language: English

## 1. Goals

- Public testnet with multiple independent validators.
- Fast blocks with deterministic system contracts.
- Observable, debuggable, and operationally safe.

## 2. Minimum decentralization bar

To claim real testnet decentralization, the following must be true:

- Validators run on **separate physical or cloud machines**, not one host.
- At least **4 independent operators** control keys and servers.
- No shared key material, no shared admin access.
- At least **2 independent seed nodes** are reachable publicly.

## 3. Recommended topology (baseline)

- 1–2 seed nodes (public P2P only)
- 1–2 public RPC nodes (JSON-RPC + REST + gRPC)
- N validator nodes (private RPC disabled)
- 1 faucet (rate-limited)
- 1 indexer + explorer

## 4. Seed node policy

Seed nodes should:

- Run with P2P only (RPC disabled).
- Be distributed across different regions/providers.
- Be listed in `YNX_SEEDS`.

## 5. RPC node policy

Public RPC nodes should:

- Enable JSON-RPC and gRPC.
- Use restrictive rate limits and monitoring.
- Be separate from validator machines.

## 6. Security baseline

- Keys stored on dedicated hosts; no shared disks.
- 2FA/SSH keys required for node access.
- No validator key on public RPC machines.
- Daily backup of config + keys.

## 7. Health checks

Use the built-in healthcheck:

```bash
cd chain
./scripts/testnet_healthcheck.sh
```

## 8. Seeds / peers configuration

To update seeds and persistent peers:

```bash
cd chain
./scripts/testnet_configure_seeds.sh
```

The script uses:

- `YNX_HOME` (default `chain/.testnet`)
- `YNX_SEEDS`
- `YNX_PERSISTENT_PEERS`
