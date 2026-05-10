# YNX Public Testnet Status - 2026-05-02

Status: active public testnet  
Track: `v2-web4`  
Chain ID: `ynx_9102-1`  
EVM chain ID: `9102` / `0x238e`

Latest launch-grade testnet gate:

```bash
./scripts/public_testnet_extreme_readiness.sh --output-dir output/readiness_launch_grade_current
# PASS=35 WARN=0 FAIL=0
```

## Runtime Snapshot

Observed from the public HTTPS endpoints on 2026-05-02 Asia/Shanghai:

- RPC, REST, EVM JSON-RPC, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub responded.
- The chain was not catching up and continued producing blocks during repeated checks.
- Indexer height tracked live chain height during the check window.
- Public P2P port `36656` was reachable on the observed validator/full-node IPs.
- The launch-grade readiness gate checked staking bonded status, jailed status, slashing signing health, latest-block signatures, and indexer signing view.

## Validator Set

The staking module reported four bonded validators. All four were unjailed and slashing signing info showed `missed_blocks_counter=0` during the check.

| Moniker | Operator | Status | Jailed |
|---|---|---|---|
| `ynx-v2-web4` | `ynxvaloper169mn3r0xm08te6n47raamerhvds2rq6ejgtqml` | `BOND_STATUS_BONDED` | `false` |
| `ynx-tencent-singapore-peer` | `ynxvaloper1nqr4v23j83g5fk99p2kcarc7pym99sdwmfhkv4` | `BOND_STATUS_BONDED` | `false` |
| `ynx-tencent-sv` | `ynxvaloper1euhh7cav7rj6pusqnjal6apeu9u872dkjh53f7` | `BOND_STATUS_BONDED` | `false` |
| `ynx-tencent-seoul` | `ynxvaloper16ht5gs0helfsgv07q6hl8xa0vtru7guuejdxpk` | `BOND_STATUS_BONDED` | `false` |

Indexer `/validators` also reported `total=4` and `signed_count=4`.

## Gaps To Close

1. Public RPC/REST gateway stability is now covered by retrying launch-grade checks, but production-quality HA still requires at least one additional public gateway or failover path.
2. Validator independence is still limited. The live set has four bonded validators, but the observed topology is still concentrated in the same deployment family. Mainnet-candidate positioning requires independent operators and failure domains.
3. AI Gateway and Web4 Hub are adequate for public-testnet workflows but still use single-instance JSON-file persistence. Production operation needs external durable storage, backup/restore, migrations, and multi-instance deployment.
4. Explorer and Indexer are useful for health and overview checks but still lack mature explorer depth: address pages, transaction detail UX, contract event views, validator detail pages, governance pages, and richer search.
5. ARES has SDK-level strict/observe verification and pluggable post-quantum hooks, but audited ML-DSA/SLH-DSA provider integration is still required before strict mainnet enforcement.
6. Account abstraction and parallel execution are currently roadmap tracks, not production-complete features.

## Current Wording Boundary

Use:

`YNX public testnet is live and launch-grade for testnet operation, with core services, public P2P reachability, and a four-validator bonded set online. Mainnet-candidate readiness still depends on independent validator expansion, production-grade service persistence, and external security review.`

Do not claim production, mainnet-candidate, institution-ready, or fully decentralized validator status yet.
