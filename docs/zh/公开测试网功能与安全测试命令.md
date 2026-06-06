# YNX 公开测试网功能与安全测试命令

状态：active  
最后更新：2026-06-06  
范围：公开测试网 `ynx_9102-1`，EVM chain id `9102`

## 1. 当前目标

YNX 现在的测试网目标是：把链、交易、跨链、AI、Web4、网站、监控和安全负测做成可验收的主网级测试网标准。

当前已经上线的核心功能：

- YNX L1 公测网：Cosmos/Tendermint + EVM RPC；
- 原生资产：`NYXT / anyxt`；
- 主流 wrapped 资产：`wBTC.y`、`wETH.y`、`wBNB.y`、`wUSDT.y`、`wUSDC.y`；
- 合成测试稳定资产：`YUSD.test`，不可赎回、无主网价值；
- 测试 AMM：`wUSDC.y/YUSD.test`、`wETH.y/YUSD.test`；
- Bridge Service：Sepolia 已有自动 full-loop 测试，BTC/BSC/TRON route 支持 manual proof 测试；
- Web4 Hub：policy、session、agent、tool、intent、审计；
- AI Gateway：智能问答、任务、vault、payment、x402、链上 settlement；
- 本地服务器模型：Ollama；目标模型为 `qwen3:14b`，官方事实类答案仍以实时链/RPC查询为准；
- 网站：`https://www.ynxweb4.com`，含 AI console、bridge、trading、readiness 文档页。

## 2. 一键总验收

优先在腾讯云服务器执行：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_security_gate.sh && scripts/public_testnet_extreme_readiness.sh && scripts/public_bridge_full_loop_probe.sh && scripts/public_ai_onchain_settlement_probe.sh && scripts/public_uptime_slo_probe.sh --once'
```

也可以从你的 Mac 触发服务器验收：

```bash
cd /Users/huangjiahao/Desktop/YNX
scripts/server_public_acceptance.sh
```

服务器上每条命令单独跑：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237
cd /home/ubuntu/YNX

scripts/public_security_gate.sh
scripts/public_testnet_extreme_readiness.sh
scripts/public_bridge_full_loop_probe.sh
scripts/public_ai_onchain_settlement_probe.sh
scripts/public_uptime_slo_probe.sh --once
```

如果只想先看安全和 AI/交易主线，跑：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_security_gate.sh && scripts/public_bridge_full_loop_probe.sh && scripts/public_ai_onchain_settlement_probe.sh'
```

## 3. 本地代码测试

```bash
cd /Users/huangjiahao/Desktop/YNX

npm -C infra/ai-gateway test -- --test-reporter=spec
npm -C infra/web4-hub test -- --test-reporter=spec
npm -C infra/bridge-service test -- --test-reporter=spec
npm -C packages/contracts test
```

网站：

```bash
cd /Users/huangjiahao/Desktop/ynx-web4-website-new
npm run build
npm run lint
```

## 4. 公开服务健康检查

```bash
curl -s https://rpc.ynxweb4.com/status | jq
curl -s https://evm.ynxweb4.com \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' | jq
curl -s https://rest.ynxweb4.com/cosmos/base/tendermint/v1beta1/node_info | jq
curl -s https://faucet.ynxweb4.com/health | jq
curl -s https://indexer.ynxweb4.com/health | jq
curl -s https://explorer.ynxweb4.com/ -I
curl -s https://ai.ynxweb4.com/health | jq
curl -s https://web4.ynxweb4.com/ready | jq
curl -s https://rpc.ynxweb4.com/bridge/health | jq
```

## 5. 资产与交易检查

核心地址：

```bash
export YNX_EVM=https://evm.ynxweb4.com
export YUSD_TEST=0xAC4Bb6f5F98aA9175B939CD867508270B0d56172
export WBTC_Y=0x1887Eb24feefB6538CBc2140B148ba831f313991
export WETH_Y=0x5715Bb5a7B050234A225fC88FF74885eF55E9339
export WBNB_Y=0x1A4DC3435b6A090824765970521cb782262523Ef
export WUSDT_Y=0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1
export WUSDC_Y=0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c
export WUSDC_YUSD_PAIR=0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E
export WETH_YUSD_PAIR=0x84868c7554efB510964a7b54E4afcAE11275475c
```

读 wrapped token 信息：

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

读 AMM 报价：

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

真实 swap 命令见服务器或仓库文档：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'sed -n "1,180p" /home/ubuntu/YNX/docs/zh/测试网交易手册.md'
```

## 6. Bridge 检查

全闭环探针：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_bridge_full_loop_probe.sh'
```

route readiness：

```bash
curl -s https://rpc.ynxweb4.com/bridge/route-readiness | jq
```

安全负测：没有 operator token 时，写路径必须拒绝。

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{}' \
  https://rpc.ynxweb4.com/bridge/watchers/scan

curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{}' \
  https://rpc.ynxweb4.com/bridge/deposits/prove

curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{}' \
  https://rpc.ynxweb4.com/bridge/withdrawals/request
```

期望：`401` 或 `403`。

## 7. AI 能力范围与测试

YNX AI 不是只做“限制 AI 能干什么”。当前定位应更全面：

- YNX 状态智能层：读取链、bridge、资产、Web4、AI settlement 的实时事实；
- AI agent 权限层：通过 Web4 policy/session 控制 agent 能调用哪些工具、花多少钱、执行多少次；
- AI 结算层：job、vault、payment、x402、on-chain settlement；
- AI 风控层：官方答案用实时事实生成，LLM 原始输出默认隐藏，避免模型胡说路线状态；
- AI 运维层：给 operator 和用户解释当前链、交易、跨链、结算是否 ready；
- AI 产品层：官网 `/ai` console 可直接问当前 YNX 状态。

AI 健康：

```bash
curl -s https://ai.ynxweb4.com/health | jq
curl -s https://ai.ynxweb4.com/ai/intelligence/brief | jq
```

AI 问答：

```bash
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"用中文简短总结 YNX 当前 AI、交易、跨链状态。"}' | jq
```

查看服务器模型原始输出，需要显式 opt-in：

```bash
curl -s https://ai.ynxweb4.com/ai/chat \
  -H 'content-type: application/json' \
  --data '{"message":"用中文简短总结 YNX 当前 AI、交易、跨链状态。","include_model_answer":true}' | jq
```

链上 AI settlement 探针：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'cd /home/ubuntu/YNX && scripts/public_ai_onchain_settlement_probe.sh'
```

AI 安全负测：没有 Web4 policy/session 时，创建 job/vault 必须失败。

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{"job_id":"security_probe_job","creator":"probe","reward":"1"}' \
  https://ai.ynxweb4.com/ai/jobs

curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{"vault_id":"security_probe_vault","owner":"probe","balance":1}' \
  https://ai.ynxweb4.com/ai/vaults
```

期望：`400`、`401` 或 `403`。

## 8. Web4 权限与工具安全

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{"policy_id":"missing","action":"ai.job.create"}' \
  https://web4.ynxweb4.com/web4/internal/authorize

curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{"tool_id":"security_private_probe","base_url":"http://127.0.0.1:1","allowed_paths":["/"]}' \
  https://web4.ynxweb4.com/web4/tools

curl -s -o /dev/null -w '%{http_code}\n' \
  -H 'content-type: application/json' \
  --data '{"agent_id":"security_probe_agent"}' \
  https://web4.ynxweb4.com/web4/agents
```

期望：internal authorize 返回 `401/403`；私网工具注册返回 `400`；无 policy agent 创建返回 `400/401/403`。

## 9. 网站与浏览器安全

```bash
curl -sI https://www.ynxweb4.com/ | grep -Ei 'content-security-policy|x-content-type-options|x-frame-options|referrer-policy'
curl -sI https://explorer.ynxweb4.com/ | grep -Ei 'content-security-policy|x-content-type-options|x-frame-options|referrer-policy'
curl -s https://www.ynxweb4.com/ai | grep '<div id="root"'
```

## 10. 服务器服务检查

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'systemctl list-units --type=service --no-pager | grep -i ynx'

ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'journalctl -u ynx-v2-node.service -n 80 --no-pager'
```

一次性 probe service 如果显示 `failed`，先看对应报告和 timer，而不是直接当核心服务宕机：

```bash
ssh -i /Users/huangjiahao/Downloads/Huang.pem ubuntu@43.153.202.237 \
  'systemctl list-timers --no-pager | grep -i ynx || true; ls -la /home/ubuntu/YNX/output | tail'
```

## 11. 验收判断

可以称为“主网级标准的测试网”的最低验收：

- `public_security_gate.sh` 无 FAIL；
- `public_testnet_extreme_readiness.sh` strict 模式通过；
- `public_bridge_full_loop_probe.sh` 记录 Sepolia full-loop；
- `public_ai_onchain_settlement_probe.sh` 能完成 vault/job/commit/finalize；
- 本地代码测试全部通过；
- 网站和 explorer 安全头存在；
- operator 写路径无 token 必须拒绝；
- AI 官方答案能说清楚 route 边界，不把测试 wrapped asset 说成真实主网资产本体。

主网仍然需要额外完成：外部安全审计、更多独立验证人、灾备演练、真实资产发行/托管/非托管法律边界、真实稳定币发行方或合规合作、生产级流动性和风控。
