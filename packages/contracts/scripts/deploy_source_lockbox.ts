import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

type LockboxRoute = {
  network: string;
  sourceChainId: string;
  routeId: string;
  sourceAssetId: string;
  nativeAsset: boolean;
  token: string;
  minAmount: string;
};

type LockboxManifest = {
  source?: string;
  routes: LockboxRoute[];
};

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error("No deployer signer available. Set YNX_EVM_PRIVATE_KEY, EVM_PRIVATE_KEY, or PRIVATE_KEY.");
  }

  const manifestPath =
    process.env.SOURCE_LOCKBOX_MANIFEST_PATH ??
    path.join(process.cwd(), "config", "source-lockbox-testnet.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as LockboxManifest;
  const net = await ethers.provider.getNetwork();
  const networkName = network.name;
  const routes = (manifest.routes || []).filter(
    (route) => route.network === networkName || BigInt(route.sourceChainId) === net.chainId,
  );
  if (routes.length === 0) {
    throw new Error(`No source lockbox routes for network=${networkName}, chainId=${net.chainId}`);
  }

  const Lockbox = await ethers.getContractFactory("YNXSourceLockbox", deployer);
  const existing = process.env.SOURCE_LOCKBOX_ADDRESS?.trim();
  const lockbox = existing
    ? Lockbox.attach(existing)
    : await Lockbox.deploy(deployer.address, BigInt(routes[0].sourceChainId));

  const lockboxAddress = await lockbox.getAddress();
  if (!existing) await lockbox.waitForDeployment();

  const records = [];
  for (const route of routes) {
    const tx = await lockbox.setRoute(
      route.sourceAssetId,
      true,
      route.nativeAsset,
      route.token,
      BigInt(route.minAmount),
    );
    const receipt = await tx.wait();
    records.push({
      ...route,
      lockbox: lockboxAddress,
      txHash: tx.hash,
      blockNumber: receipt?.blockNumber ?? null,
      action: "route_set",
    });
  }

  const summary = {
    source: manifest.source || "unknown",
    network: networkName,
    chainId: Number(net.chainId),
    lockbox: lockboxAddress,
    owner: deployer.address,
    generatedAt: new Date().toISOString(),
    records,
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `source-lockbox-${Number(net.chainId)}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
  console.log(`Source lockbox ready. Wrote ${outPath}`);
  console.log(JSON.stringify({ lockbox: lockboxAddress, routes: records.length }, null, 2));
}

await main();
