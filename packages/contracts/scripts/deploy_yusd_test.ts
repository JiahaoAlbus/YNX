import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

function parseUnits6(value: string): bigint {
  return ethers.parseUnits(value, 6);
}

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error("No deployer signer available. Set YNX_EVM_PRIVATE_KEY, EVM_PRIVATE_KEY, or PRIVATE_KEY.");
  }

  const recipient = process.env.YUSD_INITIAL_RECIPIENT || deployer.address;
  const initialSupply = parseUnits6(process.env.YUSD_INITIAL_SUPPLY || "1000000");

  const Token = await ethers.getContractFactory("YUSDTestToken", deployer);
  const token = await Token.deploy(deployer.address, recipient, initialSupply);
  await token.waitForDeployment();

  const address = await token.getAddress();
  const network = await ethers.provider.getNetwork();
  const out = {
    network: network.name,
    chainId: network.chainId.toString(),
    token: address,
    name: await token.name(),
    symbol: await token.symbol(),
    decimals: Number(await token.decimals()),
    deployer: deployer.address,
    initialRecipient: recipient,
    initialSupply: initialSupply.toString(),
    generatedAt: new Date().toISOString(),
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `yusd-test-${network.chainId.toString()}.json`);
  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));

  console.log(`YUSD.test deployed. Wrote ${outPath}`);
  console.log(JSON.stringify(out, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
