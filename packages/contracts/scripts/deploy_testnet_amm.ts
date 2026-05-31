import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

const ERC20_ABI = [
  "function approve(address spender,uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)",
];

async function approve(tokenAddress: string, spender: string, amount: bigint) {
  const token = await ethers.getContractAt(ERC20_ABI, tokenAddress);
  const tx = await token.approve(spender, amount);
  await tx.wait();
}

async function deployPair(
  label: string,
  tokenA: string,
  tokenB: string,
  amountA: bigint,
  amountB: bigint,
  deployerAddress: string,
) {
  const Pair = await ethers.getContractFactory("YNXSimpleAMMPair");
  const pair = await Pair.deploy(tokenA, tokenB, `YNX LP ${label}`, `ynxLP-${label}`);
  await pair.waitForDeployment();
  const pairAddress = await pair.getAddress();
  const token0 = await pair.token0();
  const token1 = await pair.token1();
  const amount0 = tokenA.toLowerCase() === token0.toLowerCase() ? amountA : amountB;
  const amount1 = tokenA.toLowerCase() === token0.toLowerCase() ? amountB : amountA;

  await approve(token0, pairAddress, amount0);
  await approve(token1, pairAddress, amount1);
  await (await pair.addLiquidity(amount0, amount1, deployerAddress)).wait();

  const token0Contract = await ethers.getContractAt(ERC20_ABI, token0);
  const token1Contract = await ethers.getContractAt(ERC20_ABI, token1);
  const [reserve0, reserve1] = await Promise.all([pair.reserve0(), pair.reserve1()]);
  return {
    label,
    pair: pairAddress,
    token0,
    token1,
    token0Symbol: await token0Contract.symbol(),
    token1Symbol: await token1Contract.symbol(),
    reserve0: reserve0.toString(),
    reserve1: reserve1.toString(),
  };
}

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) throw new Error("No deployer signer available.");

  const yusd = process.env.YUSD_TEST_ADDRESS || "0xAC4Bb6f5F98aA9175B939CD867508270B0d56172";
  const wusdc = process.env.WUSDC_Y_ADDRESS || "0x847A90aF23667267DDf1028E68DC52C7AD2F8D6c";
  const weth = process.env.WETH_Y_ADDRESS || "0x5715Bb5a7B050234A225fC88FF74885eF55E9339";

  const networkInfo = await ethers.provider.getNetwork();
  const records = [];
  records.push(
    await deployPair("wUSDC-YUSD", wusdc, yusd, ethers.parseUnits("0.5", 6), ethers.parseUnits("0.5", 6), deployer.address),
  );
  records.push(
    await deployPair("wETH-YUSD", weth, yusd, ethers.parseUnits("0.0005", 18), ethers.parseUnits("2", 6), deployer.address),
  );

  const out = {
    network: networkInfo.name,
    chainId: networkInfo.chainId.toString(),
    deployer: deployer.address,
    generatedAt: new Date().toISOString(),
    pairs: records,
  };
  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `testnet-amm-${networkInfo.chainId.toString()}.json`);
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log(`Testnet AMM deployed. Wrote ${outPath}`);
  console.log(JSON.stringify(out, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
