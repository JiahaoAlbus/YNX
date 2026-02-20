const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const readline = require("readline");

function loadEnvFile(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, "utf8");
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const idx = line.indexOf("=");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let value = line.slice(idx + 1).trim();
    if ((value.startsWith("\"") && value.endsWith("\"")) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

const envCandidates = [];
if (process.env.INDEXER_ENV_FILE) envCandidates.push(process.env.INDEXER_ENV_FILE);
if (process.env.YNX_ENV_FILE) envCandidates.push(process.env.YNX_ENV_FILE);
envCandidates.push(path.resolve(__dirname, ".env"));
envCandidates.push(path.resolve(__dirname, "../../.env"));
for (const candidate of envCandidates) {
  loadEnvFile(candidate);
}

function envNumber(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = parseInt(raw, 10);
  return Number.isFinite(value) ? value : fallback;
}

const INDEXER_RPC = process.env.INDEXER_RPC || "http://127.0.0.1:26657";
const INDEXER_PORT = envNumber("INDEXER_PORT", 8081);
const INDEXER_POLL_MS = envNumber("INDEXER_POLL_MS", 1000);
const INDEXER_CACHE_SIZE = envNumber("INDEXER_CACHE_SIZE", 500);
const INDEXER_TX_CACHE_SIZE = envNumber("INDEXER_TX_CACHE_SIZE", 2000);
const INDEXER_BACKFILL = envNumber("INDEXER_BACKFILL", 0);
const INDEXER_START_HEIGHT = envNumber("INDEXER_START_HEIGHT", 0);
const DATA_DIR = process.env.INDEXER_DATA_DIR || path.resolve(__dirname, "data");
const STATE_PATH = path.join(DATA_DIR, "state.json");
const BLOCKS_PATH = path.join(DATA_DIR, "blocks.jsonl");
const TXS_PATH = path.join(DATA_DIR, "txs.jsonl");
const YNX_FOUNDER_ADDRESS = process.env.YNX_FOUNDER_ADDRESS || "";
const YNX_TREASURY_ADDRESS = process.env.YNX_TREASURY_ADDRESS || "";
const YNX_TEAM_BENEFICIARY = process.env.YNX_TEAM_BENEFICIARY || "";
const YNX_COMMUNITY_RECIPIENT = process.env.YNX_COMMUNITY_RECIPIENT || "";
const YNX_FEE_BURN_BPS = envNumber("YNX_FEE_BURN_BPS", 4000);
const YNX_FEE_TREASURY_BPS = envNumber("YNX_FEE_TREASURY_BPS", 1000);
const YNX_FEE_FOUNDER_BPS = envNumber("YNX_FEE_FOUNDER_BPS", 1000);
const YNX_INFLATION_TREASURY_BPS = envNumber("YNX_INFLATION_TREASURY_BPS", 3000);
const YNX_NO_BASE_FEE = process.env.YNX_NO_BASE_FEE;

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

let state = { last_height: 0, blocks_indexed: 0, txs_indexed: 0 };
if (fs.existsSync(STATE_PATH)) {
  try {
    state = JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
  } catch {
    state = { last_height: 0, blocks_indexed: 0, txs_indexed: 0 };
  }
}

function saveState() {
  fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
}

function log(message) {
  const stamp = new Date().toISOString();
  console.log(`[${stamp}] ${message}`);
}

function rpcRequest(pathname) {
  const url = new URL(pathname, INDEXER_RPC);
  const lib = url.protocol === "https:" ? https : http;
  return new Promise((resolve, reject) => {
    const req = lib.request(url, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk.toString();
      });
      res.on("end", () => {
        try {
          const json = JSON.parse(data);
          resolve(json);
        } catch (err) {
          reject(new Error(`RPC JSON parse failed: ${err.message}`));
        }
      });
    });
    req.on("error", reject);
    req.end();
  });
}

function appendJsonLine(filePath, payload) {
  fs.appendFileSync(filePath, `${JSON.stringify(payload)}\n`);
}

function txHashFromBase64(base64) {
  const bytes = Buffer.from(base64, "base64");
  const hash = crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
  return `0x${hash}`;
}

const blocksCache = [];
const txsCache = [];
let latestSeenHeight = 0;
let indexing = false;
let chainId = "";
let governanceMeta = {
  founder_address: YNX_FOUNDER_ADDRESS,
  treasury_address: YNX_TREASURY_ADDRESS,
  team_beneficiary_address: YNX_TEAM_BENEFICIARY,
  community_recipient_address: YNX_COMMUNITY_RECIPIENT,
  fee_burn_bps: YNX_FEE_BURN_BPS,
  fee_treasury_bps: YNX_FEE_TREASURY_BPS,
  fee_founder_bps: YNX_FEE_FOUNDER_BPS,
  inflation_treasury_bps: YNX_INFLATION_TREASURY_BPS,
  no_base_fee: YNX_NO_BASE_FEE === undefined ? null : YNX_NO_BASE_FEE === "1" || YNX_NO_BASE_FEE === "true",
  base_fee: "",
};

async function initChainId() {
  try {
    const status = await rpcRequest("/status");
    chainId = status?.result?.node_info?.network || "";
  } catch {
    chainId = "";
  }
}

async function initGovernanceMeta() {
  try {
    const genesis = await rpcRequest("/genesis");
    const appState = genesis?.result?.genesis?.app_state || {};
    const ynx = appState?.ynx || {};
    const params = ynx?.params || {};
    const system = ynx?.system || {};
    const feemarket = appState?.feemarket?.params || {};

    governanceMeta = {
      founder_address: params.founder_address || governanceMeta.founder_address,
      treasury_address: params.treasury_address || governanceMeta.treasury_address,
      team_beneficiary_address: system.team_beneficiary_address || governanceMeta.team_beneficiary_address,
      community_recipient_address: system.community_recipient_address || governanceMeta.community_recipient_address,
      fee_burn_bps: Number(params.fee_burn_bps ?? governanceMeta.fee_burn_bps),
      fee_treasury_bps: Number(params.fee_treasury_bps ?? governanceMeta.fee_treasury_bps),
      fee_founder_bps: Number(params.fee_founder_bps ?? governanceMeta.fee_founder_bps),
      inflation_treasury_bps: Number(params.inflation_treasury_bps ?? governanceMeta.inflation_treasury_bps),
      no_base_fee: feemarket.no_base_fee ?? governanceMeta.no_base_fee,
      base_fee: feemarket.base_fee || governanceMeta.base_fee,
    };
  } catch {
    return;
  }
}

async function indexHeight(height) {
  const blockData = await rpcRequest(`/block?height=${height}`);
  const resultData = await rpcRequest(`/block_results?height=${height}`);

  const block = blockData?.result?.block;
  if (!block) {
    throw new Error(`Missing block for height ${height}`);
  }

  const header = block.header || {};
  const blockId = blockData?.result?.block_id || {};
  const txs = block.data?.txs || [];
  const txResults = resultData?.result?.txs_results || [];

  const record = {
    height: parseInt(header.height || height, 10),
    hash: blockId.hash || "",
    time: header.time || "",
    proposer: header.proposer_address || "",
    num_txs: txs.length,
    app_hash: header.app_hash || "",
  };

  appendJsonLine(BLOCKS_PATH, record);
  blocksCache.push(record);
  if (blocksCache.length > INDEXER_CACHE_SIZE) {
    blocksCache.shift();
  }

  const txRecords = [];
  for (let i = 0; i < txs.length; i += 1) {
    const base64 = txs[i];
    const hash = txHashFromBase64(base64);
    const result = txResults[i] || {};
    const txRecord = {
      hash,
      height: record.height,
      index: i,
      code: result.code || 0,
      gas_wanted: result.gas_wanted || 0,
      gas_used: result.gas_used || 0,
    };
    txRecords.push(txRecord);
    appendJsonLine(TXS_PATH, txRecord);
  }

  for (const txRecord of txRecords) {
    txsCache.push(txRecord);
    if (txsCache.length > INDEXER_TX_CACHE_SIZE) {
      txsCache.shift();
    }
  }

  state.last_height = record.height;
  state.blocks_indexed += 1;
  state.txs_indexed += txRecords.length;
  saveState();
}

async function poll() {
  if (indexing) return;
  indexing = true;

  try {
    const status = await rpcRequest("/status");
    if (!chainId) {
      chainId = status?.result?.node_info?.network || chainId;
    }
    const latest = parseInt(status?.result?.sync_info?.latest_block_height || "0", 10);
    if (latest > latestSeenHeight) {
      latestSeenHeight = latest;
    }

    if (!governanceMeta.founder_address && latest > 0) {
      await initGovernanceMeta();
    }

    if (!state.last_height || state.last_height === 0) {
      if (INDEXER_START_HEIGHT > 0) {
        state.last_height = INDEXER_START_HEIGHT - 1;
      } else if (INDEXER_BACKFILL > 0) {
        state.last_height = Math.max(0, latest - INDEXER_BACKFILL);
      } else {
        state.last_height = latest;
      }
      saveState();
    }

    for (let h = state.last_height + 1; h <= latest; h += 1) {
      await indexHeight(h);
    }
  } catch (err) {
    log(`Indexing error: ${err.message}`);
  } finally {
    indexing = false;
  }
}

function json(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,OPTIONS",
  });
  res.end(body);
}

async function findBlockByHeight(height) {
  const cached = blocksCache.find((b) => b.height === height);
  if (cached) return cached;
  if (!fs.existsSync(BLOCKS_PATH)) return null;

  return new Promise((resolve) => {
    const stream = fs.createReadStream(BLOCKS_PATH, "utf8");
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    let found = null;
    rl.on("line", (line) => {
      if (!line) return;
      try {
        const entry = JSON.parse(line);
        if (entry.height === height) {
          found = entry;
          rl.close();
        }
      } catch {
        return;
      }
    });
    rl.on("close", () => {
      stream.close();
      resolve(found);
    });
  });
}

async function findTxByHash(hash) {
  const upper = hash.toUpperCase();
  const cached = txsCache.find((t) => t.hash.toUpperCase() === upper);
  if (cached) return cached;
  if (!fs.existsSync(TXS_PATH)) return null;

  return new Promise((resolve) => {
    const stream = fs.createReadStream(TXS_PATH, "utf8");
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    let found = null;
    rl.on("line", (line) => {
      if (!line) return;
      try {
        const entry = JSON.parse(line);
        if ((entry.hash || "").toUpperCase() === upper) {
          found = entry;
          rl.close();
        }
      } catch {
        return;
      }
    });
    rl.on("close", () => {
      stream.close();
      resolve(found);
    });
  });
}

function listBlocks(limit, beforeHeight) {
  let items = blocksCache.slice();
  if (beforeHeight) {
    items = items.filter((b) => b.height < beforeHeight);
  }
  const slice = items.slice(-limit);
  return slice.reverse();
}

function listTxs(limit, height) {
  let items = txsCache.slice();
  if (height) {
    items = items.filter((t) => t.height === height);
  }
  const slice = items.slice(-limit);
  return slice.reverse();
}

function metrics() {
  const lines = [];
  lines.push("# HELP ynx_indexer_last_height Last indexed block height");
  lines.push("# TYPE ynx_indexer_last_height gauge");
  lines.push(`ynx_indexer_last_height ${state.last_height || 0}`);
  lines.push("# HELP ynx_indexer_latest_seen Latest height observed from RPC");
  lines.push("# TYPE ynx_indexer_latest_seen gauge");
  lines.push(`ynx_indexer_latest_seen ${latestSeenHeight || 0}`);
  lines.push("# HELP ynx_indexer_blocks_indexed Total blocks indexed");
  lines.push("# TYPE ynx_indexer_blocks_indexed counter");
  lines.push(`ynx_indexer_blocks_indexed ${state.blocks_indexed || 0}`);
  lines.push("# HELP ynx_indexer_txs_indexed Total transactions indexed");
  lines.push("# TYPE ynx_indexer_txs_indexed counter");
  lines.push(`ynx_indexer_txs_indexed ${state.txs_indexed || 0}`);
  return lines.join("\n") + "\n";
}

async function fetchValidatorsSnapshot() {
  const status = await rpcRequest("/status");
  const latestHeight = parseInt(status?.result?.sync_info?.latest_block_height || "0", 10);
  if (!latestHeight) {
    return {
      latest_height: 0,
      total: 0,
      signed_count: 0,
      validators: [],
    };
  }

  const validators = [];
  let page = 1;
  let total = 0;

  while (true) {
    const pageData = await rpcRequest(`/validators?height=${latestHeight}&page=${page}&per_page=100`);
    const result = pageData?.result || {};
    const items = result.validators || [];
    total = parseInt(result.total || "0", 10) || items.length;
    validators.push(...items);
    if (!items.length || validators.length >= total) break;
    page += 1;
  }

  const blockData = await rpcRequest(`/block?height=${latestHeight}`);
  const signatures = blockData?.result?.block?.last_commit?.signatures || [];
  const signedSet = new Set(
    signatures
      .filter((s) => s && Number(s.block_id_flag) === 2 && s.validator_address)
      .map((s) => s.validator_address)
  );

  const rows = validators.map((validator) => ({
    address: validator.address || "",
    voting_power: parseInt(validator.voting_power || "0", 10),
    proposer_priority: parseInt(validator.proposer_priority || "0", 10),
    signed_last_block: signedSet.has(validator.address || ""),
  }));

  rows.sort((a, b) => b.voting_power - a.voting_power);

  return {
    latest_height: latestHeight,
    total: rows.length,
    signed_count: rows.filter((row) => row.signed_last_block).length,
    validators: rows,
  };
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,OPTIONS",
      "access-control-allow-headers": "content-type",
    });
    return res.end();
  }

  if (req.method !== "GET") {
    return json(res, 405, { ok: false, error: "method_not_allowed" });
  }

  const url = new URL(req.url, "http://localhost");

  if (url.pathname === "/health") {
    return json(res, 200, {
      ok: true,
      chain_id: chainId,
      rpc: INDEXER_RPC,
      last_indexed: state.last_height || 0,
      latest_seen: latestSeenHeight || 0,
    });
  }

  if (url.pathname === "/stats") {
    return json(res, 200, {
      ok: true,
      chain_id: chainId,
      rpc: INDEXER_RPC,
      last_indexed: state.last_height || 0,
      latest_seen: latestSeenHeight || 0,
      blocks_indexed: state.blocks_indexed || 0,
      txs_indexed: state.txs_indexed || 0,
      cache_blocks: blocksCache.length,
      cache_txs: txsCache.length,
    });
  }

  if (url.pathname === "/metrics") {
    const body = metrics();
    res.writeHead(200, {
      "content-type": "text/plain",
      "content-length": Buffer.byteLength(body),
      "access-control-allow-origin": "*",
    });
    return res.end(body);
  }

  if (url.pathname === "/ynx/overview") {
    return json(res, 200, {
      ok: true,
      chain_id: chainId,
      rpc: INDEXER_RPC,
      latest_seen: latestSeenHeight || 0,
      last_indexed: state.last_height || 0,
      governance: governanceMeta,
      value_proposition: {
        evm_compatible: true,
        onchain_governance: true,
        open_validator_program: true,
        public_testnet_live: true,
      },
      positioning: {
        statement: "Governance-native EVM chain for real Web3 services",
        target_users: [
          "web3 builders",
          "validator operators",
          "onchain organizations",
        ],
        why_choose_ynx: [
          "mainnet-parity public testnet workflow",
          "machine-readable governance and fee-routing transparency",
          "copy-paste operator onboarding and verification tooling",
          "open validator onboarding with phased decentralization",
        ],
      },
    });
  }

  if (url.pathname === "/validators") {
    try {
      const snapshot = await fetchValidatorsSnapshot();
      return json(res, 200, { ok: true, ...snapshot });
    } catch (err) {
      return json(res, 500, { ok: false, error: "validators_fetch_failed", detail: err.message });
    }
  }

  if (url.pathname === "/blocks") {
    const limit = envNumber("INDEXER_API_LIMIT", 20);
    const requestedParam = url.searchParams.get("limit");
    const parsedLimit = requestedParam ? parseInt(requestedParam, 10) : limit;
    const requested = Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : limit;
    const before = url.searchParams.get("before");
    const beforeHeight = before ? parseInt(before, 10) : 0;
    const items = listBlocks(Math.min(requested, 200), beforeHeight || 0);
    return json(res, 200, { ok: true, items });
  }

  if (url.pathname.startsWith("/blocks/")) {
    const heightStr = url.pathname.split("/")[2];
    const height = parseInt(heightStr, 10);
    if (!height || Number.isNaN(height)) {
      return json(res, 400, { ok: false, error: "invalid_height" });
    }
    const block = await findBlockByHeight(height);
    if (!block) {
      return json(res, 404, { ok: false, error: "not_found" });
    }
    return json(res, 200, { ok: true, block });
  }

  if (url.pathname === "/txs") {
    const limit = envNumber("INDEXER_API_LIMIT", 20);
    const requestedParam = url.searchParams.get("limit");
    const parsedLimit = requestedParam ? parseInt(requestedParam, 10) : limit;
    const requested = Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : limit;
    const heightParam = url.searchParams.get("height");
    const height = heightParam ? parseInt(heightParam, 10) : 0;
    const items = listTxs(Math.min(requested, 200), height || 0);
    return json(res, 200, { ok: true, items });
  }

  if (url.pathname.startsWith("/txs/")) {
    const hash = url.pathname.split("/")[2];
    if (!hash) {
      return json(res, 400, { ok: false, error: "invalid_hash" });
    }
    const tx = await findTxByHash(hash);
    if (!tx) {
      return json(res, 404, { ok: false, error: "not_found" });
    }
    return json(res, 200, { ok: true, tx });
  }

  return json(res, 404, { ok: false, error: "not_found" });
});

async function start() {
  await initChainId();
  await initGovernanceMeta();
  server.listen(INDEXER_PORT, () => {
    log(`YNX indexer listening on :${INDEXER_PORT}`);
    log(`RPC: ${INDEXER_RPC}`);
  });
  setInterval(poll, INDEXER_POLL_MS);
  poll();
}

start();
