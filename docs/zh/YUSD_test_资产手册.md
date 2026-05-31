# YUSD.test 资产手册

状态：公开测试网合成资产  
最后更新：2026-05-31  
范围：YNX 公开测试网 `ynx_9102-1`

## 摘要

`YUSD.test` 是 YNX 公开测试网上的合成测试美元资产，用于测试交易对、
跨链体验、AI 支付、结算演示、账务界面和开发者集成。

`YUSD.test` 不是受监管稳定币，不能兑换 USD、USDC、USDT、法币、
银行存款或任何其它资产。

## 公开测试网合约

| 字段 | 值 |
|---|---|
| 名称 | `YUSD Test Dollar` |
| 符号 | `YUSD.test` |
| 网络 | YNX public testnet |
| EVM chain id | `9102` |
| 合约 | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172` |
| decimals | `6` |
| 初始测试供应量 | `1,000,000 YUSD.test` |
| 初始接收地址 | `0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5` |

## 适用场景

- YNX 测试网交易对报价资产；
- 不使用真实资金的稳定价值 UI 测试；
- AI agent 支付和结算记账测试；
- DEX 流动性、swap、手续费、索引测试；
- 内部 QA、演示、教程和黑客松流程。

## 禁止口径

不要把 `YUSD.test` 描述为：

- 真实美元；
- USDC、USDT 或合作方发行代币；
- 可赎回、有抵押、有储备、受保险或已审计；
- 法定货币、电子货币、储值工具或银行存款；
- 适合投资、储蓄、工资、汇款或生产级商业支付。

标准用户口径：

```text
YUSD.test 是仅用于公开测试网的合成测试资产，没有主网价值，
不能兑换法币或稳定币。
```

## 风险控制

已部署合约包含：

- `MINTER_ROLE`，用于受控测试网增发；
- `PAUSER_ROLE`，用于紧急暂停转账；
- burn 能力，用于清理测试余额；
- 6 位 decimals，匹配常见稳定币 UX。

任何主网稳定资产上线前，都必须单独完成法律、储备、托管、审计、
赎回和发行治理审查。主网稳定币发行应优先由受监管发行方或合格合作方完成，
除非法律顾问批准其它模式。

## 基础查询命令

```bash
export YNX_RPC=https://evm.ynxweb4.com
export YUSD_TEST=0xAC4Bb6f5F98aA9175B939CD867508270B0d56172
export ACCOUNT=0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5

node - <<'NODE'
const { JsonRpcProvider, Contract, formatUnits } = require("ethers");
const provider = new JsonRpcProvider(process.env.YNX_RPC);
const token = new Contract(process.env.YUSD_TEST, [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)"
], provider);
(async () => {
  const [name, symbol, decimals, totalSupply, balance] = await Promise.all([
    token.name(),
    token.symbol(),
    token.decimals(),
    token.totalSupply(),
    token.balanceOf(process.env.ACCOUNT),
  ]);
  console.log({
    name,
    symbol,
    decimals: Number(decimals),
    totalSupply: formatUnits(totalSupply, decimals),
    balance: formatUnits(balance, decimals),
  });
})();
NODE
```
