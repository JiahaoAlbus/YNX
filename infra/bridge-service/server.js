const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
const crypto = require("crypto");
const { ethers } = require("ethers");

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
    if (!(key in process.env)) process.env[key] = value;
  }
}

const envCandidates = [];
if (process.env.BRIDGE_ENV_FILE) envCandidates.push(process.env.BRIDGE_ENV_FILE);
if (process.env.YNX_ENV_FILE) envCandidates.push(process.env.YNX_ENV_FILE);
envCandidates.push(path.resolve(__dirname, ".env"));
envCandidates.push(path.resolve(__dirname, "../../.env"));
for (const candidate of envCandidates) loadEnvFile(candidate);

function json(res, status, payload, extraHeaders = {}) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
    "access-control-allow-origin": "*",
    ...extraHeaders,
  });
  res.end(body);
}

function parseBody(req, limitBytes) {
  return new Promise((resolve) => {
    let raw = "";
    let size = 0;
    let tooLarge = false;
    req.on("data", (chunk) => {
      if (tooLarge) return;
      size += chunk.length;
      if (size > limitBytes) {
        tooLarge = true;
        req.destroy();
        return resolve({ __parse_error: "payload_too_large" });
      }
      raw += chunk.toString();
    });
    req.on("error", () => resolve({ __parse_error: tooLarge ? "payload_too_large" : "request_error" }));
    req.on("end", () => {
      if (tooLarge) return;
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        resolve({ __parse_error: "invalid_json" });
      }
    });
  });
}

function requireValidBody(res, body) {
  if (!body || !body.__parse_error) return true;
  json(res, body.__parse_error === "payload_too_large" ? 413 : 400, { ok: false, error: body.__parse_error });
  return false;
}

function nowIso() {
  return new Date().toISOString();
}

function readJson(filePath, fallback) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return fallback;
  }
}

function atomicWriteJson(filePath, payload) {
  const tmpPath = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmpPath, JSON.stringify(payload, null, 2));
  fs.renameSync(tmpPath, filePath);
}

function normalizeHex32(value, fallback) {
  if (typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value)) return value;
  return ethers.id(String(value || fallback || ""));
}

function normalizeAddress(value) {
  try {
    return ethers.getAddress(String(value || ""));
  } catch {
    return "";
  }
}

function parseAmountUnits(value, decimals) {
  if (value === undefined || value === null || value === "") throw new Error("amount_required");
  const str = String(value).trim();
  if (!/^[0-9]+(\.[0-9]+)?$/.test(str)) throw new Error("invalid_amount");
  return ethers.parseUnits(str, decimals);
}

function requestJson(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(targetUrl);
    const body = options.body === undefined ? "" : String(options.body);
    const transport = url.protocol === "https:" ? https : http;
    const req = transport.request(
      {
        method: options.method || "GET",
        hostname: url.hostname,
        port: url.port || (url.protocol === "https:" ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        timeout: options.timeout_ms || 10000,
        headers: {
          ...(body ? { "content-type": "application/json", "content-length": Buffer.byteLength(body) } : {}),
          ...(options.headers || {}),
        },
      },
      (upstream) => {
        let raw = "";
        upstream.on("data", (chunk) => {
          raw += chunk.toString();
        });
        upstream.on("end", () => {
          try {
            resolve({ status: upstream.statusCode || 0, body: raw ? JSON.parse(raw) : {} });
          } catch {
            resolve({ status: upstream.statusCode || 0, body: { raw } });
          }
        });
      },
    );
    req.on("timeout", () => req.destroy(new Error("upstream_timeout")));
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

const BRIDGE_PORT = parseInt(process.env.BRIDGE_PORT || "38083", 10);
const BRIDGE_DATA_DIR = process.env.BRIDGE_DATA_DIR || path.resolve(__dirname, "data");
const BRIDGE_DATA_FILE = path.join(BRIDGE_DATA_DIR, "state.json");
const BRIDGE_ROUTES_FILE = process.env.BRIDGE_ROUTES_FILE || path.resolve(__dirname, "config/testnet-routes.json");
const BRIDGE_BODY_LIMIT_BYTES = parseInt(process.env.BRIDGE_BODY_LIMIT_BYTES || "1048576", 10);
const BRIDGE_YNX_RPC_URL = process.env.BRIDGE_YNX_RPC_URL || process.env.YNX_PUBLIC_EVM_RPC || "https://evm.ynxweb4.com";
const BRIDGE_GATEWAY_ADDRESS = process.env.BRIDGE_GATEWAY_ADDRESS || "";
const BRIDGE_RELAYER_PRIVATE_KEY = process.env.BRIDGE_RELAYER_PRIVATE_KEY || process.env.YNX_EVM_PRIVATE_KEY || "";
const BRIDGE_ONCHAIN_ENABLED = process.env.BRIDGE_ONCHAIN_ENABLED === "1";
const BRIDGE_CONFIRMATIONS = Math.max(0, parseInt(process.env.BRIDGE_CONFIRMATIONS || "1", 10) || 0);
const BRIDGE_REQUIRE_OPERATOR_TOKEN = process.env.BRIDGE_REQUIRE_OPERATOR_TOKEN === "1";
const BRIDGE_OPERATOR_TOKEN = process.env.BRIDGE_OPERATOR_TOKEN || "";

const GATEWAY_ABI = [
  "function mintAttestationPayloadWithAsset(bytes32 depositId,uint64 sourceChainId,bytes32 sourceAssetId,address token,address recipient,uint256 amount) view returns (bytes32)",
  "function mintWithMappedAttestation(bytes32 depositId,uint64 sourceChainId,bytes32 sourceAssetId,address recipient,uint256 amount,bytes[] signatures)",
  "function processedDeposits(bytes32 depositId) view returns (bool)",
  "function wrappedTokenByRemoteAsset(uint64 sourceChainId,bytes32 sourceAssetId) view returns (address)",
  "function outboundNonce() view returns (uint256)",
];

if (!fs.existsSync(BRIDGE_DATA_DIR)) fs.mkdirSync(BRIDGE_DATA_DIR, { recursive: true });

let routesConfig = readJson(BRIDGE_ROUTES_FILE, { routes: [] });
let state = readJson(BRIDGE_DATA_FILE, {
  deposits: [],
  withdrawals: [],
  audit_logs: [],
});
if (!Array.isArray(state.deposits)) state.deposits = [];
if (!Array.isArray(state.withdrawals)) state.withdrawals = [];
if (!Array.isArray(state.audit_logs)) state.audit_logs = [];

const runtime = {
  provider: null,
  wallet: null,
  gateway: null,
  last_error: "",
  last_tx_hash: "",
  last_tx_at: "",
};

function saveState() {
  atomicWriteJson(BRIDGE_DATA_FILE, state);
}

function addAudit(event, payload) {
  state.audit_logs.unshift({
    audit_id: `audit_${crypto.randomBytes(8).toString("hex")}`,
    event,
    payload,
    created_at: nowIso(),
  });
  state.audit_logs = state.audit_logs.slice(0, 5000);
}

function routeById(routeId) {
  return (routesConfig.routes || []).find((route) => route.routeId === routeId);
}

function depositById(depositId) {
  return state.deposits.find((item) => item.deposit_id === depositId);
}

function withdrawalById(withdrawalId) {
  return state.withdrawals.find((item) => item.withdrawal_id === withdrawalId);
}

function gatewayAddress() {
  return BRIDGE_GATEWAY_ADDRESS || routesConfig.gateway || "";
}

function onchainReady() {
  return Boolean(BRIDGE_ONCHAIN_ENABLED && BRIDGE_YNX_RPC_URL && BRIDGE_RELAYER_PRIVATE_KEY && gatewayAddress());
}

function getGateway() {
  if (!BRIDGE_ONCHAIN_ENABLED) throw new Error("bridge_onchain_disabled");
  if (!BRIDGE_YNX_RPC_URL) throw new Error("bridge_ynx_rpc_required");
  if (!BRIDGE_RELAYER_PRIVATE_KEY) throw new Error("bridge_relayer_private_key_required");
  if (!gatewayAddress()) throw new Error("bridge_gateway_required");
  if (!runtime.gateway) {
    runtime.provider = new ethers.JsonRpcProvider(BRIDGE_YNX_RPC_URL);
    runtime.wallet = new ethers.Wallet(BRIDGE_RELAYER_PRIVATE_KEY, runtime.provider);
    runtime.gateway = new ethers.Contract(gatewayAddress(), GATEWAY_ABI, runtime.wallet);
  }
  return runtime.gateway;
}

async function waitTx(tx) {
  const receipt = await tx.wait(BRIDGE_CONFIRMATIONS);
  runtime.last_tx_hash = tx.hash;
  runtime.last_tx_at = nowIso();
  runtime.last_error = "";
  return {
    tx_hash: tx.hash,
    block_number: receipt?.blockNumber || null,
    confirmations: BRIDGE_CONFIRMATIONS,
  };
}

function buildDepositId(route, body) {
  const sourceTxHash = String(body.source_tx_hash || body.tx_hash || "").trim();
  if (!sourceTxHash) throw new Error("source_tx_hash_required");
  const index = String(body.log_index ?? body.output_index ?? body.vout ?? "0").trim();
  return normalizeHex32(body.deposit_id, `${route.routeId}:${sourceTxHash}:${index}`);
}

function assertOperator(req) {
  if (!BRIDGE_REQUIRE_OPERATOR_TOKEN) return true;
  const token = req.headers["x-ynx-bridge-token"] || "";
  return Boolean(BRIDGE_OPERATOR_TOKEN && token === BRIDGE_OPERATOR_TOKEN);
}

async function mintOnYnx(deposit, route) {
  const gateway = getGateway();
  const alreadyProcessed = await gateway.processedDeposits(deposit.deposit_id);
  if (alreadyProcessed) {
    return { already_processed: true, deposit_id: deposit.deposit_id, contract: gatewayAddress() };
  }
  const payload = await gateway.mintAttestationPayloadWithAsset(
    deposit.deposit_id,
    BigInt(route.sourceChainId),
    route.sourceAssetId,
    route.wrappedToken,
    deposit.recipient,
    BigInt(deposit.amount_base_units),
  );
  const signature = await runtime.wallet.signMessage(ethers.getBytes(payload));
  const tx = await gateway.mintWithMappedAttestation(
    deposit.deposit_id,
    BigInt(route.sourceChainId),
    route.sourceAssetId,
    deposit.recipient,
    BigInt(deposit.amount_base_units),
    [signature],
  );
  return {
    ...(await waitTx(tx)),
    contract: gatewayAddress(),
    source_asset_id: route.sourceAssetId,
    wrapped_token: route.wrappedToken,
  };
}

async function sourceStatus(route) {
  if (route.sourceKind === "evm") {
    const provider = new ethers.JsonRpcProvider(route.rpc);
    const [chainId, blockNumber] = await Promise.all([
      provider.getNetwork().then((n) => n.chainId.toString()),
      provider.getBlockNumber(),
    ]);
    return { routeId: route.routeId, ok: true, sourceKind: route.sourceKind, chainId, blockNumber };
  }
  if (route.sourceKind === "bitcoin") {
    const response = await requestJson(`${route.rpc.replace(/\/$/, "")}/blocks/tip/height`, { timeout_ms: 10000 });
    const height = typeof response.body === "number" ? response.body : Number(response.body.raw || response.body);
    return { routeId: route.routeId, ok: response.status >= 200 && response.status < 300, sourceKind: route.sourceKind, height };
  }
  if (route.sourceKind === "tron") {
    const response = await requestJson(`${route.rpc.replace(/\/$/, "")}/wallet/getnowblock`, {
      method: "POST",
      body: "{}",
      timeout_ms: 10000,
    });
    const height = response.body?.block_header?.raw_data?.number ?? null;
    return { routeId: route.routeId, ok: response.status >= 200 && response.status < 300, sourceKind: route.sourceKind, height };
  }
  return { routeId: route.routeId, ok: false, error: "unsupported_source_kind" };
}

async function verifyGatewayRoute(route) {
  if (!BRIDGE_YNX_RPC_URL || !gatewayAddress()) return { routeId: route.routeId, ok: false, error: "ynx_gateway_unconfigured" };
  const provider = new ethers.JsonRpcProvider(BRIDGE_YNX_RPC_URL);
  const gateway = new ethers.Contract(gatewayAddress(), GATEWAY_ABI, provider);
  const mapped = await gateway.wrappedTokenByRemoteAsset(BigInt(route.sourceChainId), route.sourceAssetId);
  return {
    routeId: route.routeId,
    ok: mapped.toLowerCase() === route.wrappedToken.toLowerCase(),
    sourceChainId: route.sourceChainId,
    sourceAssetId: route.sourceAssetId,
    expectedWrappedToken: route.wrappedToken,
    mappedWrappedToken: mapped,
  };
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "content-type,x-ynx-bridge-token",
    });
    return res.end();
  }

  const url = new URL(req.url, "http://localhost");
  const segments = url.pathname.split("/").filter(Boolean);

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/health") {
    return json(res, 200, {
      ok: true,
      service: "ynx-bridge-service",
      network: routesConfig.network || "",
      ynx_chain_id: routesConfig.ynxChainId || 9102,
      gateway: gatewayAddress(),
      onchain: {
        enabled: BRIDGE_ONCHAIN_ENABLED,
        ready: onchainReady(),
        rpc_configured: Boolean(BRIDGE_YNX_RPC_URL),
        relayer_configured: Boolean(BRIDGE_RELAYER_PRIVATE_KEY),
        confirmations: BRIDGE_CONFIRMATIONS,
        last_tx_hash: runtime.last_tx_hash,
        last_tx_at: runtime.last_tx_at,
        last_error: runtime.last_error,
      },
      stats: {
        routes: (routesConfig.routes || []).length,
        deposits: state.deposits.length,
        withdrawals: state.withdrawals.length,
        minted_deposits: state.deposits.filter((item) => item.status === "minted").length,
        queued_withdrawals: state.withdrawals.filter((item) => item.status === "queued").length,
      },
    });
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/ready") {
    const checks = {
      routes: (routesConfig.routes || []).length > 0,
      gateway: Boolean(gatewayAddress()),
      onchain: !BRIDGE_ONCHAIN_ENABLED || onchainReady(),
    };
    const ok = checks.routes && checks.gateway && checks.onchain;
    return json(res, ok ? 200 : 503, { ok, checks });
  }

  if (req.method === "GET" && url.pathname === "/bridge/routes") {
    return json(res, 200, { ok: true, items: routesConfig.routes || [] });
  }

  if (req.method === "GET" && url.pathname === "/bridge/source-status") {
    const results = [];
    for (const route of routesConfig.routes || []) {
      try {
        results.push(await sourceStatus(route));
      } catch (error) {
        results.push({ routeId: route.routeId, ok: false, error: error.message || String(error) });
      }
    }
    return json(res, 200, { ok: true, items: results });
  }

  if (req.method === "GET" && url.pathname === "/bridge/route-checks") {
    const results = [];
    for (const route of routesConfig.routes || []) {
      try {
        results.push(await verifyGatewayRoute(route));
      } catch (error) {
        results.push({ routeId: route.routeId, ok: false, error: error.message || String(error) });
      }
    }
    return json(res, 200, { ok: true, items: results });
  }

  if (req.method === "GET" && url.pathname === "/bridge/deposits") {
    return json(res, 200, { ok: true, items: state.deposits });
  }

  if (req.method === "POST" && url.pathname === "/bridge/deposits/prove") {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const body = await parseBody(req, BRIDGE_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const route = routeById(body.route_id || body.routeId);
    if (!route) return json(res, 400, { ok: false, error: "route_not_found" });
    const recipient = normalizeAddress(body.recipient);
    if (!recipient) return json(res, 400, { ok: false, error: "invalid_recipient" });
    const confirmations = Number(body.confirmations || 0);
    if (confirmations < Number(route.minConfirmations || 0)) {
      return json(res, 400, { ok: false, error: "insufficient_confirmations", required: route.minConfirmations, confirmations });
    }

    let amountBaseUnits;
    try {
      amountBaseUnits = body.amount_base_units !== undefined
        ? BigInt(String(body.amount_base_units))
        : parseAmountUnits(body.amount, route.decimals);
    } catch (error) {
      return json(res, 400, { ok: false, error: error.message || "invalid_amount" });
    }
    if (amountBaseUnits <= 0n) return json(res, 400, { ok: false, error: "invalid_amount" });

    let depositId;
    try {
      depositId = buildDepositId(route, body);
    } catch (error) {
      return json(res, 400, { ok: false, error: error.message || "invalid_deposit_id" });
    }
    const existing = depositById(depositId);
    if (existing) return json(res, 200, { ok: true, deposit: existing, duplicate: true });

    const deposit = {
      deposit_id: depositId,
      route_id: route.routeId,
      source_kind: route.sourceKind,
      source_network: route.sourceNetwork,
      source_chain_id: route.sourceChainId,
      source_asset_id: route.sourceAssetId,
      wrapped_token: route.wrappedToken,
      wrapped_symbol: route.wrappedSymbol,
      recipient,
      amount_base_units: amountBaseUnits.toString(),
      amount: ethers.formatUnits(amountBaseUnits, route.decimals),
      source_tx_hash: String(body.source_tx_hash || body.tx_hash || ""),
      source_index: String(body.log_index ?? body.output_index ?? body.vout ?? "0"),
      confirmations,
      proof: body.proof || {},
      status: BRIDGE_ONCHAIN_ENABLED ? "accepted" : "accepted_dry_run",
      created_at: nowIso(),
      updated_at: nowIso(),
      onchain: null,
    };

    if (BRIDGE_ONCHAIN_ENABLED) {
      try {
        const onchain = await mintOnYnx(deposit, route);
        deposit.onchain = onchain;
        deposit.status = onchain.already_processed ? "already_minted" : "minted";
      } catch (error) {
        runtime.last_error = error.message || String(error);
        deposit.status = "mint_failed";
        deposit.error = runtime.last_error;
      }
    }

    state.deposits.unshift(deposit);
    addAudit("deposit.proved", { deposit_id: deposit.deposit_id, route_id: route.routeId, status: deposit.status });
    saveState();
    return json(res, deposit.status === "mint_failed" ? 502 : 201, { ok: deposit.status !== "mint_failed", deposit });
  }

  if (segments[0] === "bridge" && segments[1] === "deposits" && segments[2] && req.method === "GET") {
    const deposit = depositById(segments[2]);
    if (!deposit) return json(res, 404, { ok: false, error: "deposit_not_found" });
    return json(res, 200, { ok: true, deposit });
  }

  if (segments[0] === "bridge" && segments[1] === "deposits" && segments[2] === "reconcile" && req.method === "POST") {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const results = [];
    for (const deposit of state.deposits) {
      if (!deposit.deposit_id || !deposit.source_chain_id || !deposit.source_asset_id) continue;
      try {
        const gateway = getGateway();
        const processed = await gateway.processedDeposits(deposit.deposit_id);
        if (processed && deposit.status !== "minted") {
          deposit.status = "minted";
          deposit.updated_at = nowIso();
        }
        results.push({ deposit_id: deposit.deposit_id, processed, status: deposit.status });
      } catch (error) {
        results.push({ deposit_id: deposit.deposit_id, ok: false, error: error.message || String(error) });
      }
    }
    addAudit("deposit.reconciled", { count: results.length });
    saveState();
    return json(res, 200, { ok: true, items: results });
  }

  if (req.method === "GET" && url.pathname === "/bridge/withdrawals") {
    return json(res, 200, { ok: true, items: state.withdrawals });
  }

  if (req.method === "POST" && url.pathname === "/bridge/withdrawals/request") {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const body = await parseBody(req, BRIDGE_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const route = routeById(body.route_id || body.routeId);
    if (!route) return json(res, 400, { ok: false, error: "route_not_found" });
    let amountBaseUnits;
    try {
      amountBaseUnits = body.amount_base_units !== undefined
        ? BigInt(String(body.amount_base_units))
        : parseAmountUnits(body.amount, route.decimals);
    } catch (error) {
      return json(res, 400, { ok: false, error: error.message || "invalid_amount" });
    }
    const withdrawal = {
      withdrawal_id: normalizeHex32(body.withdrawal_id, `${route.routeId}:${body.burn_tx_hash || crypto.randomBytes(8).toString("hex")}:${Date.now()}`),
      route_id: route.routeId,
      source_chain_id: route.sourceChainId,
      source_asset_id: route.sourceAssetId,
      wrapped_token: route.wrappedToken,
      amount_base_units: amountBaseUnits.toString(),
      amount: ethers.formatUnits(amountBaseUnits, route.decimals),
      destination_recipient: String(body.destination_recipient || ""),
      burn_tx_hash: String(body.burn_tx_hash || ""),
      status: "queued",
      created_at: nowIso(),
      updated_at: nowIso(),
      proof: body.proof || {},
    };
    state.withdrawals.unshift(withdrawal);
    addAudit("withdrawal.queued", { withdrawal_id: withdrawal.withdrawal_id, route_id: route.routeId });
    saveState();
    return json(res, 201, { ok: true, withdrawal });
  }

  if (segments[0] === "bridge" && segments[1] === "withdrawals" && segments[2] && req.method === "GET") {
    const withdrawal = withdrawalById(segments[2]);
    if (!withdrawal) return json(res, 404, { ok: false, error: "withdrawal_not_found" });
    return json(res, 200, { ok: true, withdrawal });
  }

  if (req.method === "GET" && url.pathname === "/bridge/audit") {
    const limit = Math.max(1, Math.min(500, Number(url.searchParams.get("limit") || 100)));
    return json(res, 200, { ok: true, items: state.audit_logs.slice(0, limit) });
  }

  return json(res, 404, { ok: false, error: "not_found" });
});

server.listen(BRIDGE_PORT, () => {
  console.log(`YNX bridge service listening on :${BRIDGE_PORT}`);
});

async function shutdown(signal) {
  console.log(`[bridge-service] received ${signal}, saving state...`);
  try {
    saveState();
  } catch (error) {
    console.error("[bridge-service] save failed:", error);
  }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1500).unref();
}

process.on("SIGINT", () => void shutdown("SIGINT"));
process.on("SIGTERM", () => void shutdown("SIGTERM"));
