# YNX Testnet Trading Manual

Status: public-testnet trading pilot  
Last updated: 2026-06-06  
Scope: YNX public testnet `ynx_9102-1`

## Summary

YNX public testnet now has a minimal on-chain AMM pilot for testing swaps
between bridged assets and `YUSD.test`.

This is not a production DEX, not an exchange service, and not an investment
venue. It is a public-testnet contract set for testing liquidity, pricing,
indexing, wallet UX, and AI-payment flows.

## Assets

| Asset | Contract | Decimals |
|---|---|---:|
| `YUSD.test` | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172` | 6 |
| `wUSDC.y` | `0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c` | 6 |
| `wETH.y` | `0x5715Bb5a7B050234A225fC88FF74885eF55E9339` | 18 |

## AMM Pairs

| Pair | Contract | Initial liquidity |
|---|---|---|
| `wUSDC.y / YUSD.test` | `0x0DC3bF2f9AA273E16d4BEc38C967C0392a75286E` | `0.5 wUSDC.y` + `0.5 YUSD.test` |
| `wETH.y / YUSD.test` | `0x84868c7554efB510964a7b54E4afcAE11275475c` | `0.0005 wETH.y` + `2 YUSD.test` |

Smoke swap:

```text
YUSD.test -> wUSDC.y: 0x97662fd10fac494102180a5dbc2f26214a95aa003bf1be490d8edb0506243001
```

## Swap Command

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

## Risk Boundary

- Testnet liquidity is intentionally small.
- Prices are not market prices.
- `YUSD.test` is not redeemable.
- The AMM is a pilot contract for testing only.
- Mainnet trading needs separate audits, risk limits, monitoring, legal review,
  user disclosures, and liquidity governance.

## Live Website Flows

- Test assets: `https://www.ynxweb4.com/test-assets`
- Deposit bridge: `https://www.ynxweb4.com/bridge`
- Withdraw bridge: `https://www.ynxweb4.com/withdraw`
- Swap: `https://www.ynxweb4.com/trading`
- Readiness gates: `https://www.ynxweb4.com/readiness`

The public testnet now has a complete Sepolia rehearsal loop:

```text
Sepolia ETH/USDC deposit -> YNX wETH.y/wUSDC.y mint
YNX wrapped asset swap -> YNX wrapped asset burn
YNX burn watcher -> Sepolia lockbox release
```

The public testnet also has a manual proof loop for BTC testnet BTC, BSC
testnet BNB, and TRON Shasta USDT:

```text
external testnet deposit verified by operator
-> /bridge/deposits/prove
-> YNX wrapped asset mint
-> YNX wrapped asset burn
-> YNX burn watcher queues withdrawal
-> external release proof recorded with /bridge/withdrawals/:id/mark-released
```

Manual proof routes are valid for public-testnet engineering and audit-trail
testing. They are not yet production automatic bridge routes.

Smoke withdrawal evidence:

```text
YNX wUSDC.y burn tx:      0x03113a31aeb2c2dc17c218e308168ce370d3ba82c26db69878987c5b2f97cb22
Sepolia USDC release tx:  0xccfde97839036479ca55265a07a2d3770982797bead02864cb72f06591105893
YNX wETH.y burn tx:       0x1475b1d8f963462e386fad8f33a19ba2db35f16ca9970a6f2c3ed8c37fd145d6
Sepolia ETH release tx:   0x35eec0e6feda8a710f9083a237e8a582bd67eb87bce1e0c3ded378fa6331293a
```

Operator full-loop probe:

```bash
scripts/public_bridge_full_loop_probe.sh
```
