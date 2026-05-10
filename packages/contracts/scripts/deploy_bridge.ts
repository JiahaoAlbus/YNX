import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

function parseAddresses(input: string | undefined): string[] {
  if (!input) return [];
  return input
    .split(",")
    .map((v) => v.trim())
    .filter((v) => v.length > 0);
}

function parseBigIntEnv(name: string, fallback: bigint): bigint {
  const raw = process.env[name];
  if (!raw) return fallback;
  return BigInt(raw);
}

function parseNumberEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  return Number(raw);
}

async function main() {
  const [deployer, s1, s2, s3] = await ethers.getSigners();
  const chainId = Number((await ethers.provider.getNetwork()).chainId);

  const configuredSigners = parseAddresses(process.env.BRIDGE_SIGNERS);
  const signerList =
    configuredSigners.length > 0
      ? configuredSigners
      : [s1.address, s2.address, s3.address];

  const threshold = parseNumberEnv("BRIDGE_THRESHOLD", 2);
  const signerDelaySeconds = parseNumberEnv("BRIDGE_SIGNER_DELAY_SEC", 3600);

  const wrappedName = process.env.BRIDGE_WRAP_NAME ?? "Wrapped USDT on YNX";
  const wrappedSymbol = process.env.BRIDGE_WRAP_SYMBOL ?? "wUSDT.y";

  const remoteChainId = parseBigIntEnv("BRIDGE_REMOTE_CHAIN_ID", 728126428n);
  const remoteAssetCanonical =
    process.env.BRIDGE_REMOTE_ASSET_CANONICAL ??
    "tron:usdt:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t";
  const remoteAssetId = ethers.keccak256(ethers.toUtf8Bytes(remoteAssetCanonical));

  const Gateway = await ethers.getContractFactory("YNXBridgeGateway", deployer);
  const gateway = await Gateway.deploy(
    deployer.address,
    signerList,
    threshold,
    signerDelaySeconds,
  );
  await gateway.waitForDeployment();

  const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken", deployer);
  const wrapped = await Wrapped.deploy(
    wrappedName,
    wrappedSymbol,
    deployer.address,
    await gateway.getAddress(),
  );
  await wrapped.waitForDeployment();

  await (
    await gateway.setSupportedWrappedToken(await wrapped.getAddress(), true)
  ).wait();
  await (
    await gateway.setBridgeRoute(
      remoteChainId,
      remoteAssetId,
      await wrapped.getAddress(),
    )
  ).wait();

  const summary = {
    chainId,
    contracts: {
      gateway: await gateway.getAddress(),
      wrappedToken: await wrapped.getAddress(),
    },
    bridgeConfig: {
      signers: signerList,
      threshold,
      signerDelaySeconds,
      remoteChainId: remoteChainId.toString(),
      remoteAssetCanonical,
      remoteAssetId,
    },
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `bridge-${chainId}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(summary, null, 2)}\n`, "utf8");

  console.log(`Bridge contracts deployed. Wrote ${outPath}`);
  console.log(summary);
}

await main();
