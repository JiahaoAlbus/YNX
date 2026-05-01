# YNX External Validator Onboarding Packet

Status: active  
Scope: public testnet `ynx_9102-1`  
Canonical language: English

## Invitation

YNX is onboarding independent public-testnet validators for the v2 Web4 track.

This is testnet only. Tokens have no mainnet value. The goal is to improve network resilience, public P2P reachability, and independent operator coverage before any mainnet-candidate language is used.

## Network

- Chain ID: `ynx_9102-1`
- EVM chain ID: `9102` / `0x238e`
- Denom: `anyxt`
- RPC: `https://rpc.ynxweb4.com`
- REST: `https://rest.ynxweb4.com`
- EVM RPC: `https://evm.ynxweb4.com`
- Faucet: `https://faucet.ynxweb4.com`
- Explorer: `https://explorer.ynxweb4.com`
- Repository: `https://github.com/JiahaoAlbus/YNX`

## Operator Requirements

Required:

- independent server and key custody;
- public static IP or stable DNS for P2P;
- `26656/tcp` reachable from the public internet;
- no shared validator keys with any other operator;
- security contact that can respond to incidents;
- willingness to run a synced node before submitting `create-validator`.

Recommended host:

- 4 vCPU;
- 8 GB RAM;
- 200 GB SSD;
- Ubuntu 22.04 or newer;
- systemd access.

## Join Flow

1. Install the repo and binary.

```bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="$HOME/.local/bin:$PATH"
```

2. Join as a validator node first.

```bash
ynx join --role validator
```

3. Confirm sync.

```bash
curl -s http://127.0.0.1:36657/status \
  | jq -r '.result.node_info.network,.result.sync_info.latest_block_height,.result.sync_info.catching_up'
```

4. Prepare validator key and submit `create-validator`.

Follow:

- `docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md`

5. Send coordinator submission.

## Submission Fields

Send:

- operator name;
- moniker;
- region and provider;
- security contact email;
- node ID;
- P2P endpoint: `node_id@host:26656`;
- validator account: `ynx1...`;
- validator operator: `ynxvaloper1...`;
- optional public RPC endpoint;
- uptime target;
- confirmation that keys are independently controlled.

## Coordinator Preflight

From the coordinator machine:

```bash
scripts/validator_candidate_check.sh \
  --p2p <node_id@host:26656> \
  --valoper <ynxvaloper1...>
```

If the candidate exposes a temporary RPC endpoint:

```bash
scripts/validator_candidate_check.sh \
  --p2p <node_id@host:26656> \
  --rpc http://<host>:36657 \
  --valoper <ynxvaloper1...>
```

Then run the full network gate:

```bash
./scripts/public_testnet_extreme_readiness.sh
```

## Acceptance Criteria

Before listing the operator as active:

- P2P TCP check passes;
- node is synced or near synced;
- validator is `BOND_STATUS_BONDED`;
- validator is not jailed;
- launch-grade readiness remains `PASS`;
- operator improves region/provider diversity.

## Incident Expectations

Operators should notify the coordinator before planned downtime. Emergency contact is required for:

- validator jailed;
- missed blocks observed;
- key compromise suspicion;
- node outage longer than 30 minutes;
- P2P endpoint change.
