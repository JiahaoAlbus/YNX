# YNX Testnet Launch-Grade Runbook

Status: active  
Scope: public testnet only  
Canonical language: English

## Definition

Launch-grade testnet means the network is still explicitly a testnet, but it is operated with production-style controls:

- public endpoints are redundant enough for developers;
- validator status is checked at both CometBFT and staking layers;
- public P2P ports are externally reachable;
- write-path services have readiness checks and backup expectations;
- failures produce actionable reports instead of informal screenshots.

This does not mean mainnet, production, institution-ready, or fully decentralized.

## Required Daily Gate

Run:

```bash
./scripts/public_testnet_extreme_readiness.sh
```

The strict gate must pass with zero failures before public launch claims are refreshed. The gate checks:

- RPC, REST, EVM JSON-RPC, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub fetches;
- chain ID, EVM chain ID, and Web4 track;
- block advancement;
- RPC peer count;
- external TCP reachability for P2P port `36656`;
- CometBFT validator set size;
- staking bonded validator count;
- jailed validator status;
- slashing signing health;
- latest block commit signature count;
- indexer validator signing view.

Capture evidence:

```bash
./scripts/capture_public_runtime_evidence.sh
```

Continuous monitor:

```bash
scripts/testnet_launch_grade_monitor.sh
```

For alert webhooks:

```bash
ALERT_WEBHOOK_URL=https://example.invalid/hook \
  scripts/testnet_launch_grade_monitor.sh
```

## Validator Standard

Minimum public-testnet standard:

- at least 4 bonded validators;
- all bonded validators are unjailed;
- `missed_blocks_counter=0` during the check window;
- latest block has at least 4 commit signatures;
- at least 2 externally reachable public P2P peers.

Launch-grade target:

- at least 4 bonded validators across at least 2 regions;
- at least 2 independent operators outside the founding deployment account;
- at least 2 infrastructure failure domains;
- public RPC nodes are separate from validator keys.

## Public Endpoint Standard

Each public endpoint must pass HTTPS checks:

- `https://rpc.ynxweb4.com/status`
- `https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info`
- `https://evm.ynxweb4.com`
- `https://faucet.ynxweb4.com/health`
- `https://indexer.ynxweb4.com/health`
- `https://explorer.ynxweb4.com/config`
- `https://ai.ynxweb4.com/ready`
- `https://web4.ynxweb4.com/ready`

Any transient failure must be retried with the built-in readiness script. Repeated failures mean the gateway or upstream service is not launch-grade.

## Persistence And Backup Standard

For current JSON-backed services:

- AI Gateway data file must be on persistent disk.
- Web4 Hub data file must be on persistent disk.
- Indexer data must be disposable or backed up depending on whether it is used as canonical evidence.
- Daily backups must include chain config, validator keys, node keys, app state data, and service data directories.
- Restore must be tested on a clean host before claiming launch-grade operation.

Preferred next upgrade:

- move AI Gateway and Web4 Hub state to durable database storage;
- keep append-only audit logs outside the mutable service JSON file;
- run service backups with checksum validation.

## Incident Standard

Severity triggers:

- no new blocks for two readiness windows;
- any bonded validator jailed or tombstoned;
- latest block signatures below validator quorum expectation;
- public RPC/REST/EVM all unavailable after retries;
- AI/Web4 readiness returns `ok=false`;
- faucet or policy endpoints accept unauthorized writes.

Minimum response:

1. Freeze a runtime evidence report.
2. Capture validator and slashing responses.
3. Confirm whether the issue is chain consensus, public gateway, or service layer.
4. Announce testnet degraded status if public write paths are affected.
5. Restore from backup or fail over public endpoints.

## Remaining Non-Code Launch-Grade Work

These cannot be completed from this repository alone:

- recruit and bond independent external validators;
- deploy at least one additional public RPC/sentry outside the current provider/account;
- configure external monitoring alerts and on-call ownership;
- complete external security review;
- test backup restore on a clean machine.
