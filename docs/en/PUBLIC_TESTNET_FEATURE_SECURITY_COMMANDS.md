# YNX Public Testnet Feature and Security Commands

Status: active  
Last updated: 2026-06-06  
Scope: public testnet `ynx_9102-1`, EVM chain id `9102`

## Goal

YNX public testnet is being hardened as a mainnet-standard testnet across chain, trading, bridge, AI, Web4, website, monitoring, and negative security tests.

Live surfaces:

- YNX L1 public testnet with Cosmos/Tendermint and EVM RPC;
- native `NYXT / anyxt`;
- wrapped mainstream assets: `wBTC.y`, `wETH.y`, `wBNB.y`, `wUSDT.y`, `wUSDC.y`;
- synthetic test stable asset: `YUSD.test`, not redeemable and no mainnet value;
- test AMM pairs: `wUSDC.y/YUSD.test`, `wETH.y/YUSD.test`;
- Bridge Service with Sepolia full-loop testing and BTC/BSC/TRON manual-proof routes;
- Web4 Hub policy, session, agent, tool, intent, and audit controls;
- AI Gateway intelligence, jobs, vaults, payments, x402, and on-chain settlement;
- server-local Ollama, real-time model `qwen3:1.7b`, with `qwen3:4b/8b/14b` retained for background analysis; official factual answers remain grounded in live chain/RPC queries;
- website at `https://www.ynxweb4.com`.

## One-command Acceptance Set

Run the acceptance set on the Tencent Cloud server first:

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_security_gate.sh && scripts/public_testnet_extreme_readiness.sh && scripts/public_bridge_full_loop_probe.sh && scripts/public_ai_onchain_settlement_probe.sh && scripts/public_uptime_slo_probe.sh --once'
```

Or trigger the same server-side suite from the local Mac:

```bash
cd /Users/huangjiahao/Desktop/YNX
scripts/server_public_acceptance.sh
```

Individual server commands:

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237
cd /home/ubuntu/YNX

scripts/public_security_gate.sh
scripts/public_testnet_extreme_readiness.sh
scripts/public_bridge_full_loop_probe.sh
scripts/public_ai_onchain_settlement_probe.sh
scripts/public_uptime_slo_probe.sh --once
```

## Local Tests

```bash
cd /Users/huangjiahao/Desktop/YNX

npm -C infra/ai-gateway test -- --test-reporter=spec
npm -C infra/web4-hub test -- --test-reporter=spec
npm -C infra/bridge-service test -- --test-reporter=spec
npm -C packages/contracts test
```

Website:

```bash
cd /Users/huangjiahao/Desktop/ynx-web4-website-new
npm run build
npm run lint
```

## Public Health

```bash
curl -s https://rpc.ynxweb4.com/status | jq
curl -s https://evm.ynxweb4.com \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' | jq
curl -s https://faucet.ynxweb4.com/health | jq
curl -s https://indexer.ynxweb4.com/health | jq
curl -s https://ai.ynxweb4.com/health | jq
curl -s https://web4.ynxweb4.com/ready | jq
curl -s https://rpc.ynxweb4.com/bridge/health | jq
```

## All Service Commands

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'systemctl list-units --type=service --no-pager | grep -i ynx'

ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'systemctl is-active ynx-v2-node.service ynx-v2-indexer.service ynx-v2-explorer.service ynx-v2-faucet.service ynx-v2-bridge-service.service ynx-v2-web4-hub.service ynx-v2-ai-gateway.service'

ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'journalctl -u ynx-v2-node.service -u ynx-v2-indexer.service -u ynx-v2-bridge-service.service -u ynx-v2-web4-hub.service -u ynx-v2-ai-gateway.service -n 160 --no-pager'

ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_security_gate.sh && scripts/public_testnet_extreme_readiness.sh && scripts/public_bridge_full_loop_probe.sh && scripts/public_ai_onchain_settlement_probe.sh && scripts/public_uptime_slo_probe.sh --once'
```

## Asset and Trading Checks

```bash
export YNX_EVM=https://evm.ynxweb4.com
export YUSD_TEST=0xAC4Bb6f5F98aA9175B939CD867508270B0d56172
export WBTC_Y=0x1887Eb24feefB6538CBc2140B148ba831f313991
export WETH_Y=0x5715Bb5a7B050234A225fC88FF74885eF55E9339
export WBNB_Y=0x1A4DC3435b6A090824765970521cb782262523Ef
export WUSDT_Y=0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1
export WUSDC_Y=0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c
export WUSDC_YUSD_PAIR=0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E
```

```bash
node <<'NODE'
const { JsonRpcProvider, Contract } = require("ethers");
const provider = new JsonRpcProvider(process.env.YNX_EVM);
const erc20 = ["function name() view returns (string)","function symbol() view returns (string)","function decimals() view returns (uint8)"];
const tokens = ["YUSD_TEST","WBTC_Y","WETH_Y","WBNB_Y","WUSDT_Y","WUSDC_Y"];
(async () => {
  for (const key of tokens) {
    const c = new Contract(process.env[key], erc20, provider);
    console.log(key, await c.name(), await c.symbol(), await c.decimals());
  }
})();
NODE
```

```bash
node <<'NODE'
const { JsonRpcProvider, Contract, parseUnits, formatUnits } = require("ethers");
const provider = new JsonRpcProvider(process.env.YNX_EVM);
const pair = new Contract(process.env.WUSDC_YUSD_PAIR, ["function quote(address,uint256) view returns (uint256)"], provider);
(async () => {
  const out = await pair.quote(process.env.YUSD_TEST, parseUnits("0.1", 6));
  console.log("0.1 YUSD.test -> wUSDC.y quote:", formatUnits(out, 6));
})();
NODE
```

## Bridge Security

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_bridge_full_loop_probe.sh'
curl -s https://rpc.ynxweb4.com/bridge/route-readiness | jq
```

Unauthenticated bridge writes must fail:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{}' https://rpc.ynxweb4.com/bridge/watchers/scan
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{}' https://rpc.ynxweb4.com/bridge/deposits/prove
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{}' https://rpc.ynxweb4.com/bridge/withdrawals/request
```

Expected: `401` or `403`.

## AI Capability Coverage

YNX AI is broader than “AI agent permissions and settlement”:

- live YNX intelligence over chain, bridge, assets, Web4, and AI settlement;
- validator and consensus status from the live indexer `/validators` endpoint;
- latest EVM transaction lookup with fallback to known AI/bridge transaction evidence;
- Web4 policy/session control for agent actions, spend, tool scope, and usage;
- job, vault, payment, x402, and on-chain settlement;
- factual answer guardrails: official answers are generated from live facts, raw model text is hidden by default;
- operations assistant for route, trading, bridge, and settlement status;
- website AI console at `/ai`.

```bash
curl -s https://ai.ynxweb4.com/health | jq
curl -s https://ai.ynxweb4.com/ai/intelligence/brief | jq
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"Summarize current YNX AI, trading, and bridge status."}' | jq
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"validator status?"}' | jq
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"Summarize the latest YNX on-chain transaction."}' | jq
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"Summarize current YNX AI, trading, and bridge status.","include_model_answer":true}' | jq
```

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_ai_onchain_settlement_probe.sh'
```

Unauthenticated AI writes must fail:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{"job_id":"security_probe_job","creator":"probe","reward":"1"}' https://ai.ynxweb4.com/ai/jobs
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{"vault_id":"security_probe_vault","owner":"probe","balance":1}' https://ai.ynxweb4.com/ai/vaults
```

Expected: `400`, `401`, or `403`.

## Web4 Security

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{"policy_id":"missing","action":"ai.job.create"}' https://web4.ynxweb4.com/web4/internal/authorize
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{"tool_id":"security_private_probe","base_url":"http://127.0.0.1:1","allowed_paths":["/"]}' https://web4.ynxweb4.com/web4/tools
curl -s -o /dev/null -w '%{http_code}\n' -H 'content-type: application/json' --data '{"agent_id":"security_probe_agent"}' https://web4.ynxweb4.com/web4/agents
```

## Website and Explorer Headers

```bash
curl -sI https://www.ynxweb4.com/ | grep -Ei 'content-security-policy|x-content-type-options|x-frame-options|referrer-policy'
curl -sI https://explorer.ynxweb4.com/ | grep -Ei 'content-security-policy|x-content-type-options|x-frame-options|referrer-policy'
curl -s https://www.ynxweb4.com/ai | grep '<div id="root"'
```

## Server Service Check

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'systemctl list-units --type=service --no-pager | grep -i ynx'
```

## Acceptance

Mainnet-standard testnet acceptance requires:

- `public_security_gate.sh` has no FAIL;
- strict public readiness passes;
- bridge full-loop probe records Sepolia full-loop evidence;
- AI on-chain settlement probe completes vault/job/commit/finalize;
- local tests pass;
- website and explorer security headers are present;
- unauthorized operator writes are rejected;
- AI answers clearly distinguish testnet wrapped assets from real mainnet asset custody or liquidity.

Mainnet still requires external security audits, more independent validators, disaster recovery, legal review, real issuer or partner arrangements for redeemable stablecoins, and production-grade liquidity/risk controls.
