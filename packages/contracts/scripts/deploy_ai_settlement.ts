import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error(
      "No deployer signer available. Set YNX_EVM_PRIVATE_KEY, EVM_PRIVATE_KEY, or PRIVATE_KEY before running on ynxpublic.",
    );
  }

  const chainId = Number((await ethers.provider.getNetwork()).chainId);
  const Settlement = await ethers.getContractFactory("YNXAISettlement", deployer);
  const settlement = await Settlement.deploy();
  await settlement.waitForDeployment();

  const summary = {
    network: chainId === 9102 ? "YNX Web4 Public Testnet" : "local/simulated",
    chainId,
    generatedAt: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      aiSettlement: await settlement.getAddress(),
    },
    purpose: "On-chain AI job/vault/result settlement rail for policy-bounded Web4 agents.",
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `public-ai-settlement-${chainId}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
  console.log(`AI settlement deployed. Wrote ${outPath}`);
  console.log(JSON.stringify(summary.contracts, null, 2));
}

await main();
