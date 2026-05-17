import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";
import { keccak256, toUtf8Bytes } from "ethers";

const { ethers } = await network.connect();

type AssetManifestEntry = {
  sourceChainId: string;
  sourceAssetCanonical: string;
  sourceAssetId?: string;
  sourceAddress?: string;
  name: string;
  symbol: string;
  decimals: number;
};

type AssetManifest = {
  source?: string;
  generatedAt?: string;
  assets: AssetManifestEntry[];
};

function parseAddresses(input: string | undefined): string[] {
  if (!input) return [];
  return input
    .split(",")
    .map((v) => v.trim())
    .filter(Boolean);
}

function parseNumberEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = Number(raw);
  return Number.isFinite(value) ? value : fallback;
}

function sourceAssetId(entry: AssetManifestEntry): string {
  if (entry.sourceAssetId && entry.sourceAssetId.startsWith("0x")) {
    return entry.sourceAssetId;
  }
  return keccak256(toUtf8Bytes(entry.sourceAssetCanonical));
}

function cleanSymbol(symbol: string): string {
  const cleaned = symbol.trim().replace(/[^a-zA-Z0-9._-]/g, "");
  return cleaned.length > 0 ? cleaned.slice(0, 20) : "ASSET";
}

function wrappedName(name: string): string {
  const n = name.trim();
  return n.length === 0 ? "Wrapped Asset on YNX" : `Wrapped ${n} on YNX`;
}

function wrappedSymbol(symbol: string): string {
  const base = cleanSymbol(symbol).toUpperCase();
  const candidate = `w${base}.y`;
  return candidate.length <= 20 ? candidate : `w${base.slice(0, 16)}`.slice(0, 20);
}

async function main() {
  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error(
      "No deployer signer available. Set YNX_EVM_PRIVATE_KEY, EVM_PRIVATE_KEY, or PRIVATE_KEY before running on ynxpublic.",
    );
  }

  const networkChainId = Number((await ethers.provider.getNetwork()).chainId);
  const manifestPath =
    process.env.BRIDGE_ASSET_MANIFEST_PATH ??
    path.join(process.cwd(), "config", "mainstream-assets-manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as AssetManifest;
  if (!manifest.assets || manifest.assets.length === 0) {
    throw new Error(`No assets found in manifest: ${manifestPath}`);
  }

  const configuredSigners = parseAddresses(process.env.BRIDGE_SIGNERS);
  const signerList = configuredSigners.length > 0 ? configuredSigners : [deployer.address];
  const threshold = parseNumberEnv("BRIDGE_THRESHOLD", configuredSigners.length > 0 ? 2 : 1);
  const signerDelaySeconds = parseNumberEnv("BRIDGE_SIGNER_DELAY_SEC", 3600);

  const Gateway = await ethers.getContractFactory("YNXBridgeGateway", deployer);
  const existingGateway = process.env.BRIDGE_GATEWAY_ADDRESS?.trim();
  let gateway;
  let gatewayAddress = "";
  let gatewayAction: "deployed" | "attached" = "deployed";

  if (existingGateway && existingGateway.startsWith("0x")) {
    const code = await ethers.provider.getCode(existingGateway);
    if (code === "0x") throw new Error(`BRIDGE_GATEWAY_ADDRESS has no code: ${existingGateway}`);
    gateway = Gateway.attach(existingGateway);
    gatewayAddress = existingGateway;
    gatewayAction = "attached";
  } else {
    gateway = await Gateway.deploy(
      deployer.address,
      signerList,
      threshold,
      signerDelaySeconds,
    );
    await gateway.waitForDeployment();
    gatewayAddress = await gateway.getAddress();
  }

  const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken", deployer);
  const records = [];

  for (const entry of manifest.assets) {
    const remoteChainId = BigInt(entry.sourceChainId);
    const remoteAssetId = sourceAssetId(entry);
    const existing = await gateway.wrappedTokenByRemoteAsset(remoteChainId, remoteAssetId);
    if (existing !== ethers.ZeroAddress) {
      records.push({
        sourceChainId: entry.sourceChainId,
        sourceAssetCanonical: entry.sourceAssetCanonical,
        sourceAssetId: remoteAssetId,
        wrappedToken: existing,
        action: "skipped_existing",
        name: wrappedName(entry.name),
        symbol: wrappedSymbol(entry.symbol),
        decimals: entry.decimals,
      });
      continue;
    }

    const wrapped = await Wrapped.deploy(
      wrappedName(entry.name),
      wrappedSymbol(entry.symbol),
      entry.decimals,
      deployer.address,
      gatewayAddress,
    );
    await wrapped.waitForDeployment();
    const wrappedAddress = await wrapped.getAddress();

    await (await gateway.setSupportedWrappedToken(wrappedAddress, true)).wait();
    await (await gateway.setBridgeRoute(remoteChainId, remoteAssetId, wrappedAddress)).wait();

    records.push({
      sourceChainId: entry.sourceChainId,
      sourceAssetCanonical: entry.sourceAssetCanonical,
      sourceAssetId: remoteAssetId,
      wrappedToken: wrappedAddress,
      action: "deployed",
      name: wrappedName(entry.name),
      symbol: wrappedSymbol(entry.symbol),
      decimals: entry.decimals,
    });
  }

  const summary = {
    network: "YNX Web4 Public Testnet",
    chainId: networkChainId,
    gatewayAction,
    contracts: {
      gateway: gatewayAddress,
    },
    bridgeConfig: {
      signers: signerList,
      threshold,
      signerDelaySeconds,
    },
    source: manifest.source ?? "unknown",
    generatedAt: new Date().toISOString(),
    result: {
      processed: records.length,
      deployed: records.filter((r) => r.action === "deployed").length,
      skippedExisting: records.filter((r) => r.action === "skipped_existing").length,
    },
    records,
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `public-mainstream-bridge-${networkChainId}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");
  console.log(`Mainstream bridge routes ready. Wrote ${outPath}`);
  console.log(JSON.stringify(summary.result, null, 2));
}

await main();
