# YNX 测试网交易手册

状态：公开测试网交易 pilot  
最后更新：2026-05-31  
范围：YNX 公开测试网 `ynx_9102-1`

## 摘要

YNX 公开测试网现在有一个最小链上 AMM pilot，用于测试 wrapped 资产和
`YUSD.test` 之间的 swap。

这不是生产级 DEX，不是交易所服务，也不是投资场所。它是用于测试流动性、
报价、索引、钱包 UX 和 AI 支付流程的公开测试网合约组。

## 资产

| 资产 | 合约 | Decimals |
|---|---|---:|
| `YUSD.test` | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172` | 6 |
| `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 |
| `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 |

## AMM 交易池

| 交易池 | 合约 | 初始流动性 |
|---|---|---|
| `wUSDC.y / YUSD.test` | `0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E` | `0.5 wUSDC.y` + `0.5 YUSD.test` |
| `wETH.y / YUSD.test` | `0x84868c7554efB510964a7b54E4afcAE11275475c` | `0.0005 wETH.y` + `2 YUSD.test` |

实测 swap：

```text
YUSD.test -> wUSDC.y: 0x97662fd10fac494102180a5dbc2f26214a95aa003bf1be490d8edb0506243001
```

## Swap 命令

```bash
cd /Users/huangjiahao/Desktop/YNX
set +x

export SSH_KEY=/Users/huangjiahao/Downloads/Huang.pem
export YNX_RPC=https://evm.ynxweb4.com
export YUSD_TEST=0xAC4Bb6f5F98aA9175B939CD867508270B0d56172
export WUSDC_Y=0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c
export WUSDC_YUSD_PAIR=0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E
export SWAP_AMOUNT_YUSD=0.1

export YNX_EVM_PRIVATE_KEY="$(ssh -i "$SSH_KEY" -o ConnectTimeout=10 ubuntu@43.153.202.237 "sudo awk -F= '/^AI_ONCHAIN_PRIVATE_KEY=/{print \\$2}' /etc/ynx-v2/env")"

node <<'NODE'
const { Wallet, JsonRpcProvider, Contract, parseUnits, formatUnits } = require("ethers");
(async () => {
  const provider = new JsonRpcProvider(process.env.YNX_RPC);
  const wallet = new Wallet(process.env.YNX_EVM_PRIVATE_KEY, provider);
  const amount = parseUnits(process.env.SWAP_AMOUNT_YUSD, 6);
  const token = new Contract(process.env.YUSD_TEST, ["function approve(address,uint256) returns (bool)"], wallet);
  const pair = new Contract(process.env.WUSDC_YUSD_PAIR, [
    "function quote(address,uint256) view returns (uint256)",
    "function swap(address,uint256,uint256,address) returns (uint256)"
  ], wallet);
  const quoted = await pair.quote(process.env.YUSD_TEST, amount);
  console.log("quoted wUSDC.y out:", formatUnits(quoted, 6));
  await (await token.approve(process.env.WUSDC_YUSD_PAIR, amount)).wait(1);
  const tx = await pair.swap(process.env.YUSD_TEST, amount, 1n, wallet.address);
  console.log("swap tx:", tx.hash);
  await tx.wait(1);
})();
NODE
```

## 风险边界

- 测试网流动性刻意很小；
- 价格不是市场价格；
- `YUSD.test` 不可赎回；
- AMM 是测试用 pilot 合约；
- 主网交易需要单独完成审计、风险限额、监控、法律审查、用户披露和流动性治理。
