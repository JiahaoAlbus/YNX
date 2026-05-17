# YNX Production Hardening Roadmap

Status: active  
Last updated: 2026-05-17  
Scope: public testnet to mainnet-candidate readiness

This document turns the remaining YNX gaps into execution gates. It is intentionally conservative: passing local tests or public-testnet smoke checks is not enough for mainnet-candidate, production, or institution-ready claims.

## Priority 0 — Public Service Reliability

Goal: public endpoints stay reachable from multiple regions and fail visibly instead of silently.

Required:

- at least two independent public RPC/REST/EVM gateway paths;
- at least two Explorer/Indexer entry paths or a documented read-only fallback;
- external uptime checks from at least three regions;
- status page/API that reports `online`, `degraded`, or `offline` per service;
- alert routing with named on-call owner and cooldown;
- weekly public runtime evidence report attached to operator notes.

Repository support:

```bash
scripts/public_uptime_slo_probe.sh --once
scripts/install_public_uptime_slo_systemd.sh
scripts/testnet_launch_grade_monitor.sh --once
./scripts/verify_submission_readiness.sh
```

Pass condition:

- 7-day endpoint availability is at least `99.5%` for website, RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub;
- P95 endpoint probe latency is below `5s`;
- no service is offline for two consecutive probe windows without an alert.

## Priority 1 — Validator Independence

Goal: the validator set is not controlled by one operator, one deployment family, or one failure domain.

Required:

- at least four bonded validators;
- at least three independent operators before mainnet-candidate wording;
- at least two cloud/provider or physical failure domains;
- at least two geographic regions;
- public P2P reachability for published peers;
- emergency validator replacement runbook tested.

Evidence:

- validator application records;
- validator operator contact/security email;
- public `/validators` and `/net_info` snapshots;
- signed operator acknowledgement for uptime and key-handling requirements.

## Priority 2 — Durable AI/Web4 Persistence

Current AI Gateway and Web4 Hub persistence is adequate for testnet demos but not enough for production.

Required:

- external durable database or append-only event log;
- schema versioning and migrations;
- backup and restore procedure with restore test evidence;
- concurrency model for multi-instance writes;
- idempotency keys for write APIs;
- retention policy for audit logs;
- disaster recovery target: RPO <= 15 minutes, RTO <= 60 minutes for testnet production preview.

Do not use production wording until JSON-file persistence is replaced or explicitly scoped to a non-production single-instance testnet.

## Priority 3 — Explorer Maturity

Required Explorer capabilities:

- address detail pages;
- transaction detail pages with events/logs;
- block detail pages;
- validator detail pages;
- governance/proposal pages;
- contract/event search;
- paginated list views;
- clear degraded/offline UI when Indexer is slow or unavailable.

Minimum public-testnet next step:

- expose stable deep links for `/blocks/:height`, `/txs/:hash`, and `/validators`;
- render "Indexer degraded" rather than generic request errors.

## Priority 4 — Security And Cryptography

Required before mainnet-candidate:

- external security audit for chain module, governance, bridge, AI/Web4 write paths, and wallet-related surfaces;
- threat model review for RPC/REST/EVM gateway exposure;
- key rotation and access control procedure;
- root policy, treasury, bridge, governance, and upgrade actions protected by multisig or threshold controls;
- ARES post-quantum strict mode only after audited provider integration;
- incident response and rollback drill completed.

Evidence:

- audit report or issue tracker export;
- fixes merged or explicit risk acceptance;
- secrets scan report;
- runbook drill notes.

## Priority 5 — Legal, Compliance, And Public Wording

Required:

- production Terms and Privacy Policy on `ynxweb4.com`;
- support and security contact addresses;
- company/legal entity and accounting ownership;
- counsel review of non-custodial, no-exchange, no-stablecoin, and no-consumer-KYC boundaries;
- export compliance review for cryptography;
- no token price, guaranteed profit, or "unbreakable security" claims.

Correct wording until all gates pass:

`YNX public testnet is live and usable. Mainnet-candidate readiness still depends on independent validator expansion, production-grade service reliability, durable persistence, external security review, and legal sign-off.`

## Priority 6 — Mobile Client Readiness

Required before real App Store submission:

- audited wallet generation and signing;
- transaction simulation, fee estimation, broadcast, receipt, and failure states;
- recovery/import flows and seed backup education;
- biometric and local-device security testing;
- privacy policy URL and App Store metadata;
- IPv6/NAT64, poor-network, cold-start, memory, and accessibility test evidence.

## Weekly Operating Loop

Every week until mainnet-candidate:

1. Run public uptime probe and archive `output/public_uptime_slo/LATEST_REPORT.md`.
2. Run strict readiness and archive the generated report.
3. Update validator independence evidence.
4. Review AI/Web4 persistence and backup evidence.
5. Review security/audit issue status.
6. Confirm public website wording still matches the current gate state.
