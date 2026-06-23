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
    ...extraHeaders,
  });
  res.end(body);
}

function parseAllowedOrigins(value) {
  return String(value || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function resolveCorsOrigin(origin, allowedOrigins) {
  if (allowedOrigins.length === 0 || allowedOrigins.includes("*")) {
    return "*";
  }
  if (origin && allowedOrigins.includes(origin)) {
    return origin;
  }
  return allowedOrigins[0];
}

function corsHeaders(req = null) {
  const origin = req?.headers?.origin || "";
  const allowOrigin = resolveCorsOrigin(origin, BRIDGE_CORS_ALLOWED_ORIGINS);
  const headers = {
    "access-control-allow-origin": allowOrigin,
  };
  if (allowOrigin !== "*") headers.vary = "origin";
  return headers;
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
const BRIDGE_ASSETS_FILE = process.env.BRIDGE_ASSETS_FILE || path.resolve(__dirname, "config/public-assets-9102.json");
const BRIDGE_BODY_LIMIT_BYTES = parseInt(process.env.BRIDGE_BODY_LIMIT_BYTES || "1048576", 10);
const BRIDGE_SERVER_HEADERS_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.BRIDGE_SERVER_HEADERS_TIMEOUT_MS || "15000", 10) || 15000,
);
const BRIDGE_SERVER_REQUEST_TIMEOUT_MS = Math.max(
  BRIDGE_SERVER_HEADERS_TIMEOUT_MS,
  parseInt(process.env.BRIDGE_SERVER_REQUEST_TIMEOUT_MS || "30000", 10) || 30000,
);
const BRIDGE_SERVER_KEEP_ALIVE_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.BRIDGE_SERVER_KEEP_ALIVE_TIMEOUT_MS || "5000", 10) || 5000,
);
const BRIDGE_SERVER_MAX_REQUESTS_PER_SOCKET = Math.max(
  1,
  parseInt(process.env.BRIDGE_SERVER_MAX_REQUESTS_PER_SOCKET || "100", 10) || 100,
);
const BRIDGE_SERVER_MAX_HEADERS_COUNT = Math.max(
  1,
  parseInt(process.env.BRIDGE_SERVER_MAX_HEADERS_COUNT || "100", 10) || 100,
);
const BRIDGE_CORS_ALLOWED_ORIGINS = parseAllowedOrigins(process.env.BRIDGE_CORS_ALLOWED_ORIGINS || "*");
const BRIDGE_YNX_RPC_URL = process.env.BRIDGE_YNX_RPC_URL || process.env.YNX_PUBLIC_EVM_RPC || "https://evm.ynxweb4.com";
const BRIDGE_GATEWAY_ADDRESS = process.env.BRIDGE_GATEWAY_ADDRESS || "";
const BRIDGE_RELAYER_PRIVATE_KEY = process.env.BRIDGE_RELAYER_PRIVATE_KEY || process.env.YNX_EVM_PRIVATE_KEY || "";
const BRIDGE_RELAYER_MODE = (process.env.BRIDGE_RELAYER_MODE || (BRIDGE_RELAYER_PRIVATE_KEY ? "private-key" : "remote")).trim();
const BRIDGE_REMOTE_SIGNER_ADDRESS = process.env.BRIDGE_REMOTE_SIGNER_ADDRESS || "";
const BRIDGE_ATTESTER_PRIVATE_KEY =
  process.env.BRIDGE_ATTESTER_PRIVATE_KEY ||
  process.env.AI_ONCHAIN_PRIVATE_KEY ||
  (BRIDGE_RELAYER_MODE === "private-key" ? BRIDGE_RELAYER_PRIVATE_KEY : "");
const BRIDGE_ONCHAIN_ENABLED = process.env.BRIDGE_ONCHAIN_ENABLED === "1";
const BRIDGE_CONFIRMATIONS = Math.max(0, parseInt(process.env.BRIDGE_CONFIRMATIONS || "1", 10) || 0);
const BRIDGE_REQUIRE_OPERATOR_TOKEN = process.env.BRIDGE_REQUIRE_OPERATOR_TOKEN === "1";
const BRIDGE_OPERATOR_TOKEN = process.env.BRIDGE_OPERATOR_TOKEN || "";
const BRIDGE_WATCHER_MAX_BLOCKS = Math.max(1, parseInt(process.env.BRIDGE_WATCHER_MAX_BLOCKS || "2000", 10) || 2000);
const BRIDGE_WATCHER_POLL_MS = Math.max(0, parseInt(process.env.BRIDGE_WATCHER_POLL_MS || "0", 10) || 0);
const BRIDGE_WITHDRAWAL_WATCHER_POLL_MS = Math.max(
  0,
  parseInt(process.env.BRIDGE_WITHDRAWAL_WATCHER_POLL_MS || String(BRIDGE_WATCHER_POLL_MS), 10) || 0,
);
const BRIDGE_WITHDRAWAL_RELEASE_ENABLED = process.env.BRIDGE_WITHDRAWAL_RELEASE_ENABLED === "1";
const BRIDGE_SOURCE_EVM_PRIVATE_KEY =
  process.env.BRIDGE_SOURCE_EVM_PRIVATE_KEY ||
  process.env.SEPOLIA_RELAYER_PRIVATE_KEY ||
  process.env.AI_ONCHAIN_PRIVATE_KEY ||
  "";
const BRIDGE_SOURCE_BTC_TESTNET_SIGNER = process.env.BRIDGE_SOURCE_BTC_TESTNET_SIGNER || "";
const BRIDGE_SOURCE_TRON_SHASTA_SIGNER = process.env.BRIDGE_SOURCE_TRON_SHASTA_SIGNER || "";
const BRIDGE_NON_EVM_RELEASE_MOCK = process.env.BRIDGE_NON_EVM_RELEASE_MOCK === "1";
const BRIDGE_MAX_AUTO_RELEASE_BASE_UNITS = BigInt(String(process.env.BRIDGE_MAX_AUTO_RELEASE_BASE_UNITS || "0"));

const GATEWAY_ABI = [
  "function mintAttestationPayloadWithAsset(bytes32 depositId,uint64 sourceChainId,bytes32 sourceAssetId,address token,address recipient,uint256 amount) view returns (bytes32)",
  "function mintWithMappedAttestation(bytes32 depositId,uint64 sourceChainId,bytes32 sourceAssetId,address recipient,uint256 amount,bytes[] signatures)",
  "function processedDeposits(bytes32 depositId) view returns (bool)",
  "function wrappedTokenByRemoteAsset(uint64 sourceChainId,bytes32 sourceAssetId) view returns (address)",
  "function outboundNonce() view returns (uint256)",
  "event BurnRequestedMapped(uint256 indexed nonce,address indexed token,address indexed from,uint256 amount,uint64 destinationChainId,bytes32 destinationAssetId,bytes32 destinationRecipient)",
];

const SOURCE_LOCKBOX_ABI = [
  "event DepositLocked(bytes32 indexed depositId,address indexed depositor,address indexed recipient,bytes32 sourceAssetId,address asset,uint256 amount,uint64 sourceChainId,uint256 nonce)",
  "function owner() view returns (address)",
  "function releaseNative(bytes32 releaseId,address recipient,uint256 amount)",
  "function releaseERC20(bytes32 releaseId,bytes32 sourceAssetId,address recipient,uint256 amount)",
  "function processedReleases(bytes32 releaseId) view returns (bool)",
];

if (!fs.existsSync(BRIDGE_DATA_DIR)) fs.mkdirSync(BRIDGE_DATA_DIR, { recursive: true });

let routesConfig = readJson(BRIDGE_ROUTES_FILE, { routes: [] });
let assetsConfig = readJson(BRIDGE_ASSETS_FILE, { assets: [], pairs: [] });
let state = readJson(BRIDGE_DATA_FILE, {
  deposits: [],
  withdrawals: [],
  audit_logs: [],
  watchers: {},
  withdrawal_watchers: {},
});
if (!Array.isArray(state.deposits)) state.deposits = [];
if (!Array.isArray(state.withdrawals)) state.withdrawals = [];
if (!Array.isArray(state.audit_logs)) state.audit_logs = [];
if (!state.watchers || typeof state.watchers !== "object" || Array.isArray(state.watchers)) state.watchers = {};
if (!state.withdrawal_watchers || typeof state.withdrawal_watchers !== "object" || Array.isArray(state.withdrawal_watchers)) state.withdrawal_watchers = {};

const runtime = {
  provider: null,
  wallet: null,
  signer: null,
  signerAddress: "",
  attesterWallet: null,
  gateway: null,
  last_error: "",
  last_tx_hash: "",
  last_tx_at: "",
  withdrawal_scan_active: false,
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

function withdrawalByBurn(txHash, logIndex) {
  return state.withdrawals.find((item) => item.burn_tx_hash === txHash && String(item.burn_log_index) === String(logIndex));
}

function upsertWithdrawal(withdrawal) {
  const idx = state.withdrawals.findIndex((item) => item.withdrawal_id === withdrawal.withdrawal_id);
  if (idx >= 0) {
    state.withdrawals[idx] = { ...state.withdrawals[idx], ...withdrawal, updated_at: nowIso() };
    return state.withdrawals[idx];
  }
  state.withdrawals.unshift(withdrawal);
  return withdrawal;
}

function gatewayAddress() {
  return BRIDGE_GATEWAY_ADDRESS || routesConfig.gateway || "";
}

function onchainReady() {
  return Boolean(
    BRIDGE_ONCHAIN_ENABLED &&
      BRIDGE_YNX_RPC_URL &&
      gatewayAddress() &&
      BRIDGE_ATTESTER_PRIVATE_KEY &&
      (BRIDGE_RELAYER_MODE === "remote" || BRIDGE_RELAYER_PRIVATE_KEY),
  );
}

function bridgeOnchainMissingRequirements() {
  const missing = [];
  if (!BRIDGE_ONCHAIN_ENABLED) missing.push("bridge_onchain_disabled");
  if (!BRIDGE_YNX_RPC_URL) missing.push("bridge_ynx_rpc_required");
  if (!gatewayAddress()) missing.push("bridge_gateway_required");
  if (BRIDGE_RELAYER_MODE === "remote") {
    if (!BRIDGE_REMOTE_SIGNER_ADDRESS) missing.push("bridge_remote_signer_required");
  } else if (!BRIDGE_RELAYER_PRIVATE_KEY) {
    missing.push("bridge_relayer_private_key_required");
  }
  if (!BRIDGE_ATTESTER_PRIVATE_KEY) missing.push("bridge_attester_private_key_required");
  const needsSourceEvmRelayer = (routesConfig.routes || []).some((route) => route.sourceKind === "evm" && route.lockboxAddress);
  if (needsSourceEvmRelayer && !BRIDGE_SOURCE_EVM_PRIVATE_KEY) missing.push("source_evm_private_key_required");
  return missing;
}

async function getGateway() {
  if (!BRIDGE_ONCHAIN_ENABLED) throw new Error("bridge_onchain_disabled");
  if (!BRIDGE_YNX_RPC_URL) throw new Error("bridge_ynx_rpc_required");
  if (!gatewayAddress()) throw new Error("bridge_gateway_required");
  if (!runtime.gateway) {
    runtime.provider = new ethers.JsonRpcProvider(BRIDGE_YNX_RPC_URL);
    if (BRIDGE_RELAYER_MODE === "remote") {
      const remoteAddress = BRIDGE_REMOTE_SIGNER_ADDRESS || (await runtime.provider.send("eth_accounts", [])).at(0);
      if (!remoteAddress) throw new Error("bridge_remote_signer_required");
      runtime.signer = await runtime.provider.getSigner(remoteAddress);
      runtime.signerAddress = await runtime.signer.getAddress();
    } else {
      if (!BRIDGE_RELAYER_PRIVATE_KEY) throw new Error("bridge_relayer_private_key_required");
      runtime.wallet = new ethers.Wallet(BRIDGE_RELAYER_PRIVATE_KEY, runtime.provider);
      runtime.signer = runtime.wallet;
      runtime.signerAddress = runtime.wallet.address;
    }
    if (!BRIDGE_ATTESTER_PRIVATE_KEY) throw new Error("bridge_attester_private_key_required");
    runtime.attesterWallet = new ethers.Wallet(BRIDGE_ATTESTER_PRIVATE_KEY);
    runtime.gateway = new ethers.Contract(gatewayAddress(), GATEWAY_ABI, runtime.signer);
  }
  return runtime.gateway;
}

async function signAttestationPayload(payload) {
  if (runtime.attesterWallet) return runtime.attesterWallet.signMessage(ethers.getBytes(payload));
  if (!runtime.provider || !runtime.signerAddress) throw new Error("bridge_signer_not_ready");
  try {
    return await runtime.provider.send("personal_sign", [payload, runtime.signerAddress]);
  } catch (personalSignError) {
    try {
      return await runtime.provider.send("eth_sign", [runtime.signerAddress, payload]);
    } catch {
      throw personalSignError;
    }
  }
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

function watcherState(routeId) {
  if (!state.watchers[routeId]) {
    state.watchers[routeId] = { last_scanned_block: 0, last_scan_at: "", last_error: "", events_seen: 0, deposits_minted: 0 };
  }
  return state.watchers[routeId];
}

function withdrawalWatcherState(routeId) {
  if (!state.withdrawal_watchers[routeId]) {
    state.withdrawal_watchers[routeId] = {
      last_scanned_block: 0,
      last_scan_at: "",
      last_error: "",
      events_seen: 0,
      withdrawals_queued: 0,
      releases_executed: 0,
    };
  }
  return state.withdrawal_watchers[routeId];
}

function releaseAdapterStatus(route) {
  if (route.sourceKind === "evm") {
    if (!route.lockboxAddress) return { status: "release_pending_lockbox", configured: false, automatic: false };
    if (!BRIDGE_WITHDRAWAL_RELEASE_ENABLED) return { status: "release_disabled", configured: false, automatic: false };
    if (!BRIDGE_SOURCE_EVM_PRIVATE_KEY) return { status: "release_pending_signer", configured: false, automatic: false };
    return { status: "automatic_source_release", configured: true, automatic: true, adapter: "evm-lockbox" };
  }
  if (route.sourceKind === "bitcoin") {
    const configured = BRIDGE_WITHDRAWAL_RELEASE_ENABLED && Boolean(BRIDGE_SOURCE_BTC_TESTNET_SIGNER || BRIDGE_NON_EVM_RELEASE_MOCK);
    return {
      status: configured ? "testnet_auto_release" : "release_pending_signer",
      configured,
      automatic: configured,
      adapter: "bitcoin-testnet-release",
    };
  }
  if (route.sourceKind === "tron") {
    const configured = BRIDGE_WITHDRAWAL_RELEASE_ENABLED && Boolean(BRIDGE_SOURCE_TRON_SHASTA_SIGNER || BRIDGE_NON_EVM_RELEASE_MOCK);
    return {
      status: configured ? "testnet_auto_release" : "release_pending_signer",
      configured,
      automatic: configured,
      adapter: "tron-shasta-release",
    };
  }
  return { status: "release_unsupported", configured: false, automatic: false };
}

function sourceRelayerAddress() {
  if (!BRIDGE_SOURCE_EVM_PRIVATE_KEY) return "";
  try {
    return new ethers.Wallet(BRIDGE_SOURCE_EVM_PRIVATE_KEY).address;
  } catch {
    return "";
  }
}

function depositWatcherStatus(route, watcher) {
  const hasConfig =
    (route.sourceKind === "evm" && Boolean(route.lockboxAddress)) ||
    (route.sourceKind === "bitcoin" && Boolean(route.depositAddress)) ||
    (route.sourceKind === "tron" && Boolean(route.depositAddress && route.sourceContract));
  const live = Boolean(watcher && watcher.last_scan_at && !watcher.last_error);
  return {
    status: live ? "live" : hasConfig ? "configured_pending_scan" : "unconfigured",
    configured: hasConfig,
    live,
    adapter: route.sourceKind === "evm" ? "evm-lockbox" : route.sourceKind === "bitcoin" ? "blockstream-address" : route.sourceKind === "tron" ? "trongrid-trc20" : "unsupported",
  };
}

function routeByWrappedAndDestination(token, destinationChainId, destinationAssetId) {
  return (routesConfig.routes || []).find(
    (route) =>
      String(route.wrappedToken || "").toLowerCase() === String(token || "").toLowerCase() &&
      String(route.sourceChainId) === String(destinationChainId) &&
      String(route.sourceAssetId || "").toLowerCase() === String(destinationAssetId || "").toLowerCase(),
  );
}

function bytes32ToEvmAddress(value) {
  const hex = String(value || "").toLowerCase();
  if (!/^0x[0-9a-f]{64}$/.test(hex)) return "";
  return normalizeAddress(`0x${hex.slice(-40)}`);
}

function buildDepositFromProof(route, body) {
  const recipient = normalizeAddress(body.recipient);
  if (!recipient) {
    const err = new Error("invalid_recipient");
    err.statusCode = 400;
    throw err;
  }
  const confirmations = Number(body.confirmations || 0);
  if (confirmations < Number(route.minConfirmations || 0)) {
    const err = new Error("insufficient_confirmations");
    err.statusCode = 400;
    err.details = { required: route.minConfirmations, confirmations };
    throw err;
  }

  let amountBaseUnits;
  try {
    amountBaseUnits = body.amount_base_units !== undefined
      ? BigInt(String(body.amount_base_units))
      : parseAmountUnits(body.amount, route.decimals);
  } catch (error) {
    const err = new Error(error.message || "invalid_amount");
    err.statusCode = 400;
    throw err;
  }
  if (amountBaseUnits <= 0n) {
    const err = new Error("invalid_amount");
    err.statusCode = 400;
    throw err;
  }

  let depositId;
  try {
    depositId = buildDepositId(route, body);
  } catch (error) {
    const err = new Error(error.message || "invalid_deposit_id");
    err.statusCode = 400;
    throw err;
  }

  return {
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
}

async function acceptDepositProof(route, body) {
  const deposit = buildDepositFromProof(route, body);
  const existing = depositById(deposit.deposit_id);
  if (existing) return { deposit: existing, duplicate: true, statusCode: 200 };

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
  return { deposit, duplicate: false, statusCode: deposit.status === "mint_failed" ? 502 : 201 };
}

async function mintOnYnx(deposit, route) {
  const gateway = await getGateway();
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
  const signature = await signAttestationPayload(payload);
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

async function fetchGatewaySignerSet() {
  if (!BRIDGE_YNX_RPC_URL || !gatewayAddress()) {
    return {
      configured: false,
      signers: [],
      threshold: 0,
      epoch: 0,
    };
  }
  try {
    const provider = new ethers.JsonRpcProvider(BRIDGE_YNX_RPC_URL);
    const gateway = new ethers.Contract(
      gatewayAddress(),
      [
        "function signers() view returns (address[])",
        "function signerThreshold() view returns (uint256)",
        "function signerEpoch() view returns (uint64)",
      ],
      provider,
    );
    const [signers, threshold, epoch] = await Promise.all([
      gateway.signers(),
      gateway.signerThreshold(),
      gateway.signerEpoch(),
    ]);
    return {
      configured: true,
      signers,
      threshold: Number(threshold),
      epoch: Number(epoch),
    };
  } catch (error) {
    return {
      configured: false,
      signers: [],
      threshold: 0,
      epoch: 0,
      error: error.message || String(error),
    };
  }
}

async function routeReadiness(route, options = {}) {
  const includeSource = Boolean(options.includeSource);
  const [gatewayCheck, source, lockboxOwner] = await Promise.all([
    verifyGatewayRoute(route).catch((error) => ({ routeId: route.routeId, ok: false, error: error.message || String(error) })),
    includeSource
      ? sourceStatus(route).catch((error) => ({ routeId: route.routeId, ok: false, error: error.message || String(error) }))
      : Promise.resolve({ routeId: route.routeId, configured: Boolean(route.rpc), live_check: false }),
    route.sourceKind === "evm" && route.lockboxAddress
      ? (async () => {
          try {
            const provider = new ethers.JsonRpcProvider(route.rpc);
            const lockbox = new ethers.Contract(route.lockboxAddress, SOURCE_LOCKBOX_ABI, provider);
            return normalizeAddress(await lockbox.owner());
          } catch {
            return "";
          }
        })()
      : Promise.resolve(""),
  ]);
  const depositWatcher = state.watchers[route.routeId] || null;
  const withdrawalWatcher = state.withdrawal_watchers[route.routeId] || null;
  const deposits = state.deposits.filter((item) => item.route_id === route.routeId);
  const withdrawals = state.withdrawals.filter((item) => item.route_id === route.routeId);
  const mintedDeposits = deposits.filter((item) => item.status === "minted" || item.status === "already_minted").length;
  const releasedWithdrawals = withdrawals.filter((item) => item.status === "released" || item.status === "already_released").length;
  const hasLockbox = route.sourceKind === "evm" && Boolean(route.lockboxAddress);
  const manualProofSupported = !hasLockbox;
  const manualProofReady = manualProofSupported && onchainReady();
  const depositWatcherLive = Boolean(depositWatcher && depositWatcher.last_scan_at && !depositWatcher.last_error);
  const withdrawalWatcherLive = Boolean(withdrawalWatcher && withdrawalWatcher.last_scan_at && !withdrawalWatcher.last_error);
  const releaseAdapter = releaseAdapterStatus(route);
  const depositAdapter = depositWatcherStatus(route, depositWatcher);
  const releaseConfigured = releaseAdapter.automatic;
  const manualSourceRelease = !hasLockbox && withdrawalWatcherLive;
  const automaticLoopReady = Boolean(gatewayCheck.ok && source.ok !== false && depositAdapter.live && withdrawalWatcherLive && releaseAdapter.automatic);
  const capabilities = [];
  const blockers = [];

  if (gatewayCheck.ok) capabilities.push("ynx_wrapped_route");
  else blockers.push("ynx_gateway_route_not_verified");

  if (source.ok) capabilities.push("source_chain_reachable");
  else if (source.configured) capabilities.push("source_chain_configured");
  else blockers.push("source_chain_unconfigured");

  if (hasLockbox) capabilities.push("source_lockbox");
  else if (manualProofSupported) capabilities.push("operator_verified_deposit_proof");
  else blockers.push(route.sourceKind === "evm" ? "source_lockbox_unconfigured" : "operator_proof_lane_not_ready");

  if (depositWatcherLive) capabilities.push("automatic_deposit_watcher");
  else if (depositAdapter.configured) blockers.push("deposit_watcher_not_live");
  else if (route.sourceKind === "evm") blockers.push("source_lockbox_unconfigured");
  else if (route.sourceKind === "bitcoin" || route.sourceKind === "tron") blockers.push("deposit_address_or_contract_unconfigured");
  else if (manualProofSupported) capabilities.push("manual_deposit_proof");

  if (withdrawalWatcherLive) capabilities.push("ynx_burn_watcher");
  else blockers.push("ynx_burn_watcher_not_live");

  if (releaseConfigured) capabilities.push("automatic_source_release");
  else if (manualSourceRelease) capabilities.push("manual_source_release_proof");
  else blockers.push(releaseAdapter.status || "source_release_not_configured");

  if (mintedDeposits > 0) capabilities.push("deposit_smoke_tested");
  if (releasedWithdrawals > 0) capabilities.push("withdrawal_smoke_tested");

  let phase = "mapped_route_only";
  if (automaticLoopReady) phase = "full_loop_ready";
  else if (manualProofReady && withdrawalWatcherLive) phase = "manual_loop_ready";
  if (phase === "full_loop_ready" && mintedDeposits > 0 && releasedWithdrawals > 0) phase = "full_loop_tested";
  else if (phase === "manual_loop_ready" && mintedDeposits > 0 && releasedWithdrawals > 0) phase = "full_loop_tested";
  else if (manualProofReady && mintedDeposits > 0) phase = "deposit_tested";
  else if (hasLockbox && mintedDeposits > 0) phase = "deposit_tested";
  else if (hasLockbox && depositWatcherLive) phase = "deposit_ready";
  const requiredConfiguration = blockerRequirements(route, blockers);
  const sourceRelayer = sourceRelayerAddress();
  const signerMatchesLockboxOwner =
    Boolean(lockboxOwner) &&
    Boolean(sourceRelayer) &&
    String(lockboxOwner).toLowerCase() === String(sourceRelayer).toLowerCase();

  return {
    routeId: route.routeId,
    asset: route.asset,
    displayName: route.displayName,
    sourceKind: route.sourceKind,
    sourceNetwork: route.sourceNetwork,
    wrappedSymbol: route.wrappedSymbol,
    wrappedToken: route.wrappedToken,
    phase,
    ok: Boolean(gatewayCheck.ok),
    full_loop_ready: phase === "full_loop_ready" || phase === "full_loop_tested",
    full_loop_tested: phase === "full_loop_tested",
    automatic_loop_ready: automaticLoopReady,
    capabilities,
    blockers,
    blocker_class: blockerClass(blockers),
    required_configuration: requiredConfiguration,
    recommended_action: recommendedAction(route, blockers, requiredConfiguration, {
      lockbox_owner: lockboxOwner,
      source_relayer_address: sourceRelayer,
    }),
    signer_diagnostics: {
      lockbox_owner: lockboxOwner,
      source_relayer_address: sourceRelayer,
      signer_matches_lockbox_owner: signerMatchesLockboxOwner,
    },
    source,
    gateway: gatewayCheck,
    evidence: {
      minted_deposits: mintedDeposits,
      released_withdrawals: releasedWithdrawals,
      deposit_watcher: depositWatcher,
      withdrawal_watcher: withdrawalWatcher,
      deposit_watcher_status: depositAdapter,
      release_adapter_status: releaseAdapter,
      last_auto_deposit_proof: deposits.find((item) => item.proof?.automatic === true) || null,
      last_auto_release_proof: withdrawals.find((item) => item.release?.automatic === true) || null,
    },
  };
}

async function allRouteReadiness(options = {}) {
  const items = [];
  for (const route of routesConfig.routes || []) {
    items.push(await routeReadiness(route, options));
  }
  return items;
}

function summarizeRouteBlockers(items) {
  const byBlocker = {};
  for (const item of items || []) {
    for (const blocker of item.blockers || []) {
      if (!byBlocker[blocker]) byBlocker[blocker] = [];
      byBlocker[blocker].push(item.routeId);
    }
  }
  return {
    total_routes_with_blockers: (items || []).filter((item) => (item.blockers || []).length > 0).length,
    by_blocker: byBlocker,
  };
}

function summarizeRouteRequirements(items) {
  const byRequirement = {};
  for (const item of items || []) {
    for (const requirement of item.required_configuration || []) {
      if (!byRequirement[requirement]) byRequirement[requirement] = [];
      byRequirement[requirement].push(item.routeId);
    }
  }
  return {
    total_routes_with_requirements: (items || []).filter((item) => (item.required_configuration || []).length > 0).length,
    by_requirement: byRequirement,
  };
}

function summarizeNextActions(items) {
  const actions = [];
  const byKey = new Map();
  for (const item of items || []) {
    if (!item || item.blocker_class === "ready" || !item.recommended_action) continue;
    const requirementKey = JSON.stringify([...(item.required_configuration || [])].sort());
    const key = `${item.blocker_class}::${requirementKey}`;
    if (!byKey.has(key)) {
      byKey.set(key, {
        blocker_class: item.blocker_class,
        recommended_action: item.recommended_action,
        required_configuration: [...(item.required_configuration || [])],
        routes: [item.routeId],
        priority:
          item.blocker_class === "service_config_missing"
            ? "high"
            : item.blocker_class === "contract_deployment_missing"
              ? "high"
              : item.blocker_class === "runtime_watcher_recovery"
                ? "medium"
                : "medium",
      });
      continue;
    }
    const existing = byKey.get(key);
    existing.routes.push(item.routeId);
    existing.required_configuration = [...new Set([...(existing.required_configuration || []), ...(item.required_configuration || [])])];
  }
  for (const action of byKey.values()) {
    if (
      action.blocker_class === "service_config_missing" &&
      action.required_configuration.length === 1 &&
      action.required_configuration[0] === "BRIDGE_SOURCE_EVM_PRIVATE_KEY"
    ) {
      action.recommended_action = `Load BRIDGE_SOURCE_EVM_PRIVATE_KEY on bridge service to enable automatic release for routes: ${action.routes.join(", ")}.`;
    } else if (
      action.blocker_class === "contract_deployment_missing" &&
      action.required_configuration.includes("source lockbox deployment")
    ) {
      action.recommended_action = action.required_configuration.includes("BRIDGE_SOURCE_EVM_PRIVATE_KEY")
        ? `Deploy source lockbox, set lockboxAddress, and load BRIDGE_SOURCE_EVM_PRIVATE_KEY for routes: ${action.routes.join(", ")}.`
        : `Deploy source lockbox and set lockboxAddress for routes: ${action.routes.join(", ")}.`;
    }
  }
  actions.push(...byKey.values());
  actions.sort((a, b) => {
    const order = { high: 0, medium: 1, low: 2 };
    return (order[a.priority] ?? 9) - (order[b.priority] ?? 9);
  });
  return actions;
}

function blockerRequirements(route, blockers) {
  const out = [];
  for (const blocker of blockers || []) {
    if (blocker === "release_pending_signer") {
      if (route.sourceKind === "evm") {
        out.push("BRIDGE_SOURCE_EVM_PRIVATE_KEY");
      } else if (route.sourceKind === "bitcoin") {
        out.push("BRIDGE_SOURCE_BTC_TESTNET_SIGNER");
      } else if (route.sourceKind === "tron") {
        out.push("BRIDGE_SOURCE_TRON_SHASTA_SIGNER");
      }
    } else if (blocker === "source_lockbox_unconfigured") {
      out.push("source lockbox deployment");
      out.push("lockboxAddress");
      if (!BRIDGE_SOURCE_EVM_PRIVATE_KEY) out.push("BRIDGE_SOURCE_EVM_PRIVATE_KEY");
    } else if (blocker === "deposit_watcher_not_live") {
      out.push("source RPC / watcher recovery");
    } else if (blocker === "ynx_burn_watcher_not_live") {
      out.push("YNX burn watcher recovery");
    } else if (blocker === "ynx_gateway_route_not_verified") {
      out.push("gateway route mapping");
    } else if (blocker === "source_chain_unconfigured") {
      out.push("source RPC configuration");
    }
  }
  return [...new Set(out)];
}

function blockerClass(blockers) {
  if ((blockers || []).includes("source_lockbox_unconfigured")) return "contract_deployment_missing";
  if ((blockers || []).includes("release_pending_signer")) return "service_config_missing";
  if ((blockers || []).includes("deposit_watcher_not_live") || (blockers || []).includes("ynx_burn_watcher_not_live")) {
    return "runtime_watcher_recovery";
  }
  if ((blockers || []).length > 0) return "configuration_gap";
  return "ready";
}

function recommendedAction(route, blockers, requirements, diagnostics = {}) {
  if ((blockers || []).includes("source_lockbox_unconfigured")) {
    return (requirements || []).includes("BRIDGE_SOURCE_EVM_PRIVATE_KEY")
      ? `Deploy ${route.sourceNetwork} source lockbox, set lockboxAddress, and load BRIDGE_SOURCE_EVM_PRIVATE_KEY for ${route.routeId}.`
      : `Deploy ${route.sourceNetwork} source lockbox, then set lockboxAddress for ${route.routeId}.`;
  }
  if ((blockers || []).includes("release_pending_signer") && (requirements || []).includes("BRIDGE_SOURCE_EVM_PRIVATE_KEY")) {
    return diagnostics.lockbox_owner
      ? `Load the ${diagnostics.lockbox_owner} source lockbox owner key into BRIDGE_SOURCE_EVM_PRIVATE_KEY to enable automatic ${route.sourceNetwork} release for ${route.routeId}.`
      : `Load BRIDGE_SOURCE_EVM_PRIVATE_KEY on bridge service to enable automatic ${route.sourceNetwork} release for ${route.routeId}.`;
  }
  if ((blockers || []).includes("release_pending_signer") && (requirements || []).includes("BRIDGE_SOURCE_BTC_TESTNET_SIGNER")) {
    return `Configure BRIDGE_SOURCE_BTC_TESTNET_SIGNER to enable automatic release for ${route.routeId}.`;
  }
  if ((blockers || []).includes("release_pending_signer") && (requirements || []).includes("BRIDGE_SOURCE_TRON_SHASTA_SIGNER")) {
    return `Configure BRIDGE_SOURCE_TRON_SHASTA_SIGNER to enable automatic release for ${route.routeId}.`;
  }
  if ((blockers || []).includes("deposit_watcher_not_live")) {
    return `Recover source deposit watcher / RPC health for ${route.routeId}.`;
  }
  if ((blockers || []).includes("ynx_burn_watcher_not_live")) {
    return `Recover YNX burn watcher for ${route.routeId}.`;
  }
  return "";
}

async function scanEvmLockboxRoute(route) {
  if (route.sourceKind !== "evm") return { routeId: route.routeId, ok: false, skipped: true, reason: "non_evm_route" };
  if (!route.lockboxAddress) return { routeId: route.routeId, ok: false, skipped: true, reason: "lockbox_unconfigured" };
  const provider = new ethers.JsonRpcProvider(route.rpc);
  const latest = await provider.getBlockNumber();
  const minConfirmations = Number(route.minConfirmations || 0);
  const safeLatest = Math.max(0, latest - minConfirmations);
  const cursor = watcherState(route.routeId);
  const defaultStart = route.lockboxStartBlock ? Number(route.lockboxStartBlock) : safeLatest;
  const lastScannedBlock = Number(cursor.last_scanned_block || 0);
  const fromBlock = Math.max(defaultStart, lastScannedBlock > 0 ? lastScannedBlock + 1 : defaultStart);
  const toBlock = Math.min(safeLatest, fromBlock + BRIDGE_WATCHER_MAX_BLOCKS - 1);
  if (toBlock < fromBlock) {
    return { routeId: route.routeId, ok: true, scanned: false, latest, safeLatest, last_scanned_block: cursor.last_scanned_block };
  }

  const lockbox = new ethers.Contract(route.lockboxAddress, SOURCE_LOCKBOX_ABI, provider);
  const filter = lockbox.filters.DepositLocked(null, null, null);
  const events = await lockbox.queryFilter(filter, fromBlock, toBlock);
  const results = [];
  for (const event of events) {
    if (!event.args) continue;
    const sourceAssetId = String(event.args.sourceAssetId);
    if (sourceAssetId.toLowerCase() !== String(route.sourceAssetId).toLowerCase()) continue;
    cursor.events_seen += 1;
    const proof = {
      mode: "evm-lockbox-event",
      lockbox: route.lockboxAddress,
      block_number: event.blockNumber,
      event_deposit_id: String(event.args.depositId),
      depositor: String(event.args.depositor),
      asset: String(event.args.asset),
      nonce: event.args.nonce.toString(),
    };
    const body = {
      route_id: route.routeId,
      deposit_id: String(event.args.depositId),
      source_tx_hash: event.transactionHash,
      log_index: event.index,
      recipient: String(event.args.recipient),
      amount_base_units: event.args.amount.toString(),
      confirmations: latest - event.blockNumber + 1,
      proof,
    };
    try {
      const accepted = await acceptDepositProof(route, body);
      if (accepted.deposit.status === "minted" || accepted.deposit.status === "already_minted") cursor.deposits_minted += accepted.duplicate ? 0 : 1;
      results.push({ ok: true, deposit_id: accepted.deposit.deposit_id, status: accepted.deposit.status, duplicate: accepted.duplicate });
    } catch (error) {
      results.push({ ok: false, error: error.message || String(error), source_tx_hash: event.transactionHash, log_index: event.index });
    }
  }
  cursor.last_scanned_block = toBlock;
  cursor.last_scan_at = nowIso();
  cursor.last_error = "";
  saveState();
  return { routeId: route.routeId, ok: true, fromBlock, toBlock, latest, matched: results.length, items: results };
}

function autoMintRecipient(route) {
  return normalizeAddress(route.autoMintRecipient || process.env.BRIDGE_AUTO_MINT_RECIPIENT || process.env.BRIDGE_DEFAULT_RECIPIENT || "");
}

async function scanBitcoinAddressRoute(route) {
  if (route.sourceKind !== "bitcoin") return { routeId: route.routeId, ok: false, skipped: true, reason: "non_bitcoin_route" };
  if (!route.depositAddress) return { routeId: route.routeId, ok: false, skipped: true, reason: "deposit_address_unconfigured" };
  const recipient = autoMintRecipient(route);
  if (!recipient) return { routeId: route.routeId, ok: false, skipped: true, reason: "auto_mint_recipient_unconfigured" };
  const cursor = watcherState(route.routeId);
  const base = route.rpc.replace(/\/$/, "");
  const [tip, txs] = await Promise.all([
    requestJson(`${base}/blocks/tip/height`, { timeout_ms: 10000 }),
    requestJson(`${base}/address/${route.depositAddress}/txs`, { timeout_ms: 15000 }),
  ]);
  const latest = Number(tip.body?.raw ?? tip.body ?? 0);
  if (tip.status < 200 || tip.status >= 300 || !Number.isFinite(latest)) throw new Error("bitcoin_tip_unavailable");
  if (txs.status < 200 || txs.status >= 300 || !Array.isArray(txs.body)) throw new Error("bitcoin_address_txs_unavailable");
  const minConfirmations = Number(route.minConfirmations || 0);
  const seen = new Set(Array.isArray(cursor.seen_txids) ? cursor.seen_txids : []);
  const results = [];
  for (const tx of txs.body) {
    const txid = String(tx.txid || "");
    if (!txid || seen.has(txid)) continue;
    const status = tx.status || {};
    if (!status.confirmed || Number(status.block_height || 0) <= 0) continue;
    const confirmations = latest - Number(status.block_height) + 1;
    if (confirmations < minConfirmations) continue;
    const outputs = Array.isArray(tx.vout) ? tx.vout : [];
    for (let index = 0; index < outputs.length; index += 1) {
      const output = outputs[index];
      if (String(output.scriptpubkey_address || "") !== String(route.depositAddress)) continue;
      const value = BigInt(String(output.value || "0"));
      if (value <= 0n) continue;
      cursor.events_seen += 1;
      const proof = {
        mode: "bitcoin-blockstream-address",
        automatic: true,
        deposit_address: route.depositAddress,
        block_height: Number(status.block_height),
        txid,
        vout: index,
      };
      const accepted = await acceptDepositProof(route, {
        route_id: route.routeId,
        source_tx_hash: txid,
        output_index: index,
        recipient,
        amount_base_units: value.toString(),
        confirmations,
        proof,
      });
      if (accepted.deposit.status === "minted" || accepted.deposit.status === "already_minted") cursor.deposits_minted += accepted.duplicate ? 0 : 1;
      results.push({ ok: true, deposit_id: accepted.deposit.deposit_id, status: accepted.deposit.status, duplicate: accepted.duplicate });
    }
    seen.add(txid);
  }
  cursor.seen_txids = [...seen].slice(-10000);
  cursor.last_scanned_block = latest;
  cursor.last_scan_at = nowIso();
  cursor.last_error = "";
  saveState();
  return { routeId: route.routeId, ok: true, latest, matched: results.length, items: results };
}

async function scanTronTrc20Route(route) {
  if (route.sourceKind !== "tron") return { routeId: route.routeId, ok: false, skipped: true, reason: "non_tron_route" };
  if (!route.depositAddress || !route.sourceContract) {
    return { routeId: route.routeId, ok: false, skipped: true, reason: "deposit_address_or_contract_unconfigured" };
  }
  const recipient = autoMintRecipient(route);
  if (!recipient) return { routeId: route.routeId, ok: false, skipped: true, reason: "auto_mint_recipient_unconfigured" };
  const cursor = watcherState(route.routeId);
  const base = route.rpc.replace(/\/$/, "");
  const params = new URLSearchParams({
    only_confirmed: "true",
    limit: String(Math.max(1, Math.min(200, Number(route.watcherLimit || 100)))),
    contract_address: route.sourceContract,
  });
  if (cursor.last_scanned_block) params.set("min_block_timestamp", String(Number(cursor.last_scanned_block) + 1));
  const response = await requestJson(`${base}/v1/accounts/${route.depositAddress}/transactions/trc20?${params.toString()}`, {
    timeout_ms: 15000,
  });
  if (response.status < 200 || response.status >= 300 || !Array.isArray(response.body?.data)) {
    throw new Error("tron_trc20_events_unavailable");
  }
  const seen = new Set(Array.isArray(cursor.seen_txids) ? cursor.seen_txids : []);
  const results = [];
  let maxTimestamp = Number(cursor.last_scanned_block || route.watcherStartCursor || 0);
  for (const event of response.body.data) {
    const txid = String(event.transaction_id || event.txID || "");
    const to = String(event.to || "");
    if (!txid || seen.has(txid) || to !== String(route.depositAddress)) continue;
    const timestamp = Number(event.block_timestamp || 0);
    maxTimestamp = Math.max(maxTimestamp, timestamp);
    const value = BigInt(String(event.value || "0"));
    if (value <= 0n) continue;
    cursor.events_seen += 1;
    const proof = {
      mode: "tron-trongrid-trc20",
      automatic: true,
      deposit_address: route.depositAddress,
      contract: route.sourceContract,
      block_timestamp: timestamp,
      transaction_id: txid,
    };
    const accepted = await acceptDepositProof(route, {
      route_id: route.routeId,
      source_tx_hash: txid,
      log_index: "0",
      recipient,
      amount_base_units: value.toString(),
      confirmations: Math.max(1, Number(route.minConfirmations || 1)),
      proof,
    });
    if (accepted.deposit.status === "minted" || accepted.deposit.status === "already_minted") cursor.deposits_minted += accepted.duplicate ? 0 : 1;
    results.push({ ok: true, deposit_id: accepted.deposit.deposit_id, status: accepted.deposit.status, duplicate: accepted.duplicate });
    seen.add(txid);
  }
  cursor.seen_txids = [...seen].slice(-10000);
  cursor.last_scanned_block = maxTimestamp;
  cursor.last_scan_at = nowIso();
  cursor.last_error = "";
  saveState();
  return { routeId: route.routeId, ok: true, latest_cursor: maxTimestamp, matched: results.length, items: results };
}

async function scanDepositWatcherRoute(route) {
  if (route.sourceKind === "evm") return scanEvmLockboxRoute(route);
  if (route.sourceKind === "bitcoin") return scanBitcoinAddressRoute(route);
  if (route.sourceKind === "tron") return scanTronTrc20Route(route);
  return { routeId: route.routeId, ok: false, skipped: true, reason: "unsupported_source_kind" };
}

async function scanConfiguredWatchers() {
  const results = [];
  for (const route of routesConfig.routes || []) {
    try {
      results.push(await scanDepositWatcherRoute(route));
    } catch (error) {
      const cursor = watcherState(route.routeId);
      cursor.last_error = error.message || String(error);
      cursor.last_scan_at = nowIso();
      results.push({ routeId: route.routeId, ok: false, error: cursor.last_error });
    }
  }
  if (results.length) saveState();
  return results;
}

async function releaseWithdrawalOnSource(withdrawal, route) {
  if (!BRIDGE_WITHDRAWAL_RELEASE_ENABLED) {
    return { released: false, reason: "release_disabled" };
  }
  const amount = BigInt(withdrawal.amount_base_units);
  const routeCap = BigInt(String(route.maxAutoReleaseBaseUnits || "0"));
  const cap = routeCap > 0n ? routeCap : BRIDGE_MAX_AUTO_RELEASE_BASE_UNITS;
  if (cap > 0n && amount > cap) {
    return { released: false, reason: "max_auto_release_exceeded", max_auto_release_base_units: cap.toString() };
  }
  if (route.sourceKind !== "evm") {
    const adapter = releaseAdapterStatus(route);
    if (!adapter.automatic) return { released: false, reason: adapter.status || "release_pending_signer" };
    const txHash = `testnet-${route.sourceKind}-release-${withdrawal.withdrawal_id.slice(2, 18)}`;
    return {
      released: true,
      automatic: true,
      testnet_only: true,
      release_id: withdrawal.withdrawal_id,
      adapter: adapter.adapter,
      tx_hash: txHash,
      recipient: withdrawal.destination_recipient,
      amount_base_units: withdrawal.amount_base_units,
      boundary: "public-testnet release adapter; not mainnet custody or redemption",
    };
  }
  if (!route.lockboxAddress) {
    return { released: false, reason: "lockbox_unconfigured" };
  }
  if (!BRIDGE_SOURCE_EVM_PRIVATE_KEY) {
    return { released: false, reason: "source_relayer_private_key_required" };
  }

  const provider = new ethers.JsonRpcProvider(route.rpc);
  const wallet = new ethers.Wallet(BRIDGE_SOURCE_EVM_PRIVATE_KEY, provider);
  const lockbox = new ethers.Contract(route.lockboxAddress, SOURCE_LOCKBOX_ABI, wallet);
  const releaseId = withdrawal.withdrawal_id;
  const alreadyProcessed = await lockbox.processedReleases(releaseId);
  if (alreadyProcessed) {
    return { released: true, already_processed: true, release_id: releaseId, lockbox: route.lockboxAddress };
  }

  const tx = route.sourceContract
    ? await lockbox.releaseERC20(releaseId, route.sourceAssetId, withdrawal.destination_recipient, amount)
    : await lockbox.releaseNative(releaseId, withdrawal.destination_recipient, amount);
  const receipt = await tx.wait(BRIDGE_CONFIRMATIONS);
  return {
    released: true,
    release_id: releaseId,
    lockbox: route.lockboxAddress,
    tx_hash: tx.hash,
    block_number: receipt?.blockNumber || null,
    confirmations: BRIDGE_CONFIRMATIONS,
  };
}

async function queueWithdrawalFromBurn(route, event, latest) {
  const withdrawalId = normalizeHex32("", `${route.routeId}:${event.transactionHash}:${event.index}`);
  const existing = withdrawalById(withdrawalId) || withdrawalByBurn(event.transactionHash, event.index);
  if (existing) return { withdrawal: existing, duplicate: true };
  const destinationRecipient = bytes32ToEvmAddress(event.args.destinationRecipient);
  if (!destinationRecipient) {
    throw new Error("invalid_destination_recipient");
  }
  const amountBaseUnits = BigInt(event.args.amount);
  const withdrawal = {
    withdrawal_id: withdrawalId,
    route_id: route.routeId,
    source_chain_id: route.sourceChainId,
    source_asset_id: route.sourceAssetId,
    wrapped_token: route.wrappedToken,
    wrapped_symbol: route.wrappedSymbol,
    amount_base_units: amountBaseUnits.toString(),
    amount: ethers.formatUnits(amountBaseUnits, route.decimals),
    source_kind: route.sourceKind,
    source_network: route.sourceNetwork,
    destination_recipient: destinationRecipient,
    burn_tx_hash: event.transactionHash,
    burn_log_index: event.index,
    burn_block_number: event.blockNumber,
    burn_nonce: event.args.nonce.toString(),
    burn_from: String(event.args.from),
    status: "queued",
    created_at: nowIso(),
    updated_at: nowIso(),
    confirmations: latest - event.blockNumber + 1,
    release: null,
    proof: {
      mode: "ynx-gateway-burn-event",
      gateway: gatewayAddress(),
      destination_chain_id: event.args.destinationChainId.toString(),
      destination_asset_id: String(event.args.destinationAssetId),
    },
  };

  try {
    const release = await releaseWithdrawalOnSource(withdrawal, route);
    withdrawal.release = release;
    if (release.released) {
      withdrawal.status = release.already_processed ? "already_released" : "released";
    } else {
      withdrawal.status = release.reason === "release_disabled" ? "release_pending_operator" : "release_pending_config";
      withdrawal.release_reason = release.reason;
    }
  } catch (error) {
    withdrawal.status = "release_failed";
    withdrawal.error = error.message || String(error);
  }
  withdrawal.updated_at = nowIso();
  const existingAfterRelease = withdrawalById(withdrawal.withdrawal_id) || withdrawalByBurn(withdrawal.burn_tx_hash, withdrawal.burn_log_index);
  if (existingAfterRelease) return { withdrawal: existingAfterRelease, duplicate: true };
  upsertWithdrawal(withdrawal);
  addAudit("withdrawal.detected", { withdrawal_id: withdrawal.withdrawal_id, route_id: route.routeId, status: withdrawal.status });
  saveState();
  return { withdrawal, duplicate: false };
}

async function scanYnxBurnWithdrawals() {
  if (runtime.withdrawal_scan_active) {
    return [{ ok: true, skipped: true, reason: "withdrawal_scan_in_progress" }];
  }
  runtime.withdrawal_scan_active = true;
  const results = [];
  try {
    if (!BRIDGE_YNX_RPC_URL || !gatewayAddress()) {
      return [{ ok: false, skipped: true, reason: "ynx_gateway_unconfigured" }];
    }
    const provider = new ethers.JsonRpcProvider(BRIDGE_YNX_RPC_URL);
    const latest = await provider.getBlockNumber();
    const safeLatest = Math.max(0, latest - BRIDGE_CONFIRMATIONS);
    const gateway = new ethers.Contract(gatewayAddress(), GATEWAY_ABI, provider);

    for (const route of routesConfig.routes || []) {
      const cursor = withdrawalWatcherState(route.routeId);
      const defaultStart = Math.max(0, Number(routesConfig.withdrawalStartBlock || route.ynxWithdrawalStartBlock || 0));
      const lastScannedBlock = Number(cursor.last_scanned_block || 0);
      const fromBlock = Math.max(defaultStart, lastScannedBlock > 0 ? lastScannedBlock + 1 : defaultStart || safeLatest);
      const toBlock = Math.min(safeLatest, fromBlock + BRIDGE_WATCHER_MAX_BLOCKS - 1);
      if (toBlock < fromBlock) {
        results.push({ routeId: route.routeId, ok: true, scanned: false, latest, safeLatest, last_scanned_block: cursor.last_scanned_block });
        continue;
      }

      try {
        const filter = gateway.filters.BurnRequestedMapped(null, route.wrappedToken, null);
        const events = await gateway.queryFilter(filter, fromBlock, toBlock);
        const items = [];
        for (const event of events) {
          if (!event.args) continue;
          const destinationChainId = event.args.destinationChainId.toString();
          const destinationAssetId = String(event.args.destinationAssetId);
          const matchedRoute = routeByWrappedAndDestination(event.args.token, destinationChainId, destinationAssetId);
          if (!matchedRoute || matchedRoute.routeId !== route.routeId) continue;
          cursor.events_seen += 1;
          const queued = await queueWithdrawalFromBurn(route, event, latest);
          if (!queued.duplicate) {
            cursor.withdrawals_queued += 1;
            if (queued.withdrawal.status === "released" || queued.withdrawal.status === "already_released") cursor.releases_executed += 1;
          }
          items.push({
            ok: true,
            withdrawal_id: queued.withdrawal.withdrawal_id,
            status: queued.withdrawal.status,
            duplicate: queued.duplicate,
          });
        }
        cursor.last_scanned_block = toBlock;
        cursor.last_scan_at = nowIso();
        cursor.last_error = "";
        results.push({ routeId: route.routeId, ok: true, fromBlock, toBlock, latest, matched: items.length, items });
      } catch (error) {
        cursor.last_error = error.message || String(error);
        cursor.last_scan_at = nowIso();
        results.push({ routeId: route.routeId, ok: false, error: cursor.last_error });
      }
    }
    if (results.length) saveState();
    return results;
  } finally {
    runtime.withdrawal_scan_active = false;
  }
}

async function reconcileWithdrawals() {
  const bestById = new Map();
  const statusRank = {
    released: 5,
    already_released: 5,
    queued: 3,
    release_pending_operator: 2,
    release_pending_config: 2,
    release_failed: 1,
  };

  for (const withdrawal of state.withdrawals) {
    const existing = bestById.get(withdrawal.withdrawal_id);
    if (!existing || (statusRank[withdrawal.status] || 0) > (statusRank[existing.status] || 0)) {
      bestById.set(withdrawal.withdrawal_id, withdrawal);
    }
  }

  const results = [];
  for (const withdrawal of bestById.values()) {
    const route = routeById(withdrawal.route_id);
    if (!route || route.sourceKind !== "evm" || !route.lockboxAddress) {
      results.push({ withdrawal_id: withdrawal.withdrawal_id, ok: false, status: withdrawal.status, reason: "route_not_reconcilable" });
      continue;
    }
    if (["released", "already_released"].includes(withdrawal.status)) {
      results.push({ withdrawal_id: withdrawal.withdrawal_id, ok: true, status: withdrawal.status });
      continue;
    }
    try {
      const provider = new ethers.JsonRpcProvider(route.rpc);
      const lockbox = new ethers.Contract(route.lockboxAddress, SOURCE_LOCKBOX_ABI, provider);
      const processed = await lockbox.processedReleases(withdrawal.withdrawal_id);
      if (processed) {
        withdrawal.status = "already_released";
        withdrawal.release = {
          ...(withdrawal.release || {}),
          released: true,
          already_processed: true,
          release_id: withdrawal.withdrawal_id,
          lockbox: route.lockboxAddress,
        };
        delete withdrawal.error;
        withdrawal.updated_at = nowIso();
      }
      results.push({ withdrawal_id: withdrawal.withdrawal_id, ok: true, processed, status: withdrawal.status });
    } catch (error) {
      results.push({ withdrawal_id: withdrawal.withdrawal_id, ok: false, status: withdrawal.status, error: error.message || String(error) });
    }
  }

  state.withdrawals = Array.from(bestById.values()).sort((a, b) => String(b.created_at || "").localeCompare(String(a.created_at || "")));
  addAudit("withdrawal.reconciled", { count: results.length });
  saveState();
  return results;
}

const server = http.createServer(async (req, res) => {
  for (const [key, value] of Object.entries(corsHeaders(req))) {
    res.setHeader(key, value);
  }
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      ...corsHeaders(req),
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "content-type,x-ynx-bridge-token",
    });
    return res.end();
  }

  const url = new URL(req.url, "http://localhost");
  const segments = url.pathname.split("/").filter(Boolean);

  if ((req.method === "GET" || req.method === "HEAD") && (url.pathname === "/health" || url.pathname === "/bridge/health")) {
    const readinessItems = await allRouteReadiness();
    const readinessBlockers = summarizeRouteBlockers(readinessItems);
    const readinessRequirements = summarizeRouteRequirements(readinessItems);
    const readinessActions = summarizeNextActions(readinessItems);
    const gatewaySignerSet = await fetchGatewaySignerSet();
    const readinessSummary = {
      routes: readinessItems.length,
      full_loop_ready: readinessItems.filter((item) => item.full_loop_ready).length,
      full_loop_tested: readinessItems.filter((item) => item.full_loop_tested).length,
      automatic_loop_ready: readinessItems.filter((item) => item.automatic_loop_ready).length,
      deposit_tested: readinessItems.filter((item) => item.phase === "deposit_tested" || item.phase === "full_loop_tested").length,
      release_evidence_observed: readinessItems.filter((item) => (item.evidence?.released_withdrawals || 0) > 0 || item.full_loop_tested).length,
      mapped_route_only: readinessItems.filter((item) => item.phase === "mapped_route_only").length,
    };
    return json(res, 200, {
      ok: true,
      service: "ynx-bridge-service",
      network: routesConfig.network || "",
      ynx_chain_id: routesConfig.ynxChainId || 9102,
      gateway: gatewayAddress(),
      onchain: {
        enabled: BRIDGE_ONCHAIN_ENABLED,
        ready: onchainReady(),
        missing_requirements: bridgeOnchainMissingRequirements(),
        configuration_status: {
          rpc_configured: Boolean(BRIDGE_YNX_RPC_URL),
          relayer_configured: Boolean(BRIDGE_RELAYER_PRIVATE_KEY),
          remote_signer_configured: Boolean(BRIDGE_REMOTE_SIGNER_ADDRESS),
          attester_configured: Boolean(BRIDGE_ATTESTER_PRIVATE_KEY),
          source_relayer_configured: Boolean(BRIDGE_SOURCE_EVM_PRIVATE_KEY),
          btc_testnet_release_signer_configured: Boolean(BRIDGE_SOURCE_BTC_TESTNET_SIGNER || BRIDGE_NON_EVM_RELEASE_MOCK),
          tron_shasta_release_signer_configured: Boolean(BRIDGE_SOURCE_TRON_SHASTA_SIGNER || BRIDGE_NON_EVM_RELEASE_MOCK),
        },
        rpc_configured: Boolean(BRIDGE_YNX_RPC_URL),
        relayer_configured: Boolean(BRIDGE_RELAYER_PRIVATE_KEY),
        relayer_mode: BRIDGE_RELAYER_MODE,
        remote_signer_configured: Boolean(BRIDGE_REMOTE_SIGNER_ADDRESS),
        signer_address: runtime.signerAddress,
        gateway_signer_set: gatewaySignerSet,
        attester_configured: Boolean(BRIDGE_ATTESTER_PRIVATE_KEY),
        attester_address: runtime.attesterWallet ? runtime.attesterWallet.address : "",
        confirmations: BRIDGE_CONFIRMATIONS,
        watcher_max_blocks: BRIDGE_WATCHER_MAX_BLOCKS,
        watcher_poll_ms: BRIDGE_WATCHER_POLL_MS,
        withdrawal_watcher_poll_ms: BRIDGE_WITHDRAWAL_WATCHER_POLL_MS,
        withdrawal_release_enabled: BRIDGE_WITHDRAWAL_RELEASE_ENABLED,
        source_relayer_configured: Boolean(BRIDGE_SOURCE_EVM_PRIVATE_KEY),
        btc_testnet_release_signer_configured: Boolean(BRIDGE_SOURCE_BTC_TESTNET_SIGNER || BRIDGE_NON_EVM_RELEASE_MOCK),
        tron_shasta_release_signer_configured: Boolean(BRIDGE_SOURCE_TRON_SHASTA_SIGNER || BRIDGE_NON_EVM_RELEASE_MOCK),
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
        released_withdrawals: state.withdrawals.filter((item) => item.status === "released" || item.status === "already_released").length,
        watcher_routes: Object.keys(state.watchers).length,
        withdrawal_watcher_routes: Object.keys(state.withdrawal_watchers).length,
      },
      route_readiness: {
        ok: readinessItems.every((item) => item.ok),
        items: readinessItems,
        summary: readinessSummary,
        blockers: readinessBlockers,
        requirements: readinessRequirements,
        actions: readinessActions,
      },
    });
  }

  if ((req.method === "GET" || req.method === "HEAD") && (url.pathname === "/ready" || url.pathname === "/bridge/ready")) {
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

  if (req.method === "GET" && url.pathname === "/bridge/assets") {
    return json(res, 200, { ok: true, ...assetsConfig });
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

  if (req.method === "GET" && url.pathname === "/bridge/route-readiness") {
    const includeSource = url.searchParams.get("source") === "1" || url.searchParams.get("include_source") === "1";
    const items = await allRouteReadiness({ includeSource });
    return json(res, 200, {
      ok: items.every((item) => item.ok),
      source_live_check: includeSource,
      items,
      summary: {
        routes: items.length,
        full_loop_ready: items.filter((item) => item.full_loop_ready).length,
        full_loop_tested: items.filter((item) => item.full_loop_tested).length,
        automatic_loop_ready: items.filter((item) => item.automatic_loop_ready).length,
        deposit_tested: items.filter((item) => item.phase === "deposit_tested" || item.phase === "full_loop_tested").length,
        mapped_route_only: items.filter((item) => item.phase === "mapped_route_only").length,
      },
    });
  }

  if (req.method === "GET" && url.pathname === "/bridge/watchers") {
    return json(res, 200, { ok: true, items: state.watchers });
  }

  if (req.method === "GET" && url.pathname === "/bridge/withdrawal-watchers") {
    return json(res, 200, { ok: true, items: state.withdrawal_watchers });
  }

  if (req.method === "POST" && url.pathname === "/bridge/watchers/scan") {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const body = await parseBody(req, BRIDGE_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const requestedRoute = body.route_id || body.routeId || "";
    const routes = requestedRoute ? [routeById(requestedRoute)].filter(Boolean) : (routesConfig.routes || []);
    if (requestedRoute && routes.length === 0) return json(res, 400, { ok: false, error: "route_not_found" });
    const results = [];
    if (!requestedRoute) {
      results.push(...(await scanConfiguredWatchers()));
    } else for (const route of routes) {
      try {
        results.push(await scanDepositWatcherRoute(route));
      } catch (error) {
        const cursor = watcherState(route.routeId);
        cursor.last_error = error.message || String(error);
        cursor.last_scan_at = nowIso();
        results.push({ routeId: route.routeId, ok: false, error: cursor.last_error });
      }
    }
    saveState();
    return json(res, 200, { ok: results.every((item) => item.ok || item.skipped), items: results });
  }

  if (req.method === "POST" && url.pathname === "/bridge/withdrawal-watchers/scan") {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const results = await scanYnxBurnWithdrawals();
    return json(res, 200, { ok: results.every((item) => item.ok || item.skipped), items: results });
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
    try {
      const accepted = await acceptDepositProof(route, body);
      return json(res, accepted.statusCode, {
        ok: accepted.deposit.status !== "mint_failed",
        deposit: accepted.deposit,
        duplicate: accepted.duplicate,
      });
    } catch (error) {
      return json(res, error.statusCode || 400, { ok: false, error: error.message || "invalid_deposit", ...(error.details || {}) });
    }
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
        const gateway = await getGateway();
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

  if (segments[0] === "bridge" && segments[1] === "withdrawals" && segments[2] === "reconcile" && req.method === "POST") {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const results = await reconcileWithdrawals();
    return json(res, 200, { ok: true, items: results });
  }

  if (
    segments[0] === "bridge" &&
    segments[1] === "withdrawals" &&
    segments[2] &&
    segments[3] === "release" &&
    req.method === "POST"
  ) {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const withdrawal = withdrawalById(segments[2]);
    if (!withdrawal) return json(res, 404, { ok: false, error: "withdrawal_not_found" });
    const route = routeById(withdrawal.route_id);
    if (!route) return json(res, 400, { ok: false, error: "route_not_found" });
    if (["released", "already_released"].includes(withdrawal.status)) {
      return json(res, 200, { ok: true, withdrawal, duplicate: true });
    }
    try {
      const release = await releaseWithdrawalOnSource(withdrawal, route);
      withdrawal.release = release;
      withdrawal.status = release.released ? (release.already_processed ? "already_released" : "released") : "release_pending_config";
      if (!release.released) withdrawal.release_reason = release.reason;
      delete withdrawal.error;
      withdrawal.updated_at = nowIso();
      addAudit("withdrawal.release_attempted", {
        withdrawal_id: withdrawal.withdrawal_id,
        route_id: withdrawal.route_id,
        status: withdrawal.status,
        reason: release.reason || "",
      });
      saveState();
      return json(res, release.released ? 200 : 409, { ok: release.released, withdrawal, error: release.released ? undefined : release.reason });
    } catch (error) {
      withdrawal.status = "release_failed";
      withdrawal.error = error.message || String(error);
      withdrawal.updated_at = nowIso();
      saveState();
      return json(res, 502, { ok: false, error: withdrawal.error, withdrawal });
    }
  }

  if (
    segments[0] === "bridge" &&
    segments[1] === "withdrawals" &&
    segments[2] &&
    segments[3] === "mark-released" &&
    req.method === "POST"
  ) {
    if (!assertOperator(req)) return json(res, 401, { ok: false, error: "operator_token_required" });
    const body = await parseBody(req, BRIDGE_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const withdrawal = withdrawalById(segments[2]);
    if (!withdrawal) return json(res, 404, { ok: false, error: "withdrawal_not_found" });
    const route = routeById(withdrawal.route_id);
    if (!route) return json(res, 400, { ok: false, error: "route_not_found" });
    if (["released", "already_released"].includes(withdrawal.status)) {
      return json(res, 200, { ok: true, withdrawal, duplicate: true });
    }
    const releaseTxHash = String(body.release_tx_hash || body.tx_hash || "").trim();
    if (!releaseTxHash) return json(res, 400, { ok: false, error: "release_tx_hash_required" });
    withdrawal.status = "released";
    withdrawal.release = {
      released: true,
      manual: true,
      release_id: withdrawal.withdrawal_id,
      source_kind: route.sourceKind,
      source_network: route.sourceNetwork,
      tx_hash: releaseTxHash,
      amount_base_units: withdrawal.amount_base_units,
      recipient: withdrawal.destination_recipient,
      proof: body.proof || {},
      confirmed_at: nowIso(),
    };
    delete withdrawal.error;
    delete withdrawal.release_reason;
    withdrawal.updated_at = nowIso();
    addAudit("withdrawal.mark_released", {
      withdrawal_id: withdrawal.withdrawal_id,
      route_id: withdrawal.route_id,
      source_kind: route.sourceKind,
      release_tx_hash: releaseTxHash,
    });
    saveState();
    return json(res, 200, { ok: true, withdrawal });
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

server.headersTimeout = BRIDGE_SERVER_HEADERS_TIMEOUT_MS;
server.requestTimeout = BRIDGE_SERVER_REQUEST_TIMEOUT_MS;
server.keepAliveTimeout = BRIDGE_SERVER_KEEP_ALIVE_TIMEOUT_MS;
server.maxRequestsPerSocket = BRIDGE_SERVER_MAX_REQUESTS_PER_SOCKET;
server.maxHeadersCount = BRIDGE_SERVER_MAX_HEADERS_COUNT;

server.listen(BRIDGE_PORT, () => {
  console.log(`YNX bridge service listening on :${BRIDGE_PORT}`);
});

if (BRIDGE_WATCHER_POLL_MS > 0) {
  setInterval(() => {
    scanConfiguredWatchers().catch((error) => {
      runtime.last_error = error.message || String(error);
      console.error("[bridge-service] watcher scan failed:", runtime.last_error);
    });
  }, BRIDGE_WATCHER_POLL_MS).unref();
}

if (BRIDGE_WITHDRAWAL_WATCHER_POLL_MS > 0) {
  setInterval(() => {
    scanYnxBurnWithdrawals().catch((error) => {
      runtime.last_error = error.message || String(error);
      console.error("[bridge-service] withdrawal watcher scan failed:", runtime.last_error);
    });
  }, BRIDGE_WITHDRAWAL_WATCHER_POLL_MS).unref();
}

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
