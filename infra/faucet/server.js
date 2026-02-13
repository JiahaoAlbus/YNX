const http = require("http");
const { execFile } = require("child_process");
const fs = require("fs");
const path = require("path");

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
if (process.env.FAUCET_ENV_FILE) envCandidates.push(process.env.FAUCET_ENV_FILE);
if (process.env.YNX_ENV_FILE) envCandidates.push(process.env.YNX_ENV_FILE);
envCandidates.push(path.resolve(__dirname, ".env"));
envCandidates.push(path.resolve(__dirname, "../../.env"));

for (const candidate of envCandidates) {
  loadEnvFile(candidate);
}

const FAUCET_PORT = parseInt(process.env.FAUCET_PORT || "8080", 10);
const FAUCET_HOME = process.env.FAUCET_HOME || path.resolve(__dirname, "../../chain/.testnet");
const FAUCET_KEY = process.env.FAUCET_KEY || "faucet";
const FAUCET_KEYRING = process.env.FAUCET_KEYRING || "os";
const FAUCET_CHAIN_ID = process.env.FAUCET_CHAIN_ID || "ynx_9002-1";
const FAUCET_NODE = process.env.FAUCET_NODE || "http://127.0.0.1:26657";
const FAUCET_DENOM = process.env.FAUCET_DENOM || "anyxt";
const FAUCET_AMOUNT = process.env.FAUCET_AMOUNT || "1000000000000000000";
const FAUCET_GAS_PRICES = process.env.FAUCET_GAS_PRICES || "0anyxt";
const FAUCET_GAS_ADJUSTMENT = process.env.FAUCET_GAS_ADJUSTMENT || "1.2";
const RATE_LIMIT_SECONDS = parseInt(process.env.FAUCET_RATE_LIMIT_SECONDS || "3600", 10);
const MAX_PER_DAY = parseInt(process.env.FAUCET_MAX_PER_DAY || "3", 10);
const IP_RATE_LIMIT_SECONDS = parseInt(process.env.FAUCET_IP_RATE_LIMIT_SECONDS || "60", 10);
const IP_MAX_PER_DAY = parseInt(process.env.FAUCET_IP_MAX_PER_DAY || "10", 10);
const TRUST_PROXY = process.env.FAUCET_TRUST_PROXY === "1";
const MAX_INFLIGHT = parseInt(process.env.FAUCET_MAX_INFLIGHT || "1", 10);
const YNXD = process.env.YNXD_PATH || path.resolve(__dirname, "../../chain/ynxd");

const dataDir = process.env.FAUCET_DATA_DIR || path.resolve(__dirname, "data");
const statePath = path.join(dataDir, "ratelimit.json");

if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

let state = { addresses: {}, ips: {} };
if (fs.existsSync(statePath)) {
  try {
    state = JSON.parse(fs.readFileSync(statePath, "utf8"));
  } catch {
    state = { addresses: {}, ips: {} };
  }
}

function saveState() {
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
}

function json(res, code, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(code, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
  });
  res.end(body);
}

function parseBody(req) {
  return new Promise((resolve) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk.toString();
    });
    req.on("end", () => {
      if (!data) return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch {
        resolve({});
      }
    });
  });
}

function isBech32(addr) {
  return /^ynx1[0-9a-z]{10,}$/.test(addr);
}

function isHex(addr) {
  return /^0x[0-9a-fA-F]{40}$/.test(addr);
}

function resolveBech32(addr) {
  return new Promise((resolve, reject) => {
    if (isBech32(addr)) return resolve(addr);
    if (!isHex(addr)) return reject(new Error("Invalid address format"));

    execFile(YNXD, ["debug", "addr", addr], (err, stdout) => {
      if (err) return reject(err);
      const line = stdout
        .split("\n")
        .find((l) => l.startsWith("Bech32 Acc "));
      if (!line) return reject(new Error("Failed to convert address"));
      const bech = line.replace("Bech32 Acc ", "").trim();
      if (!isBech32(bech)) return reject(new Error("Invalid bech32 output"));
      resolve(bech);
    });
  });
}

function checkRateLimit(address) {
  const now = Date.now();
  const dayAgo = now - 24 * 60 * 60 * 1000;
  const list = (state.addresses[address] || []).filter((t) => t >= dayAgo);
  if (list.length >= MAX_PER_DAY) {
    return { ok: false, reason: "daily_limit" };
  }
  if (list.length > 0 && now - list[list.length - 1] < RATE_LIMIT_SECONDS * 1000) {
    return { ok: false, reason: "rate_limited" };
  }
  list.push(now);
  state.addresses[address] = list;
  saveState();
  return { ok: true };
}

function checkIpRateLimit(ip) {
  if (!ip) return { ok: true };
  const now = Date.now();
  const dayAgo = now - 24 * 60 * 60 * 1000;
  const list = (state.ips[ip] || []).filter((t) => t >= dayAgo);
  if (list.length >= IP_MAX_PER_DAY) {
    return { ok: false, reason: "ip_daily_limit" };
  }
  if (list.length > 0 && now - list[list.length - 1] < IP_RATE_LIMIT_SECONDS * 1000) {
    return { ok: false, reason: "ip_rate_limited" };
  }
  list.push(now);
  state.ips[ip] = list;
  saveState();
  return { ok: true };
}

function getClientIp(req) {
  if (TRUST_PROXY) {
    const header = req.headers["x-forwarded-for"];
    if (header) {
      const first = header.split(",")[0].trim();
      if (first) return first;
    }
  }
  const socketAddr = req.socket?.remoteAddress || "";
  return socketAddr.replace(/^::ffff:/, "");
}

function sendTokens(toAddress) {
  return new Promise((resolve, reject) => {
    const amount = `${FAUCET_AMOUNT}${FAUCET_DENOM}`;
    const args = [
      "tx",
      "bank",
      "send",
      FAUCET_KEY,
      toAddress,
      amount,
      "--chain-id",
      FAUCET_CHAIN_ID,
      "--node",
      FAUCET_NODE,
      "--keyring-backend",
      FAUCET_KEYRING,
      "--home",
      FAUCET_HOME,
      "--gas",
      "auto",
      "--gas-adjustment",
      FAUCET_GAS_ADJUSTMENT,
      "--gas-prices",
      FAUCET_GAS_PRICES,
      "--yes",
      "--output",
      "json",
    ];

    execFile(YNXD, args, (err, stdout, stderr) => {
      if (err) return reject(new Error(stderr || err.message));
      try {
        const result = JSON.parse(stdout);
        if (result.code && result.code !== 0) {
          return reject(new Error(result.raw_log || "broadcast failed"));
        }
        resolve(result);
      } catch (e) {
        reject(new Error(`Invalid response: ${e.message}`));
      }
    });
  });
}

let inflight = 0;
const queue = [];

async function enqueue(fn) {
  return new Promise((resolve, reject) => {
    queue.push({ fn, resolve, reject });
    processQueue();
  });
}

async function processQueue() {
  if (inflight >= MAX_INFLIGHT || queue.length === 0) return;
  const item = queue.shift();
  inflight += 1;
  try {
    const result = await item.fn();
    item.resolve(result);
  } catch (err) {
    item.reject(err);
  } finally {
    inflight -= 1;
    processQueue();
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    return json(res, 200, {
      ok: true,
      chain_id: FAUCET_CHAIN_ID,
      denom: FAUCET_DENOM,
      amount: FAUCET_AMOUNT,
    });
  }

  if ((req.method === "POST" && req.url === "/faucet") || (req.method === "GET" && req.url.startsWith("/faucet"))) {
    const body = req.method === "POST" ? await parseBody(req) : {};
    const url = new URL(req.url, "http://localhost");
    const addrInput = body.address || url.searchParams.get("address");
    if (!addrInput) {
      return json(res, 400, { ok: false, error: "address_required" });
    }

    try {
      const address = await resolveBech32(addrInput.trim());
      const ip = getClientIp(req);
      const ipLimit = checkIpRateLimit(ip);
      if (!ipLimit.ok) {
        return json(res, 429, { ok: false, error: ipLimit.reason });
      }
      const limit = checkRateLimit(address);
      if (!limit.ok) {
        return json(res, 429, { ok: false, error: limit.reason });
      }
      const result = await enqueue(() => sendTokens(address));
      return json(res, 200, {
        ok: true,
        address,
        amount: `${FAUCET_AMOUNT}${FAUCET_DENOM}`,
        txhash: result.txhash,
      });
    } catch (err) {
      return json(res, 500, { ok: false, error: err.message });
    }
  }

  json(res, 404, { ok: false, error: "not_found" });
});

server.listen(FAUCET_PORT, () => {
  console.log(`YNX faucet listening on :${FAUCET_PORT}`);
});
