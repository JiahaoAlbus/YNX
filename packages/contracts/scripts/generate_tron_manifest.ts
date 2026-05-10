import fs from "node:fs";
import path from "node:path";
import { keccak256, toUtf8Bytes } from "ethers";

type TronToken = {
  name?: string;
  abbr?: string;
  contractAddress?: string;
  decimal?: number;
  nrOfTokenHolders?: number;
  marketCapUSD?: number;
  canShow?: number;
};

type TronOverviewResponse = {
  all?: number;
  tokens?: TronToken[];
};

type BridgeAssetManifestEntry = {
  sourceChainId: string;
  sourceAssetCanonical: string;
  sourceAssetId: string;
  sourceAddress: string;
  name: string;
  symbol: string;
  decimals: number;
  holders?: number;
  marketCapUsd?: number;
};

const TRON_MAINNET_CHAIN_ID = 728126428n;
const DEFAULT_PAGE_SIZE = 50;
const DEFAULT_MAX_ASSETS = 200;
const DEFAULT_MIN_HOLDERS = 100;

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return fallback;
  return parsed;
}

function envBigInt(name: string, fallback: bigint): bigint {
  const raw = process.env[name];
  if (!raw) return fallback;
  return BigInt(raw);
}

function buildCanonical(address: string): string {
  return `tron:trc20:${address}`;
}

function parseSymbol(symbol: string | undefined): string {
  const raw = (symbol ?? "TRON_ASSET").trim().toUpperCase();
  const clean = raw.replace(/[^A-Z0-9._-]/g, "");
  return clean.length > 0 ? clean : "TRON_ASSET";
}

function parseName(name: string | undefined): string {
  const raw = (name ?? "TRON Asset").trim();
  return raw.length > 0 ? raw : "TRON Asset";
}

async function fetchPage(start: number, limit: number): Promise<TronOverviewResponse> {
  const url = `https://apilist.tronscanapi.com/api/tokens/overview?start=${start}&limit=${limit}&filter=trc20`;
  const res = await fetch(url, {
    headers: {
      "accept": "application/json",
      "user-agent": "YNX-bridge-bootstrap/1.0",
    },
  });
  if (!res.ok) {
    throw new Error(`TronScan request failed (${res.status}) at start=${start}`);
  }
  const json = (await res.json()) as TronOverviewResponse;
  return json;
}

async function main() {
  const sourceChainId = envBigInt("BRIDGE_REMOTE_CHAIN_ID", TRON_MAINNET_CHAIN_ID);
  const pageSize = envInt("TRON_PAGE_SIZE", DEFAULT_PAGE_SIZE);
  const maxAssets = envInt("TRON_MAX_ASSETS", DEFAULT_MAX_ASSETS);
  const minHolders = envInt("TRON_MIN_HOLDERS", DEFAULT_MIN_HOLDERS);
  const maxPages = envInt("TRON_MAX_PAGES", 1000);
  const outPath =
    process.env.TRON_MANIFEST_OUT ??
    path.join(process.cwd(), "deployments", "tron-assets-manifest.json");

  if (pageSize <= 0) throw new Error("TRON_PAGE_SIZE must be > 0");
  if (maxAssets <= 0) throw new Error("TRON_MAX_ASSETS must be > 0");
  if (maxPages <= 0) throw new Error("TRON_MAX_PAGES must be > 0");

  const seen = new Set<string>();
  const assets: BridgeAssetManifestEntry[] = [];

  let start = 0;
  let page = 0;
  let total = 0;

  while (assets.length < maxAssets && page < maxPages) {
    const response = await fetchPage(start, pageSize);
    const tokens = response.tokens ?? [];
    if (tokens.length === 0) break;

    if (typeof response.all === "number" && response.all > 0) {
      total = response.all;
    }

    for (const token of tokens) {
      if (assets.length >= maxAssets) break;

      const address = token.contractAddress?.trim();
      if (!address) continue;
      if (seen.has(address.toLowerCase())) continue;
      if (token.canShow === 0) continue;

      const holders = token.nrOfTokenHolders ?? 0;
      if (holders < minHolders) continue;

      const decimals =
        typeof token.decimal === "number" && Number.isFinite(token.decimal)
          ? token.decimal
          : 18;
      if (decimals < 0 || decimals > 36) continue;

      const canonical = buildCanonical(address);
      const sourceAssetId = keccak256(toUtf8Bytes(canonical));

      assets.push({
        sourceChainId: sourceChainId.toString(),
        sourceAssetCanonical: canonical,
        sourceAssetId,
        sourceAddress: address,
        name: parseName(token.name),
        symbol: parseSymbol(token.abbr),
        decimals,
        holders,
        marketCapUsd: token.marketCapUSD,
      });

      seen.add(address.toLowerCase());
    }

    start += pageSize;
    page += 1;
  }

  const manifest = {
    source: "tronscan",
    generatedAt: new Date().toISOString(),
    requested: {
      sourceChainId: sourceChainId.toString(),
      pageSize,
      maxAssets,
      minHolders,
      maxPages,
    },
    observed: {
      totalAvailableFromSource: total,
      selectedAssets: assets.length,
    },
    assets,
  };

  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  console.log(`Wrote ${outPath}`);
  console.log(
    JSON.stringify(
      {
        totalAvailableFromSource: total,
        selectedAssets: assets.length,
      },
      null,
      2,
    ),
  );
}

await main();
