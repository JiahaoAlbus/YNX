# YNX Builder Quickstart

Status: active  
Last updated: 2026-05-16  
Scope: public testnet `ynx_9102-1`

YNX exposes three builder surfaces on the public testnet:

- EVM JSON-RPC for Solidity contracts and Ethereum-compatible tooling.
- Web4 Hub for policy-bounded identities, agents, sessions, intents, and audit logs.
- AI Gateway for AI job, vault, payment, commit, and settlement workflows.

Testnet assets have no mainnet value. Do not use production funds or production secrets.

## Network Constants

| Field | Value |
|---|---|
| Cosmos chain ID | `ynx_9102-1` |
| EVM chain ID | `9102` / `0x238e` |
| Native denom | `anyxt` |
| Public RPC | `https://rpc.ynxweb4.com` |
| EVM RPC | `https://evm.ynxweb4.com` |
| REST | `https://rest.ynxweb4.com` |
| Faucet | `https://faucet.ynxweb4.com` |
| Indexer | `https://indexer.ynxweb4.com` |
| Explorer | `https://explorer.ynxweb4.com` |
| AI Gateway | `https://ai.ynxweb4.com` |
| Web4 Hub | `https://web4.ynxweb4.com` |

## 1. Verify Live Network Status

```bash
curl -s https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network, .result.sync_info.latest_block_height, .result.sync_info.catching_up'
curl -s https://indexer.ynxweb4.com/health | jq
curl -s https://faucet.ynxweb4.com/health | jq
```

Expected chain ID:

```text
ynx_9102-1
```

## 2. Use The EVM Surface

Add the network to an EVM wallet or Hardhat configuration:

```text
Network name: YNX Web4 Public Testnet
RPC URL: https://evm.ynxweb4.com
Chain ID: 9102
Currency symbol: ANYXT
Explorer: https://explorer.ynxweb4.com
```

Check the EVM chain ID:

```bash
curl -s https://evm.ynxweb4.com \
  -H 'content-type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' | jq -r '.result'
```

Expected result:

```text
0x238e
```

## 3. Use The Web4 Hub

The Web4 Hub coordinates bounded agent authority.

Core endpoint groups:

- `GET /health`
- `POST /web4/identities`
- `POST /web4/agents`
- `POST /web4/policies`
- `POST /web4/policies/:id/sessions`
- `POST /web4/intents`
- `GET /web4/audit`

Start with:

```bash
curl -s https://web4.ynxweb4.com/health | jq
```

Reference:

- `docs/en/WEB4_FOR_YNX.md`
- `docs/en/YNX_v2_WEB4_API.md`
- `infra/openapi/ynx-v2-web4.yaml`

## 4. Use The AI Gateway

The AI Gateway handles machine-payment and AI settlement flows.

Core endpoint groups:

- `GET /health`
- `POST /ai/vaults`
- `POST /ai/jobs`
- `POST /ai/jobs/:id/commit`
- `POST /ai/jobs/:id/finalize`
- `POST /ai/payments`
- `GET /x402/resource`

Start with:

```bash
curl -s https://ai.ynxweb4.com/health | jq
```

Reference:

- `docs/en/AI_WEB4_OFFICIAL_DEMO.md`
- `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
- `infra/openapi/ynx-v2-ai.yaml`

## 5. Run The Official Local AI/Web4 Demo

From the repository root:

```bash
./scripts/ai_web4_settlement_demo.sh
```

The demo starts temporary local Web4 Hub and AI Gateway processes, then writes JSON evidence under:

```text
output/ai_web4_demo/<run-id>/
```

It proves the bounded Web4 policy, session key, AI job, result commit, finalization, and vault reward settlement flow.

## 6. Install The YNX CLI

```bash
curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/scripts/install_ynx.sh | bash
export PATH="$HOME/.local/bin:$PATH"
ynx join --role full-node
```

Use `ynx join --role validator` only after operator review and funding if you are applying to become a consensus validator candidate.

## Safety Boundary

- Public testnet only.
- No production funds.
- No private keys or mnemonics in source control.
- No mainnet, production, or investment-return claims until the mainnet readiness gates are complete.

