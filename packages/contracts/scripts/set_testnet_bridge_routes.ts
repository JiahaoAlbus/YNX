import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

type TestnetRoute = {
  routeId: string;
  sourceChainId: string;
  sourceAssetCanonical: string;
  sourceAssetId: string;
  wrappedToken: string;
};

type TestnetRouteManifest = {
  source?: string;
  generatedAt?: string;
  routes: TestnetRoute[];
};

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error(
      "No deployer signer available. Set YNX_EVM_PRIVATE_KEY, EVM_PRIVATE_KEY, or PRIVATE_KEY before running on ynxpublic.",
    );
  }

  const gatewayAddress = process.env.BRIDGE_GATEWAY_ADDRESS?.trim();
  if (!gatewayAddress || !gatewayAddress.startsWith("0x")) {
    throw new Error("BRIDGE_GATEWAY_ADDRESS is required");
  }

  const manifestPath =
    process.env.BRIDGE_TESTNET_ROUTES_PATH ??
    path.join(process.cwd(), "config", "testnet-assets-manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as TestnetRouteManifest;
  if (!manifest.routes || manifest.routes.length === 0) {
    throw new Error(`No routes found in manifest: ${manifestPath}`);
  }

  const Gateway = await ethers.getContractFactory("YNXBridgeGateway", deployer);
  const gateway = Gateway.attach(gatewayAddress);
  const records = [];

  for (const route of manifest.routes) {
    const sourceChainId = BigInt(route.sourceChainId);
    const existing = await gateway.wrappedTokenByRemoteAsset(sourceChainId, route.sourceAssetId);
    if (existing.toLowerCase() === route.wrappedToken.toLowerCase()) {
      records.push({ ...route, action: "skipped_existing" });
      continue;
    }
    if (existing !== ethers.ZeroAddress && existing.toLowerCase() !== route.wrappedToken.toLowerCase()) {
      throw new Error(
        `Route ${route.routeId} already maps to ${existing}, expected ${route.wrappedToken}`,
      );
    }
    await (await gateway.setBridgeRoute(sourceChainId, route.sourceAssetId, route.wrappedToken)).wait();
    records.push({ ...route, action: "route_set" });
  }

  const chainId = Number((await ethers.provider.getNetwork()).chainId);
  const summary = {
    network: "YNX Web4 Public Testnet",
    chainId,
    gateway: gatewayAddress,
    source: manifest.source || "unknown",
    generatedAt: new Date().toISOString(),
    result: {
      processed: records.length,
      routeSet: records.filter((item) => item.action === "route_set").length,
      skippedExisting: records.filter((item) => item.action === "skipped_existing").length,
    },
    records,
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `public-testnet-bridge-routes-${chainId}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
  console.log(`Testnet bridge routes ready. Wrote ${outPath}`);
  console.log(JSON.stringify(summary.result, null, 2));
}

await main();
