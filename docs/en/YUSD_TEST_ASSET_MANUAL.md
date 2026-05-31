# YUSD.test Asset Manual

Status: public-testnet synthetic asset  
Last updated: 2026-05-31  
Scope: YNX public testnet `ynx_9102-1`

## Summary

`YUSD.test` is a synthetic test dollar asset on the YNX public testnet.
It is designed for testing trading pairs, bridge UX, AI payments, settlement
demos, accounting screens, and developer integrations.

`YUSD.test` is not a regulated stablecoin and is not redeemable for USD,
USDC, USDT, fiat money, bank deposits, or any other asset.

## Public Testnet Contract

| Field | Value |
|---|---|
| Name | `YUSD Test Dollar` |
| Symbol | `YUSD.test` |
| Network | YNX public testnet |
| EVM chain id | `9102` |
| Contract | `0xAC4Bb6f5F98aA9175B939CD867508270B0d56172` |
| Decimals | `6` |
| Initial test supply | `1,000,000 YUSD.test` |
| Initial recipient | `0xDAab5F0C6A2d89F7b669ac56025c92D8c0cC69c5` |

## Intended Uses

- quote asset for YNX testnet trading pairs;
- test stable-value UI flows without using real money;
- test AI-agent payment and settlement accounting;
- test DEX liquidity, swaps, fees, and indexing;
- internal QA, demos, tutorials, and hackathon flows.

## Prohibited Claims

Do not describe `YUSD.test` as:

- real USD;
- USDC, USDT, or a partner-issued token;
- redeemable, collateralized, backed, insured, or audited;
- legal tender, e-money, stored value, or a bank deposit;
- suitable for investment, saving, payroll, remittance, or production commerce.

The canonical user-facing phrase is:

```text
YUSD.test is a synthetic public-testnet asset for testing only. It has no
mainnet value and is not redeemable for fiat or stablecoins.
```

## Risk Controls

The deployed contract includes:

- `MINTER_ROLE` for controlled testnet minting;
- `PAUSER_ROLE` for emergency transfer pause;
- burn support for cleaning up test balances;
- 6 decimals to match common stablecoin UX.

Before any mainnet stable asset launch, YNX must complete a separate legal,
reserve, custody, audit, redemption, and issuer-governance review. Mainnet
stablecoin issuance should be handled by a regulated issuer or qualified
partner unless counsel approves another model.

## Basic Commands

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
