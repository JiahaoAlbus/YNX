# YNX Public Testnet Readiness Report — 2026-05-01

Status: Strict public testnet readiness passed
Generated from local operator verification on 2026-05-01
Canonical language: English

## Executive Result

YNX public testnet services are live and usable for builders, demos, API integration, Web4 workflow testing, and AI settlement workflow testing.

The testnet now meets the current strict public-testnet readiness gate:

- public RPC `/net_info`: `n_peers=3`;
- public validator set: `4` bonded validators;
- strict readiness: `27 PASS`, `0 WARN`, `0 FAIL`.

## Verified Working Surfaces

Runtime evidence passed:

- docs readiness: `13/13 PASS`;
- public runtime evidence: `20/20 PASS`;
- strict extreme readiness: `27 PASS`, `0 WARN`, `0 FAIL`;
- RPC: live, correct chain ID, block height advancing;
- EVM JSON-RPC: live, `eth_chainId=0x238e`;
- REST: live, correct chain ID;
- Faucet: health endpoint live;
- Indexer: health, overview, network descriptor, validator endpoint live;
- Explorer: config endpoint live;
- AI Gateway: health and readiness live with policy enforcement enabled;
- Web4 Hub: health and readiness live with policy enforcement and internal authorization enabled.

Observed runtime sample:

- chain ID: `ynx_9102-1`;
- EVM chain ID: `0x238e`;
- track: `v2-web4`;
- block advancement: `+12` blocks over `8s`;
- validator signing: `4/4`.

## Verified Write-Path Smoke

HTTPS write-path smoke passed against production public domains:

- Web4 policy create;
- Web4 session issue;
- wallet bootstrap and verify;
- policy enforcement rejection without session;
- AI vault create;
- AI job create, commit, finalize;
- AI payout payment creation;
- direct machine-payment charge;
- x402 unpaid `402` and paid resource access;
- identity create;
- agent create;
- agent self-update;
- agent replicate;
- intent create, claim, challenge, finalize;
- policy pause and resume.

Latest smoke IDs:

- policy: `policy_a4655a53d91d7741`;
- vault: `vault_2380906d8211982a`;
- job: `job_efa0ebee9426478f`;
- payment: `pay_f2e38489e85d558b`;
- identity: `identity_1812236bbd87889d`;
- agent: `agent_ff4e306c6e5007d9`;
- child agent: `agent_11a5f3bbfc3ba50f`;
- intent: `intent_12ba9890dfe23fcc`.

## Local Test Results

Passed:

- `npm test` at repository root: contracts and SDK tests pass;
- `npm run lint` at repository root: contracts and SDK lint pass;
- `npm test` in `infra/web4-hub`: pass;
- `npm test` in `infra/ai-gateway`: pass;
- `CGO_ENABLED=0 go test $(go list ./... | grep -v '/third_party/')` in `chain`: pass;
- `./scripts/verify_docs_readiness.sh`: pass;
- `./scripts/prepare_audit_compliance_pack.sh --skip-runtime-evidence`: pass.

Environment note:

- plain `go test` without `CGO_ENABLED=0` is blocked on this Mac by the local Xcode license prompt, not by a YNX code failure.

## Current Validator / Peer Topology

The public network is currently backed by one canonical public service node plus three Tencent validator peers:

- `43.153.202.237`: canonical public service node, moniker `ynx-v2-web4`, node id `7b8bf4128aeb20e12648086a9fa9b6c4a28cb4e7`;
- `43.162.100.54`: Silicon Valley validator peer, moniker `ynx-tencent-sv`, node id `aac4cf1eff04ea0bbfdb0762808553ef820d16d2`;
- `43.164.132.81`: Seoul validator peer, moniker `ynx-tencent-seoul`, node id `ca7292a1529787d34983158934db8c29162d0060`;
- `43.134.23.58`: Singapore validator peer, moniker `ynx-tencent-singapore-peer`, node id `c3fdd22c9df6c26dc9cbad88c65c5a1fb1cf0598`.

Operational notes:

- P2P uses TCP `36656` on all four nodes.
- Join/bootstrap nodes must keep CometBFT PEX enabled because the canonical public peer advertises the PEX channel.
- The secondary validators were seeded from a canonical data snapshot, then promoted with `MsgCreateValidator` and additional delegation so all validators have non-zero voting power and sign the live chain.

## Industry Readiness Classification

- Service availability: PASS.
- Web4 / AI write path: PASS.
- Documentation readiness: PASS.
- Local code tests: PASS.
- P2P redundancy: PASS.
- Validator topology redundancy: PASS.
- Validator independence claim: NOT CLAIMED.

Overall: public testnet passes the current strict readiness gate.

Strict readiness command:

```bash
./scripts/public_testnet_extreme_readiness.sh
```

Latest strict result:

- `public_p2p_peers`: `n_peers=3`, required minimum `2`;
- `validator_set_size`: `validators=4`, required minimum `4`;
- `validator_signing`: `signed=4/4`.
