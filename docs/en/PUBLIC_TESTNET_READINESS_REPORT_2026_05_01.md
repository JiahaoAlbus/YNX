# YNX Public Testnet Readiness Report — 2026-05-01

Status: Degraded public testnet readiness
Generated from local operator verification on 2026-05-01
Canonical language: English

## Executive Result

YNX public testnet services are live and usable for builders, demos, API integration, Web4 workflow testing, and AI settlement workflow testing.

The testnet is not yet industry-grade for decentralized public-network claims because public P2P redundancy and validator-set diversity are below the required threshold:

- public RPC `/net_info`: `n_peers=0`;
- public validator set: `1` validator;
- industry-grade public testnet target: at least `2` reachable public peers and at least `4` independently operated validators before broad mainnet-candidate messaging.

## Verified Working Surfaces

Runtime evidence passed:

- docs readiness: `13/13 PASS`;
- public runtime evidence: `20/20 PASS`;
- extreme readiness in degraded mode: `25 PASS`, `0 WARN`, `2 FAIL`;
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
- validator signing: `1/1`.

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

## Current Blocking Gap

The remaining gap is network decentralization and public P2P resilience.

Required action:

1. Restore SSH access to the three secondary Tencent nodes or create replacement nodes.
2. Run each as a synced full node or validator candidate.
3. Open TCP `36656` on each node.
4. Configure persistent peers on the canonical node and the secondary nodes.
5. Re-run `scripts/public_testnet_extreme_readiness.sh`.
6. Do not present the network as mainnet-candidate until the script passes strict mode.

Current secondary-node access status from local operator check:

- `43.162.100.54`: SSH key rejected;
- `43.164.132.81`: SSH key rejected;
- `43.134.23.58`: SSH key rejected after host-key mismatch was bypass-tested with isolated known-host handling;
- `43.153.202.237`: accessible and running the canonical full public service stack.

## Industry Readiness Classification

- Service availability: PASS.
- Web4 / AI write path: PASS.
- Documentation readiness: PASS.
- Local code tests: PASS.
- P2P redundancy: FAIL.
- Validator decentralization: FAIL.

Overall: public testnet is usable, but not yet industry-grade decentralized readiness.

Strict readiness command:

```bash
./scripts/public_testnet_extreme_readiness.sh
```

Current strict blockers:

- `public_p2p_peers`: `n_peers=0`, required minimum `2`;
- `validator_set_size`: `validators=1`, required minimum `4`.
