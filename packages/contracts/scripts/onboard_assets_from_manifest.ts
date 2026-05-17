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

type DeploymentRecord = {
  sourceChainId: string;
  sourceAssetCanonical: string;
  sourceAssetId: string;
  wrappedToken: string;
  action: "deployed" | "skipped_existing" | "planned";
  name: string;
  symbol: string;
};

function parseBoolean(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (!raw) return fallback;
  const v = raw.trim().toLowerCase();
  return v === "1" || v === "true" || v === "yes";
}

function parseIntEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const num = Number(raw);
  if (!Number.isFinite(num)) return fallback;
  return num;
}

function readGatewayFromFile(filePath: string): string | null {
  if (!fs.existsSync(filePath)) return null;
  const raw = fs.readFileSync(filePath, "utf8");
  const parsed = JSON.parse(raw) as { contracts?: { gateway?: string } };
  const gateway = parsed.contracts?.gateway?.trim();
  if (!gateway || !gateway.startsWith("0x")) return null;
  return gateway;
}

function resolveGatewayAddress(dryRun: boolean, networkChainId: number): string {
  const fromEnv = process.env.BRIDGE_GATEWAY_ADDRESS?.trim();
  if (fromEnv && fromEnv.startsWith("0x")) return fromEnv;

  if (dryRun) return ethers.ZeroAddress;

  const deploymentsDir = path.join(process.cwd(), "deployments");
  const preferred = path.join(deploymentsDir, `bridge-${networkChainId}.json`);
  const preferredGateway = readGatewayFromFile(preferred);
  if (preferredGateway) return preferredGateway;

  if (fs.existsSync(deploymentsDir)) {
    const files = fs
      .readdirSync(deploymentsDir)
      .filter((name) => /^bridge-\d+\.json$/.test(name))
      .map((name) => ({
        name,
        fullPath: path.join(deploymentsDir, name),
        mtimeMs: fs.statSync(path.join(deploymentsDir, name)).mtimeMs,
      }))
      .sort((a, b) => b.mtimeMs - a.mtimeMs);

    for (const file of files) {
      const gateway = readGatewayFromFile(file.fullPath);
      if (gateway) return gateway;
    }
  }

  throw new Error(
    `Gateway address not found. Run bridge deploy first or pass BRIDGE_GATEWAY_ADDRESS. Expected file: deployments/bridge-${networkChainId}.json`,
  );
}

function sourceAssetId(entry: AssetManifestEntry): string {
  if (entry.sourceAssetId && entry.sourceAssetId.startsWith("0x")) {
    return entry.sourceAssetId;
  }
  return keccak256(toUtf8Bytes(entry.sourceAssetCanonical));
}

function cleanSymbol(symbol: string): string {
  const s = symbol.trim().replace(/[^a-zA-Z0-9._-]/g, "");
  if (s.length === 0) return "ASSET";
  return s.slice(0, 20);
}

function wrappedName(name: string): string {
  const n = name.trim();
  return n.length === 0 ? "Wrapped Asset on YNX" : `Wrapped ${n} on YNX`;
}

function wrappedSymbol(symbol: string): string {
  const base = cleanSymbol(symbol).toUpperCase();
  const candidate = `w${base}.y`;
  if (candidate.length <= 20) return candidate;
  return `w${base.slice(0, 16)}`.slice(0, 20);
}

async function main() {
  const networkChainId = Number((await ethers.provider.getNetwork()).chainId);
  const manifestPath =
    process.env.BRIDGE_ASSET_MANIFEST_PATH ??
    path.join(process.cwd(), "deployments", "tron-assets-manifest.json");
  const maxAssets = parseIntEnv("BRIDGE_MAX_ONBOARD", 200);
  const dryRun = parseBoolean("BRIDGE_DRY_RUN", false);
  const gatewayAddress = resolveGatewayAddress(dryRun, networkChainId);

  const raw = fs.readFileSync(manifestPath, "utf8");
  const manifest = JSON.parse(raw) as AssetManifest;
  if (!manifest.assets || manifest.assets.length === 0) {
    throw new Error(`No assets found in manifest: ${manifestPath}`);
  }

  const Gateway = await ethers.getContractFactory("YNXBridgeGateway");
  const hasGateway = gatewayAddress !== ethers.ZeroAddress;
  const gateway = hasGateway ? Gateway.attach(gatewayAddress) : null;
  if (gateway) {
    const code = await ethers.provider.getCode(gatewayAddress);
    if (code === "0x") {
      throw new Error(
        `Gateway ${gatewayAddress} has no code on current network. Start the right node or redeploy bridge for this network.`,
      );
    }
  }
  const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken");
  const [deployer] = await ethers.getSigners();

  const selected = manifest.assets.slice(0, maxAssets);
  const records: DeploymentRecord[] = [];

  for (const entry of selected) {
    const chainId = BigInt(entry.sourceChainId);
    const remoteAssetId = sourceAssetId(entry);

    if (gateway) {
      const existing = await gateway.wrappedTokenByRemoteAsset(chainId, remoteAssetId);
      if (existing !== ethers.ZeroAddress) {
        records.push({
          sourceChainId: entry.sourceChainId,
          sourceAssetCanonical: entry.sourceAssetCanonical,
          sourceAssetId: remoteAssetId,
          wrappedToken: existing,
          action: "skipped_existing",
          name: wrappedName(entry.name),
          symbol: wrappedSymbol(entry.symbol),
        });
        continue;
      }
    }

    const name = wrappedName(entry.name);
    const symbol = wrappedSymbol(entry.symbol);

    if (dryRun) {
      records.push({
        sourceChainId: entry.sourceChainId,
        sourceAssetCanonical: entry.sourceAssetCanonical,
        sourceAssetId: remoteAssetId,
        wrappedToken: ethers.ZeroAddress,
        action: "planned",
        name,
        symbol,
      });
      continue;
    }

    const wrapped = await Wrapped.deploy(
      name,
      symbol,
      entry.decimals,
      deployer.address,
      gatewayAddress,
    );
    await wrapped.waitForDeployment();
    const wrappedAddress = await wrapped.getAddress();

    if (!gateway) {
      throw new Error("Gateway is required when BRIDGE_DRY_RUN=false");
    }
    await (await gateway.setSupportedWrappedToken(wrappedAddress, true)).wait();
    await (await gateway.setBridgeRoute(chainId, remoteAssetId, wrappedAddress)).wait();

    records.push({
      sourceChainId: entry.sourceChainId,
      sourceAssetCanonical: entry.sourceAssetCanonical,
      sourceAssetId: remoteAssetId,
      wrappedToken: wrappedAddress,
      action: "deployed",
      name,
      symbol,
    });
  }

  const out = {
    source: manifest.source ?? "unknown",
    generatedAt: new Date().toISOString(),
    gatewayAddress,
    dryRun,
    requested: {
      networkChainId,
      manifestPath,
      maxAssets,
    },
    result: {
      totalInManifest: manifest.assets.length,
      processed: selected.length,
      deployed: records.filter((r) => r.action === "deployed").length,
      skippedExisting: records.filter((r) => r.action === "skipped_existing").length,
      planned: records.filter((r) => r.action === "planned").length,
    },
    records,
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `bridge-onboard-${Date.now()}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
  console.log(`Wrote ${outPath}`);
  console.log(JSON.stringify(out.result, null, 2));
}

await main();
