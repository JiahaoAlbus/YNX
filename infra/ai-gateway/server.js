const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
const crypto = require("crypto");
const { ethers } = require("ethers");

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
  const status = body.__parse_error === "payload_too_large" ? 413 : 400;
  json(res, status, { ok: false, error: body.__parse_error });
  return false;
}

function nowIso() {
  return new Date().toISOString();
}

function randomId(prefix) {
  return `${prefix}_${crypto.randomBytes(8).toString("hex")}`;
}

function toNumber(value, fallback = 0) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function uniqueStrings(items) {
  return [...new Set((Array.isArray(items) ? items : []).filter((item) => typeof item === "string" && item.trim()))];
}

function atomicWriteJson(filePath, payload) {
  const tmpPath = `${filePath}.${process.pid}.tmp`;
  fs.writeFileSync(tmpPath, JSON.stringify(payload, null, 2));
  fs.renameSync(tmpPath, filePath);
}

async function atomicWriteJsonAsync(filePath, payload) {
  const tmpPath = `${filePath}.${process.pid}.tmp`;
  await fs.promises.writeFile(tmpPath, JSON.stringify(payload, null, 2));
  await fs.promises.rename(tmpPath, filePath);
}

function normalizeState(loaded) {
  if (Array.isArray(loaded)) {
    return {
      jobs: loaded,
      vaults: [],
      payments: [],
      audit_logs: [],
    };
  }

  const source = loaded && typeof loaded === "object" ? loaded : {};
  return {
    jobs: Array.isArray(source.jobs) ? source.jobs : [],
    vaults: Array.isArray(source.vaults) ? source.vaults : [],
    payments: Array.isArray(source.payments) ? source.payments : [],
    audit_logs: Array.isArray(source.audit_logs) ? source.audit_logs : [],
  };
}

function postJson(targetUrl, payload, extraHeaders = {}, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(targetUrl);
    const transport = url.protocol === "https:" ? https : http;
    const body = JSON.stringify(payload);
    const req = transport.request(
      {
        method: "POST",
        hostname: url.hostname,
        port: url.port || (url.protocol === "https:" ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        timeout: options.timeout_ms || 20000,
        headers: {
          "content-type": "application/json",
          "content-length": Buffer.byteLength(body),
          ...extraHeaders,
        },
      },
      (res) => {
        let raw = "";
        res.on("data", (chunk) => {
          raw += chunk.toString();
        });
        res.on("end", () => {
          let parsed = {};
          try {
            parsed = raw ? JSON.parse(raw) : {};
          } catch {
            parsed = { ok: false, error: "invalid_upstream_response", raw };
          }
          resolve({ status: res.statusCode || 500, payload: parsed });
        });
      }
    );

    req.on("timeout", () => req.destroy(new Error("upstream_timeout")));
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

function getJson(targetUrl, options = {}) {
  return new Promise((resolve) => {
    const url = new URL(targetUrl);
    const transport = url.protocol === "https:" ? https : http;
    const req = transport.request(
      {
        method: "GET",
        hostname: url.hostname,
        port: url.port || (url.protocol === "https:" ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        timeout: options.timeout_ms || 8000,
        headers: options.headers || {},
      },
      (res) => {
        let raw = "";
        res.on("data", (chunk) => {
          raw += chunk.toString();
        });
        res.on("end", () => {
          try {
            resolve({ status: res.statusCode || 0, payload: raw ? JSON.parse(raw) : {} });
          } catch {
            resolve({ status: res.statusCode || 0, payload: { raw } });
          }
        });
      }
    );
    req.on("timeout", () => req.destroy(new Error("upstream_timeout")));
    req.on("error", (error) => resolve({ status: 0, payload: { ok: false, error: error.message || "request_failed" } }));
    req.end();
  });
}

const AI_GATEWAY_PORT = parseInt(process.env.AI_GATEWAY_PORT || "8090", 10);
const AI_CHAIN_ID = process.env.AI_CHAIN_ID || "ynx_9102-1";
const AI_DATA_DIR = process.env.AI_DATA_DIR || path.resolve(__dirname, "data");
const AI_DATA_FILE = path.join(AI_DATA_DIR, "jobs.json");
const AI_DEFAULT_CHALLENGE_BLOCKS = parseInt(process.env.AI_DEFAULT_CHALLENGE_BLOCKS || "120", 10);
const AI_X402_UNIT_PRICE = Number(process.env.AI_X402_UNIT_PRICE || "1");
const AI_X402_DENOM = process.env.AI_X402_DENOM || "usdc";
const AI_BODY_LIMIT_BYTES = parseInt(process.env.AI_BODY_LIMIT_BYTES || "1048576", 10);
const AI_ENFORCE_POLICY = process.env.AI_ENFORCE_POLICY !== "0";
const AI_WEB4_HUB_URL = (process.env.AI_WEB4_HUB_URL || process.env.YNX_PUBLIC_WEB4_HUB || "").replace(/\/$/, "");
const AI_WEB4_INTERNAL_TOKEN = process.env.AI_WEB4_INTERNAL_TOKEN || process.env.WEB4_INTERNAL_TOKEN || "";
const AI_AUDIT_LIMIT = parseInt(process.env.AI_AUDIT_LIMIT || "5000", 10);
const AI_MAX_JOBS = parseInt(process.env.AI_MAX_JOBS || "200000", 10);
const AI_MAX_VAULTS = parseInt(process.env.AI_MAX_VAULTS || "50000", 10);
const AI_MAX_PAYMENTS = parseInt(process.env.AI_MAX_PAYMENTS || "200000", 10);
const AI_PERSIST_DEBOUNCE_MS = Math.max(0, parseInt(process.env.AI_PERSIST_DEBOUNCE_MS || "200", 10));
const AI_ONCHAIN_ENABLED = process.env.AI_ONCHAIN_ENABLED === "1";
const AI_ONCHAIN_RPC_URL = process.env.AI_ONCHAIN_RPC_URL || process.env.YNX_PUBLIC_EVM_RPC || "";
const AI_ONCHAIN_PRIVATE_KEY = process.env.AI_ONCHAIN_PRIVATE_KEY || process.env.YNX_EVM_PRIVATE_KEY || "";
const AI_SETTLEMENT_CONTRACT = process.env.AI_SETTLEMENT_CONTRACT || process.env.YNX_AI_SETTLEMENT_CONTRACT || "";
const AI_ONCHAIN_CONFIRMATIONS = Math.max(0, parseInt(process.env.AI_ONCHAIN_CONFIRMATIONS || "1", 10) || 0);
const AI_INTELLIGENCE_ENABLED = process.env.AI_INTELLIGENCE_ENABLED !== "0";
const AI_LLM_PROVIDER = (process.env.AI_LLM_PROVIDER || "openai-responses").toLowerCase();
const AI_LLM_API_KEY = process.env.AI_LLM_API_KEY || process.env.OPENAI_API_KEY || "";
const AI_LLM_MODEL = process.env.AI_LLM_MODEL || process.env.OPENAI_MODEL || (AI_LLM_PROVIDER === "ollama" ? "qwen2.5:1.5b" : "gpt-4o-mini");
const AI_LLM_BASE_URL = (
  process.env.AI_LLM_BASE_URL ||
  (AI_LLM_PROVIDER === "ollama" ? "http://127.0.0.1:11434/api/chat" : "https://api.openai.com/v1/responses")
).replace(/\/$/, "");
const AI_LLM_TIMEOUT_MS = Math.max(1000, parseInt(process.env.AI_LLM_TIMEOUT_MS || "20000", 10) || 20000);
const AI_PUBLIC_BRIDGE_URL = (process.env.AI_PUBLIC_BRIDGE_URL || "https://rpc.ynxweb4.com/bridge").replace(/\/$/, "");
const AI_PUBLIC_WEB4_URL = (process.env.AI_PUBLIC_WEB4_URL || AI_WEB4_HUB_URL || "https://web4.ynxweb4.com").replace(/\/$/, "");
const AI_PUBLIC_SITE_URL = (process.env.AI_PUBLIC_SITE_URL || "https://www.ynxweb4.com").replace(/\/$/, "");
const AI_PUBLIC_EVM_RPC_URL = (process.env.AI_PUBLIC_EVM_RPC_URL || process.env.YNX_PUBLIC_EVM_RPC || "https://evm.ynxweb4.com").replace(/\/$/, "");
const AI_EVM_RPC_TIMEOUT_MS = Math.max(500, parseInt(process.env.AI_EVM_RPC_TIMEOUT_MS || "2500", 10) || 2500);

const AI_SETTLEMENT_ABI = [
  "function createVault(bytes32 vaultId, bytes32 policyHash, uint256 maxPerPayment) payable",
  "function deposit(bytes32 vaultId) payable",
  "function createJob(bytes32 jobId, bytes32 vaultId, uint256 reward, uint256 stake, bytes32 inputHash, bytes32 policyHash, uint64 challengeBlocks)",
  "function commitResult(bytes32 jobId, bytes32 resultHash, string attestationURI)",
  "function challenge(bytes32 jobId)",
  "function finalize(bytes32 jobId)",
  "function slash(bytes32 jobId)",
  "function vaults(bytes32 vaultId) view returns (address owner,uint256 balance,uint256 maxPerPayment,bool active,bytes32 policyHash)",
  "function jobs(bytes32 jobId) view returns (bytes32 vaultId,address creator,address worker,uint256 reward,uint256 stake,uint64 challengeDeadline,bytes32 inputHash,bytes32 resultHash,string attestationURI,uint8 status,bytes32 policyHash)",
];

if (!fs.existsSync(AI_DATA_DIR)) fs.mkdirSync(AI_DATA_DIR, { recursive: true });

let state = {
  jobs: [],
  vaults: [],
  payments: [],
  audit_logs: [],
};

if (fs.existsSync(AI_DATA_FILE)) {
  try {
    const loaded = JSON.parse(fs.readFileSync(AI_DATA_FILE, "utf8"));
    state = normalizeState(loaded);
  } catch {
    state = normalizeState({});
  }
}

let onchainRuntime = {
  provider: null,
  signer: null,
  contract: null,
  last_error: "",
  last_tx_hash: "",
  last_tx_at: "",
};

function isHex32(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value);
}

function bytes32From(value, fallback) {
  if (isHex32(value)) return value;
  return ethers.id(String(value || fallback || ""));
}

function weiFrom(value, fallback = "0") {
  const raw = value === undefined || value === null || value === "" ? fallback : value;
  if (typeof raw === "bigint") return raw;
  if (typeof raw === "number") {
    if (!Number.isFinite(raw) || raw < 0) throw new Error("invalid_wei_amount");
    return BigInt(Math.trunc(raw));
  }
  const str = String(raw).trim();
  if (!/^[0-9]+$/.test(str)) throw new Error("invalid_wei_amount");
  return BigInt(str);
}

function onchainConfigReady() {
  return Boolean(AI_ONCHAIN_ENABLED && AI_ONCHAIN_RPC_URL && AI_ONCHAIN_PRIVATE_KEY && AI_SETTLEMENT_CONTRACT);
}

function getSettlementContract() {
  if (!AI_ONCHAIN_ENABLED) throw new Error("onchain_disabled");
  if (!AI_ONCHAIN_RPC_URL) throw new Error("onchain_rpc_required");
  if (!AI_ONCHAIN_PRIVATE_KEY) throw new Error("onchain_private_key_required");
  if (!AI_SETTLEMENT_CONTRACT) throw new Error("settlement_contract_required");
  if (!onchainRuntime.contract) {
    onchainRuntime.provider = new ethers.JsonRpcProvider(AI_ONCHAIN_RPC_URL);
    onchainRuntime.signer = new ethers.Wallet(AI_ONCHAIN_PRIVATE_KEY, onchainRuntime.provider);
    onchainRuntime.contract = new ethers.Contract(AI_SETTLEMENT_CONTRACT, AI_SETTLEMENT_ABI, onchainRuntime.signer);
  }
  return onchainRuntime.contract;
}

async function waitTx(tx) {
  const receipt = await tx.wait(AI_ONCHAIN_CONFIRMATIONS);
  onchainRuntime.last_tx_hash = tx.hash;
  onchainRuntime.last_tx_at = nowIso();
  onchainRuntime.last_error = "";
  return {
    tx_hash: tx.hash,
    block_number: receipt?.blockNumber || null,
    confirmations: AI_ONCHAIN_CONFIRMATIONS,
  };
}

async function callOnchain(action, fn) {
  try {
    const result = await fn(getSettlementContract());
    addAudit(`onchain.${action}`, result);
    return { ok: true, result };
  } catch (error) {
    const message = error && error.shortMessage ? error.shortMessage : error && error.message ? error.message : String(error);
    onchainRuntime.last_error = message;
    addAudit(`onchain.${action}.failed`, { error: message });
    return { ok: false, error: message };
  }
}

async function createVaultOnchain(vault, body) {
  const vaultId = bytes32From(body.onchain_vault_id, `vault:${vault.vault_id}`);
  const policyHash = bytes32From(body.policy_hash, `policy:${vault.policy_id || vault.owner || vault.vault_id}`);
  const maxPerPayment = weiFrom(body.onchain_max_per_payment_wei, "0");
  const value = weiFrom(body.onchain_value_wei, "0");
  const response = await callOnchain("vault.created", async (contract) => {
    const tx = await contract.createVault(vaultId, policyHash, maxPerPayment, { value });
    return {
      ...(await waitTx(tx)),
      vault_id: vaultId,
      policy_hash: policyHash,
      value_wei: value.toString(),
      max_per_payment_wei: maxPerPayment.toString(),
      contract: AI_SETTLEMENT_CONTRACT,
    };
  });
  if (!response.ok) return response;
  return { ok: true, onchain: response.result };
}

async function depositVaultOnchain(vault, body) {
  if (!vault.onchain?.vault_id) return { ok: false, error: "vault_not_onchain" };
  const value = weiFrom(body.onchain_value_wei ?? body.amount_wei, "0");
  if (value <= 0n) return { ok: false, error: "invalid_onchain_value" };
  const response = await callOnchain("vault.deposited", async (contract) => {
    const tx = await contract.deposit(vault.onchain.vault_id, { value });
    return {
      ...(await waitTx(tx)),
      vault_id: vault.onchain.vault_id,
      value_wei: value.toString(),
      contract: AI_SETTLEMENT_CONTRACT,
    };
  });
  if (!response.ok) return response;
  return { ok: true, onchain: response.result };
}

async function createJobOnchain(job, vault, body) {
  if (!vault?.onchain?.vault_id) return { ok: false, error: "vault_not_onchain" };
  const jobId = bytes32From(body.onchain_job_id, `job:${job.job_id}`);
  const reward = weiFrom(body.reward_wei ?? body.onchain_reward_wei, "");
  const stake = weiFrom(body.stake_wei ?? body.onchain_stake_wei, "0");
  const inputHash = bytes32From(body.input_hash, body.input_uri || `input:${job.job_id}`);
  const policyHash = vault.onchain.policy_hash || bytes32From(body.policy_hash, `policy:${job.policy_id || vault.policy_id}`);
  const challengeRaw =
    body.challenge_window_blocks === undefined || body.challenge_window_blocks === null
      ? AI_DEFAULT_CHALLENGE_BLOCKS
      : body.challenge_window_blocks;
  const challengeBlocks = Math.max(0, parseInt(challengeRaw, 10) || 0);
  const response = await callOnchain("job.created", async (contract) => {
    const tx = await contract.createJob(jobId, vault.onchain.vault_id, reward, stake, inputHash, policyHash, challengeBlocks);
    return {
      ...(await waitTx(tx)),
      job_id: jobId,
      vault_id: vault.onchain.vault_id,
      reward_wei: reward.toString(),
      stake_wei: stake.toString(),
      input_hash: inputHash,
      policy_hash: policyHash,
      contract: AI_SETTLEMENT_CONTRACT,
    };
  });
  if (!response.ok) return response;
  return { ok: true, onchain: response.result };
}

async function commitJobOnchain(job, body) {
  if (!job.onchain?.job_id) return { ok: false, error: "job_not_onchain" };
  const resultHash = bytes32From(body.result_hash, `result:${job.job_id}:${body.attestation_uri || ""}`);
  const response = await callOnchain("job.committed", async (contract) => {
    const tx = await contract.commitResult(job.onchain.job_id, resultHash, body.attestation_uri || "");
    return {
      ...(await waitTx(tx)),
      job_id: job.onchain.job_id,
      result_hash: resultHash,
      contract: AI_SETTLEMENT_CONTRACT,
    };
  });
  if (!response.ok) return response;
  return { ok: true, onchain: response.result };
}

async function transitionJobOnchain(job, action) {
  if (!job.onchain?.job_id) return { ok: false, error: "job_not_onchain" };
  const response = await callOnchain(`job.${action}`, async (contract) => {
    const tx = await contract[action](job.onchain.job_id);
    return {
      ...(await waitTx(tx)),
      job_id: job.onchain.job_id,
      contract: AI_SETTLEMENT_CONTRACT,
    };
  });
  if (!response.ok) return response;
  return { ok: true, onchain: response.result };
}

const persistRuntime = {
  timer: null,
  pending: false,
  writing: false,
  writes: 0,
  queued: 0,
  last_persist_at: "",
  last_error: "",
};

function trimStateForRetention() {
  if (AI_MAX_JOBS > 0 && state.jobs.length > AI_MAX_JOBS) state.jobs = state.jobs.slice(0, AI_MAX_JOBS);
  if (AI_MAX_VAULTS > 0 && state.vaults.length > AI_MAX_VAULTS) state.vaults = state.vaults.slice(0, AI_MAX_VAULTS);
  if (AI_MAX_PAYMENTS > 0 && state.payments.length > AI_MAX_PAYMENTS) state.payments = state.payments.slice(0, AI_MAX_PAYMENTS);
  if (AI_AUDIT_LIMIT > 0 && state.audit_logs.length > AI_AUDIT_LIMIT) state.audit_logs = state.audit_logs.slice(0, AI_AUDIT_LIMIT);
}

function persistSync() {
  trimStateForRetention();
  atomicWriteJson(AI_DATA_FILE, state);
  persistRuntime.writes += 1;
  persistRuntime.last_persist_at = nowIso();
}

async function flushPersist() {
  if (!persistRuntime.pending || persistRuntime.writing) return;
  persistRuntime.writing = true;
  persistRuntime.pending = false;
  try {
    trimStateForRetention();
    await atomicWriteJsonAsync(AI_DATA_FILE, state);
    persistRuntime.writes += 1;
    persistRuntime.last_persist_at = nowIso();
    persistRuntime.last_error = "";
  } catch (error) {
    persistRuntime.last_error = error && error.message ? error.message : "persist_failed";
    console.error("[ai-gateway] persist error:", error);
  } finally {
    persistRuntime.writing = false;
    if (persistRuntime.pending) {
      void flushPersist();
    }
  }
}

function persist() {
  persistRuntime.pending = true;
  persistRuntime.queued += 1;
  if (AI_PERSIST_DEBOUNCE_MS === 0) {
    void flushPersist();
    return;
  }
  if (persistRuntime.timer) return;
  persistRuntime.timer = setTimeout(() => {
    persistRuntime.timer = null;
    void flushPersist();
  }, AI_PERSIST_DEBOUNCE_MS);
}

function addAudit(event, payload) {
  state.audit_logs.unshift({
    audit_id: randomId("audit"),
    event,
    payload,
    created_at: nowIso(),
  });
  if (state.audit_logs.length > AI_AUDIT_LIMIT) {
    state.audit_logs = state.audit_logs.slice(0, AI_AUDIT_LIMIT);
  }
}

function createJob(payload, vault) {
  return {
    job_id: payload.job_id || randomId("job"),
    creator: payload.creator || "",
    worker: payload.worker || "",
    policy_id: payload.policy_id || vault?.policy_id || "",
    vault_id: payload.vault_id || "",
    reward: payload.reward || "0",
    stake: payload.stake || "0",
    input_uri: payload.input_uri || "",
    result_hash: "",
    attestation_uri: "",
    status: "created",
    challenge_window_blocks: Number.isFinite(payload.challenge_window_blocks)
      ? payload.challenge_window_blocks
      : AI_DEFAULT_CHALLENGE_BLOCKS,
    payout_payment_id: "",
    created_at: nowIso(),
    updated_at: nowIso(),
    finalized_at: "",
  };
}

function canTransitionJob(job, nextStatus) {
  const allowed = {
    created: ["committed", "cancelled"],
    committed: ["challenged", "finalized", "slashed"],
    challenged: ["finalized", "slashed"],
    finalized: [],
    slashed: [],
    cancelled: [],
  };
  return Boolean(allowed[job.status] && allowed[job.status].includes(nextStatus));
}

function findJob(jobId) {
  return state.jobs.find((item) => item.job_id === jobId);
}

function findVault(vaultId) {
  return state.vaults.find((item) => item.vault_id === vaultId);
}

function resetDaily(vault) {
  const key = new Date().toISOString().slice(0, 10);
  if (vault.spent_day_key !== key) {
    vault.spent_day_key = key;
    vault.spent_day = 0;
  }
}

function createVault(payload) {
  return {
    vault_id: payload.vault_id || randomId("vault"),
    owner: payload.owner || "",
    policy_id: payload.policy_id || "",
    status: "active",
    balance: toNumber(payload.balance, 0),
    max_daily_spend: toNumber(payload.max_daily_spend, 0),
    max_per_payment: toNumber(payload.max_per_payment, 0),
    metadata: payload.metadata && typeof payload.metadata === "object" ? payload.metadata : {},
    spent_day: 0,
    spent_day_key: new Date().toISOString().slice(0, 10),
    created_at: nowIso(),
    updated_at: nowIso(),
  };
}

function chargeVault(vault, amount, context = {}) {
  if (!vault) return { ok: false, error: "vault_not_found" };
  if (vault.status !== "active") return { ok: false, error: `vault_${vault.status}` };
  if (amount <= 0) return { ok: false, error: "invalid_amount" };
  resetDaily(vault);
  if (vault.max_per_payment > 0 && amount > vault.max_per_payment) return { ok: false, error: "max_per_payment_exceeded" };
  if (vault.max_daily_spend > 0 && vault.spent_day + amount > vault.max_daily_spend) return { ok: false, error: "max_daily_spend_exceeded" };
  if (vault.balance < amount) return { ok: false, error: "insufficient_balance" };

  vault.balance -= amount;
  vault.spent_day += amount;
  vault.updated_at = nowIso();

  const payment = {
    payment_id: context.payment_id || randomId("pay"),
    vault_id: vault.vault_id,
    policy_id: vault.policy_id || "",
    amount,
    denom: context.denom || AI_X402_DENOM,
    reason: context.reason || "machine-payment",
    request_id: context.request_id || "",
    resource: context.resource || "",
    status: "settled",
    created_at: nowIso(),
  };
  state.payments.unshift(payment);
  return { ok: true, payment };
}

function quoteFromRequest(body) {
  const units = Math.max(1, parseInt(body.units || "1", 10) || 1);
  const unitPrice = toNumber(body.unit_price, AI_X402_UNIT_PRICE);
  const amount = units * unitPrice;
  return { units, unit_price: unitPrice, amount };
}

function summarizeStats() {
  const byStatus = state.jobs.reduce((acc, item) => {
    acc[item.status] = (acc[item.status] || 0) + 1;
    return acc;
  }, {});
  return {
    total_jobs: state.jobs.length,
    total_vaults: state.vaults.length,
    total_payments: state.payments.length,
    by_status: byStatus,
  };
}

async function collectIntelligenceContext() {
  const [bridgeHealth, routeReadiness, bridgeAssets, web4Ready] = await Promise.all([
    getJson(`${AI_PUBLIC_BRIDGE_URL}/health`),
    getJson(`${AI_PUBLIC_BRIDGE_URL}/route-readiness`),
    getJson(`${AI_PUBLIC_BRIDGE_URL}/assets`),
    getJson(`${AI_PUBLIC_WEB4_URL}/ready`),
  ]);
  return {
    chain_id: AI_CHAIN_ID,
    generated_at: nowIso(),
      ai: {
        service: "ynx-ai-gateway",
        intelligence_enabled: AI_INTELLIGENCE_ENABLED,
        llm_configured: llmConfigured(),
        llm_provider: AI_LLM_PROVIDER,
        model: llmConfigured() ? AI_LLM_MODEL : "",
      onchain: {
        enabled: AI_ONCHAIN_ENABLED,
        ready: onchainConfigReady(),
        settlement_contract: AI_SETTLEMENT_CONTRACT || "",
        last_tx_hash: onchainRuntime.last_tx_hash,
        last_error: onchainRuntime.last_error,
      },
      stats: summarizeStats(),
    },
    web4: {
      url: AI_PUBLIC_WEB4_URL,
      status: web4Ready.status,
      ready: web4Ready.payload,
    },
    bridge: {
      url: AI_PUBLIC_BRIDGE_URL,
      health_status: bridgeHealth.status,
      health: bridgeHealth.payload,
      route_readiness_status: routeReadiness.status,
      route_readiness: routeReadiness.payload,
      assets_status: bridgeAssets.status,
      assets: bridgeAssets.payload,
    },
    site: {
      url: AI_PUBLIC_SITE_URL,
      pages: ["/readiness", "/bridge", "/withdraw", "/trading", "/docs/en/ai-web4-official-demo.md"],
    },
  };
}

function hasChinese(text) {
  return /[\u3400-\u9fff]/.test(String(text || ""));
}

function summarizeRoutePhases(context) {
  const items = context.bridge?.route_readiness?.items || [];
  if (!Array.isArray(items) || items.length === 0) return "route readiness unavailable";
  return items.map((item) => `${item.routeId}:${item.phase}`).join(", ");
}

function compactIntelligenceContext(context) {
  const routeReadiness = context.bridge?.route_readiness || {};
  const bridgeHealth = context.bridge?.health || {};
  return {
    generated_at: context.generated_at,
    chain_id: context.chain_id,
    ai: {
      stats: context.ai?.stats || {},
      onchain: context.ai?.onchain || {},
    },
    bridge: {
      stats: bridgeHealth.stats || {},
      routes: routeReadiness.summary || {},
      route_phases: Array.isArray(routeReadiness.items)
        ? routeReadiness.items.map((item) => ({
            routeId: item.routeId,
            phase: item.phase,
            full_loop_tested: item.full_loop_tested,
          }))
        : [],
    },
    web4: {
      status: context.web4?.status || 0,
      ok: context.web4?.ready?.ok,
      checks: context.web4?.ready?.checks || {},
    },
    site: context.site || {},
    live_query: context.live_query || {},
  };
}

async function evmRpc(method, params = []) {
  if (!AI_PUBLIC_EVM_RPC_URL) return { ok: false, error: "evm_rpc_not_configured" };
  try {
    const response = await postJson(
      AI_PUBLIC_EVM_RPC_URL,
      { jsonrpc: "2.0", id: 1, method, params },
      {},
      { timeout_ms: AI_EVM_RPC_TIMEOUT_MS },
    );
    if (response.status < 200 || response.status >= 300) {
      return { ok: false, error: `evm_http_${response.status}` };
    }
    if (response.payload?.error) {
      return { ok: false, error: response.payload.error.message || response.payload.error.code || "evm_rpc_error" };
    }
    return { ok: true, result: response.payload?.result };
  } catch (error) {
    return { ok: false, error: error.message || "evm_rpc_failed" };
  }
}

function hexToNumber(value) {
  if (typeof value !== "string" || !/^0x[0-9a-fA-F]+$/.test(value)) return null;
  return Number.parseInt(value, 16);
}

function wantsLatestTransaction(message) {
  const text = String(message || "").toLowerCase();
  return (
    /(最后|最新|最近).*(交易|tx|transaction)/i.test(text) ||
    /(交易|tx|transaction).*(最后|最新|最近)/i.test(text) ||
    /\blatest\s+(tx|transaction)\b/i.test(text) ||
    /\blast\s+(tx|transaction)\b/i.test(text)
  );
}

function wantsLiveStatusAnswer(message) {
  const text = String(message || "").toLowerCase();
  return (
    wantsLatestTransaction(text) ||
    /(状态|现状|当前|现在|ready|health|是否|能不能|可用|上线|live|status|跨链|桥|bridge|route|资产|asset|settlement|结算|yusd|usdc|usdt|btc|eth|bnb|链上|on.?chain)/i.test(text)
  );
}

function findLatestKnownTxEvidence() {
  const candidates = [];
  const visit = (value, pathParts = [], timestamp = "") => {
    if (!value || typeof value !== "object") return;
    const nextTimestamp =
      typeof value.created_at === "string"
        ? value.created_at
        : typeof value.updated_at === "string"
          ? value.updated_at
          : typeof value.finalized_at === "string"
            ? value.finalized_at
            : timestamp;
    for (const [key, child] of Object.entries(value)) {
      const childPath = [...pathParts, key];
      if (typeof child === "string" && /^0x[0-9a-fA-F]{64}$/.test(child) && /(tx|hash)/i.test(key)) {
        candidates.push({
          tx_hash: child,
          source: childPath.join("."),
          timestamp: nextTimestamp || "",
        });
      } else if (child && typeof child === "object") {
        visit(child, childPath, nextTimestamp);
      }
    }
  };
  visit({ jobs: state.jobs, vaults: state.vaults, payments: state.payments, audit_logs: state.audit_logs });
  candidates.sort((a, b) => String(b.timestamp).localeCompare(String(a.timestamp)));
  return candidates[0] || null;
}

async function getLatestEvmTransaction(scanDepth = 1000) {
  const latest = await evmRpc("eth_getBlockByNumber", ["latest", true]);
  if (!latest.ok || !latest.result) return { ok: false, error: latest.error || "latest_block_unavailable" };

  const latestNumber = hexToNumber(latest.result.number);
  if (!Number.isFinite(latestNumber)) return { ok: false, error: "invalid_latest_block_number" };

  for (let height = latestNumber; height >= Math.max(0, latestNumber - scanDepth); height -= 1) {
    const block =
      height === latestNumber
        ? latest.result
        : (await evmRpc("eth_getBlockByNumber", [`0x${height.toString(16)}`, true])).result;
    const txs = Array.isArray(block?.transactions) ? block.transactions : [];
    const tx = txs.find((item) => item && typeof item === "object" && item.hash) || null;
    if (!tx) continue;
    const receipt = await evmRpc("eth_getTransactionReceipt", [tx.hash]);
    return {
      ok: true,
      latest_block_number: latestNumber,
      scanned_blocks: latestNumber - height + 1,
      block_number: hexToNumber(block.number),
      block_hash: block.hash || "",
      block_timestamp: hexToNumber(block.timestamp),
      transaction_count_in_block: txs.length,
      transaction: {
        hash: tx.hash || "",
        from: tx.from || "",
        to: tx.to || "",
        value_wei: tx.value ? BigInt(tx.value).toString() : "0",
        nonce: hexToNumber(tx.nonce),
        gas: tx.gas ? BigInt(tx.gas).toString() : "",
        gas_price: tx.gasPrice ? BigInt(tx.gasPrice).toString() : "",
        input_bytes: typeof tx.input === "string" && tx.input.startsWith("0x") ? Math.max(0, (tx.input.length - 2) / 2) : 0,
      },
      receipt: receipt.ok && receipt.result
        ? {
            status: receipt.result.status || "",
            contract_address: receipt.result.contractAddress || "",
            gas_used: receipt.result.gasUsed ? BigInt(receipt.result.gasUsed).toString() : "",
            logs: Array.isArray(receipt.result.logs) ? receipt.result.logs.length : 0,
          }
        : null,
    };
  }
  return {
    ok: false,
    latest_block_number: latestNumber,
    scanned_blocks: scanDepth,
    latest_known_tx: findLatestKnownTxEvidence(),
    error: "no_transaction_found_in_scan_window",
  };
}

async function enrichContextForQuestion(message, context) {
  if (wantsLatestTransaction(message)) {
    return {
      ...context,
      live_query: {
        ...(context.live_query || {}),
        latest_evm_transaction: await getLatestEvmTransaction(),
      },
    };
  }
  return context;
}

function llmConfigured() {
  if (!AI_INTELLIGENCE_ENABLED) return false;
  if (AI_LLM_PROVIDER === "ollama") return Boolean(AI_LLM_BASE_URL);
  return Boolean(AI_LLM_API_KEY);
}

function llmModeLabel() {
  if (!llmConfigured()) return "live-deterministic";
  return `llm:${AI_LLM_PROVIDER}`;
}

function deterministicIntelligenceAnswer(message, context) {
  const zh = hasChinese(message);
  const latestTx = context.live_query?.latest_evm_transaction;
  if (latestTx) {
    if (!latestTx.ok) {
      const known = latestTx.latest_known_tx;
      if (zh) {
        return [
          `我刚查了 YNX EVM RPC：最新块高度=${latestTx.latest_block_number ?? "-"}，向前扫描 ${latestTx.scanned_blocks ?? "-"} 个块，没有找到新的 EVM 交易。`,
          known
            ? `目前 AI/bridge 记录里最新可见链上 tx 证据是 ${known.tx_hash}，来源=${known.source}，记录时间=${known.timestamp || "-"}。`
            : "AI/bridge 记录里也没有可引用的最近 tx 证据。",
          "说明：YNX 当前出块很快，但 EVM 交易不是每个块都有；这不是预设文本，是实时 RPC 扫描结果。",
        ].join("\n");
      }
      return [
        `I queried the YNX EVM RPC: latest_block=${latestTx.latest_block_number ?? "-"}, scanned_blocks=${latestTx.scanned_blocks ?? "-"}, and found no new EVM transaction in that window.`,
        known
          ? `Latest known on-chain tx evidence in AI/bridge records: ${known.tx_hash}; source=${known.source}; recorded_at=${known.timestamp || "-"}.`
          : "No latest known tx evidence is available in AI/bridge records.",
      ].join("\n");
    }
    const tx = latestTx.transaction || {};
    const receipt = latestTx.receipt || {};
    if (zh) {
      return [
        "我刚从 YNX EVM RPC 实时查询了最近一笔链上交易：",
        "",
        `- 最新块高度：${latestTx.latest_block_number}`,
        `- 找到交易的块：${latestTx.block_number}，该块交易数=${latestTx.transaction_count_in_block}`,
        `- tx hash：${tx.hash || "-"}`,
        `- from：${tx.from || "-"}`,
        `- to：${tx.to || tx.contract_address || "-"}`,
        `- value wei：${tx.value_wei || "0"}`,
        `- input bytes：${tx.input_bytes ?? 0}`,
        `- receipt status：${receipt.status || "-"}`,
        `- gas used：${receipt.gas_used || "-"}`,
        `- logs：${receipt.logs ?? "-"}`,
        "",
        "说明：这是 YNX 9102 EVM RPC 当前可见的最近 EVM 交易，不是预设文本。",
      ].join("\n");
    }
    return [
      "I queried the YNX EVM RPC live for the latest on-chain transaction:",
      "",
      `- Latest block: ${latestTx.latest_block_number}`,
      `- Transaction block: ${latestTx.block_number}, txs_in_block=${latestTx.transaction_count_in_block}`,
      `- tx hash: ${tx.hash || "-"}`,
      `- from: ${tx.from || "-"}`,
      `- to: ${tx.to || tx.contract_address || "-"}`,
      `- value wei: ${tx.value_wei || "0"}`,
      `- input bytes: ${tx.input_bytes ?? 0}`,
      `- receipt status: ${receipt.status || "-"}`,
      `- gas used: ${receipt.gas_used || "-"}`,
      `- logs: ${receipt.logs ?? "-"}`,
    ].join("\n");
  }

  const bridgeSummary = context.bridge?.route_readiness?.summary || {};
  const healthStats = context.bridge?.health?.stats || {};
  const aiStats = context.ai?.stats || {};
  const onchain = context.ai?.onchain || {};
  const routePhases = summarizeRoutePhases(context);
  if (zh) {
    return [
      "我是 YNX Intelligence，当前直接运行在 YNX AI Gateway 上。",
      "",
      `交易/桥状态：${bridgeSummary.full_loop_tested || 0}/${bridgeSummary.routes || 0} 条 route 已完成 full-loop-tested；当前路线为 ${routePhases}。`,
      `Sepolia 闭环证据：minted deposits=${healthStats.minted_deposits ?? "-"}，released withdrawals=${healthStats.released_withdrawals ?? "-"}。`,
      `AI 链上结算：${onchain.enabled && onchain.ready ? "已开启并 ready" : "未完全 ready"}，settlement contract=${onchain.settlement_contract || "-"}，最近 tx=${onchain.last_tx_hash || "-"}。`,
      `AI 任务统计：jobs=${aiStats.total_jobs ?? 0}，vaults=${aiStats.total_vaults ?? 0}，payments=${aiStats.total_payments ?? 0}，finalized=${aiStats.by_status?.finalized ?? 0}。`,
      "",
      "产品定位建议：YNX AI 不应只叫 agent 权限与结算层，而应定位为 Intelligence Layer：链上状态分析、交易/跨链助手、AI 任务执行、机器支付、权限控制、链上结算、运维预警和开发者问答的组合。",
      "下一步最有价值的是：继续扩大 full-loop-tested 交易路线，并让服务器本地模型/外部模型持续接入实时 YNX 上下文，形成真正的链上智能运营与交易助手。",
    ].join("\n");
  }
  return [
    "I am YNX Intelligence, running inside the YNX AI Gateway.",
    "",
    `Bridge/trading status: ${bridgeSummary.full_loop_tested || 0}/${bridgeSummary.routes || 0} routes are full-loop-tested; phases: ${routePhases}.`,
    `Sepolia loop evidence: minted deposits=${healthStats.minted_deposits ?? "-"}, released withdrawals=${healthStats.released_withdrawals ?? "-"}.`,
    `AI on-chain settlement: ${onchain.enabled && onchain.ready ? "enabled and ready" : "not fully ready"}, contract=${onchain.settlement_contract || "-"}, latest tx=${onchain.last_tx_hash || "-"}.`,
    `AI stats: jobs=${aiStats.total_jobs ?? 0}, vaults=${aiStats.total_vaults ?? 0}, payments=${aiStats.total_payments ?? 0}, finalized=${aiStats.by_status?.finalized ?? 0}.`,
    "",
    "Product position: YNX AI should be the Intelligence Layer: chain-state analysis, bridge/trading assistant, AI task execution, machine payments, policy control, on-chain settlement, ops alerts, and developer Q&A.",
  ].join("\n");
}

async function callConfiguredLlm(message, context) {
  if (!llmConfigured()) return null;
  const system = [
    "You are YNX Intelligence, the official AI layer for the YNX Web4 public testnet.",
    "Use the provided live context. Be candid about testnet limits.",
    "YNX AI is broader than agent authorization: it covers chain intelligence, bridge/trading guidance, AI job execution, machine payments, policy controls, on-chain settlement, monitoring, and developer support.",
    "Answer concisely in the user's language. Keep the answer complete and under 10 short bullets.",
    "Do not output hidden chain-of-thought or <think> blocks.",
  ].join(" ");

  if (AI_LLM_PROVIDER === "ollama") {
    const response = await postJson(
      AI_LLM_BASE_URL,
      {
        model: AI_LLM_MODEL,
        stream: false,
        messages: [
          { role: "system", content: system },
          {
            role: "user",
            content: `User question:\n${message}\n\nCompact live YNX context:\n${JSON.stringify(compactIntelligenceContext(context)).slice(0, 5000)}\n\n/no_think`,
          },
        ],
        options: {
          temperature: 0.2,
          num_ctx: 4096,
          num_predict: 600,
        },
      },
      {},
      { timeout_ms: AI_LLM_TIMEOUT_MS },
    );
    if (response.status < 200 || response.status >= 300) {
      return { ok: false, error: response.payload?.error || `ollama_http_${response.status}` };
    }
    return {
      ok: true,
      text: response.payload?.message?.content || response.payload?.response || deterministicIntelligenceAnswer(message, context),
      raw_model: response.payload?.model || AI_LLM_MODEL,
    };
  }

  const payload = {
    model: AI_LLM_MODEL,
    instructions: system,
    input: [
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: `User question:\n${message}\n\nCompact live YNX context:\n${JSON.stringify(compactIntelligenceContext(context)).slice(0, 5000)}`,
          },
        ],
      },
    ],
  };
  const response = await postJson(
    AI_LLM_BASE_URL,
    payload,
    {
      authorization: `Bearer ${AI_LLM_API_KEY}`,
    },
    { timeout_ms: AI_LLM_TIMEOUT_MS },
  );
  if (response.status < 200 || response.status >= 300) {
    return { ok: false, error: response.payload?.error?.message || response.payload?.error || `llm_http_${response.status}` };
  }
  const outputText =
    response.payload.output_text ||
    (Array.isArray(response.payload.output)
      ? response.payload.output
          .flatMap((item) => (Array.isArray(item.content) ? item.content : []))
          .map((item) => item.text || "")
          .filter(Boolean)
          .join("\n")
      : "");
  return { ok: true, text: outputText || deterministicIntelligenceAnswer(message, context), raw_model: response.payload.model || AI_LLM_MODEL };
}

async function authorizeViaWeb4(req, action, options = {}) {
  const policyId = options.policy_id || "";
  if (!policyId) {
    if (AI_ENFORCE_POLICY) return { ok: false, status: 400, error: "policy_required" };
    return { ok: true };
  }
  if (!AI_WEB4_HUB_URL) return { ok: false, status: 503, error: "web4_authorizer_unavailable" };
  const sessionToken = req.headers["x-ynx-session"] || "";
  if (!sessionToken) return { ok: false, status: 401, error: "session_required" };

  const resourceHost = String(options.resource_host || req.headers.host || "")
    .trim()
    .split(":")[0]
    .toLowerCase();
  const payload = {
    policy_id: policyId,
    action,
    amount: toNumber(options.amount, 0),
    consume: options.consume !== false,
    resource_host: resourceHost,
    resource: options.resource || "",
    context: {
      request_id: options.request_id || req.headers["x-request-id"] || "",
      resource: options.resource || "",
      reason: options.reason || "",
    },
  };

  try {
    let response = await postJson(
      `${AI_WEB4_HUB_URL}/web4/authorize`,
      payload,
      {
        "x-ynx-session": sessionToken,
      }
    );

    // Backward compatibility for older hubs that only expose internal authorize.
    if (response.status === 404 || response.payload?.error === "not_found") {
      response = await postJson(
        `${AI_WEB4_HUB_URL}/web4/internal/authorize`,
        payload,
        {
          "x-ynx-session": sessionToken,
          ...(AI_WEB4_INTERNAL_TOKEN ? { "x-ynx-internal-token": AI_WEB4_INTERNAL_TOKEN } : {}),
        }
      );
    }

    if (response.status < 200 || response.status >= 300 || response.payload.ok !== true) {
      return {
        ok: false,
        status: response.status || 502,
        error: response.payload.error || "policy_authorization_failed",
      };
    }
    return { ok: true, authorization: response.payload };
  } catch {
    return { ok: false, status: 502, error: "web4_authorizer_unreachable" };
  }
}

function ensureUnique(collection, key, value) {
  return !value || !collection.some((item) => item[key] === value);
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "content-type,x-ynx-payment,x-ynx-session,x-request-id",
    });
    return res.end();
  }

  const url = new URL(req.url, "http://localhost");
  const segments = url.pathname.split("/").filter(Boolean);

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/health") {
    return json(res, 200, {
      ok: true,
      chain_id: AI_CHAIN_ID,
      service: "ynx-ai-gateway",
      enforce_policy: AI_ENFORCE_POLICY,
      has_web4_authorizer: Boolean(AI_WEB4_HUB_URL),
      intelligence: {
        enabled: AI_INTELLIGENCE_ENABLED,
        llm_configured: llmConfigured(),
        llm_provider: AI_LLM_PROVIDER,
        model: llmConfigured() ? AI_LLM_MODEL : "",
        mode: llmModeLabel(),
      },
      onchain: {
        enabled: AI_ONCHAIN_ENABLED,
        ready: onchainConfigReady(),
        rpc_configured: Boolean(AI_ONCHAIN_RPC_URL),
        signer_configured: Boolean(AI_ONCHAIN_PRIVATE_KEY),
        settlement_contract: AI_SETTLEMENT_CONTRACT || "",
        confirmations: AI_ONCHAIN_CONFIRMATIONS,
        last_tx_hash: onchainRuntime.last_tx_hash,
        last_tx_at: onchainRuntime.last_tx_at,
        last_error: onchainRuntime.last_error,
      },
      persistence: {
        debounce_ms: AI_PERSIST_DEBOUNCE_MS,
        pending: persistRuntime.pending,
        writing: persistRuntime.writing,
        writes: persistRuntime.writes,
        last_persist_at: persistRuntime.last_persist_at,
        last_error: persistRuntime.last_error,
      },
      stats: summarizeStats(),
    });
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/ready") {
    const checks = {
      persistence: fs.existsSync(AI_DATA_DIR),
      policy_authorizer: !AI_ENFORCE_POLICY || Boolean(AI_WEB4_HUB_URL),
      onchain: !AI_ONCHAIN_ENABLED || onchainConfigReady(),
    };
    return json(res, checks.persistence && checks.policy_authorizer && checks.onchain ? 200 : 503, {
      ok: checks.persistence && checks.policy_authorizer && checks.onchain,
      checks,
      data_file: AI_DATA_FILE,
      chain_id: AI_CHAIN_ID,
      enforce_policy: AI_ENFORCE_POLICY,
      onchain: {
        enabled: AI_ONCHAIN_ENABLED,
        settlement_contract: AI_SETTLEMENT_CONTRACT || "",
        confirmations: AI_ONCHAIN_CONFIRMATIONS,
        last_tx_hash: onchainRuntime.last_tx_hash,
        last_tx_at: onchainRuntime.last_tx_at,
        last_error: onchainRuntime.last_error,
      },
      persistence: {
        debounce_ms: AI_PERSIST_DEBOUNCE_MS,
        pending: persistRuntime.pending,
        writing: persistRuntime.writing,
        last_error: persistRuntime.last_error,
      },
    });
  }

  if (req.method === "GET" && url.pathname === "/ai/stats") {
    return json(res, 200, {
      ok: true,
      chain_id: AI_CHAIN_ID,
      enforce_policy: AI_ENFORCE_POLICY,
      ...summarizeStats(),
    });
  }

  if (req.method === "GET" && url.pathname === "/ai/intelligence/brief") {
    if (!AI_INTELLIGENCE_ENABLED) return json(res, 503, { ok: false, error: "intelligence_disabled" });
    const context = await collectIntelligenceContext();
    const enrichedContext = await enrichContextForQuestion(url.searchParams.get("q") || "status", context);
    return json(res, 200, {
      ok: true,
      mode: llmModeLabel(),
      answer: deterministicIntelligenceAnswer(url.searchParams.get("q") || "status", enrichedContext),
      context: enrichedContext,
    });
  }

  if (req.method === "POST" && url.pathname === "/ai/chat") {
    if (!AI_INTELLIGENCE_ENABLED) return json(res, 503, { ok: false, error: "intelligence_disabled" });
    const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const message = String(body.message || body.prompt || body.question || "").trim();
    if (!message) return json(res, 400, { ok: false, error: "message_required" });
    const context = await enrichContextForQuestion(message, await collectIntelligenceContext());
    const liveFactAnswer = wantsLiveStatusAnswer(message);
    let llm = null;
    if (!liveFactAnswer) {
      try {
        llm = await callConfiguredLlm(message, context);
      } catch (error) {
        llm = { ok: false, error: error.message || "llm_request_failed" };
      }
    }
    const usedLlm = Boolean(llm && llm.ok);
    const deterministicAnswer = deterministicIntelligenceAnswer(message, context);
    const answer = liveFactAnswer || !usedLlm ? deterministicAnswer : llm.text;
    addAudit("intelligence.chat", {
      mode: usedLlm ? llmModeLabel() : "live-deterministic",
      llm_error: llm && !llm.ok ? llm.error : "",
      message_preview: message.slice(0, 160),
    });
    persist();
    return json(res, 200, {
      ok: true,
      mode: usedLlm ? llmModeLabel() : "live-deterministic",
      model: usedLlm ? llm.raw_model || AI_LLM_MODEL : "",
      answer,
      model_answer: usedLlm && (body.include_model_answer === true || body.include_model_answer === "1") ? llm.text : undefined,
      llm_error: llm && !llm.ok ? llm.error : "",
      context: body.include_context === true || body.include_context === "1" ? context : undefined,
    });
  }

  if (req.method === "GET" && url.pathname === "/ai/audit") {
    const limit = Math.max(1, Math.min(500, parseInt(url.searchParams.get("limit") || "100", 10) || 100));
    return json(res, 200, { ok: true, items: state.audit_logs.slice(0, limit) });
  }

  if (req.method === "GET" && url.pathname === "/ai/jobs") {
    return json(res, 200, { ok: true, items: state.jobs });
  }

  if (req.method === "POST" && url.pathname === "/ai/jobs") {
    const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const vault = body.vault_id ? findVault(body.vault_id) : null;
    if (body.vault_id && !vault) return json(res, 400, { ok: false, error: "vault_not_found" });
    if (body.job_id && !ensureUnique(state.jobs, "job_id", body.job_id)) {
      return json(res, 409, { ok: false, error: "job_id_exists" });
    }
    const policyId = body.policy_id || vault?.policy_id || "";
    const auth = await authorizeViaWeb4(req, "ai.job.create", {
      policy_id: policyId,
      amount: 0,
      consume: true,
      request_id: body.job_id || "",
      resource: "ai/job/create",
      reason: "ai-job-create",
    });
    if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
    const job = createJob({ ...body, policy_id: policyId }, vault);
    if (body.onchain === true || body.onchain === "1") {
      const onchain = await createJobOnchain(job, vault, body);
      if (!onchain.ok) return json(res, 502, { ok: false, error: "onchain_job_create_failed", detail: onchain.error });
      job.onchain = onchain.onchain;
    }
    state.jobs.unshift(job);
    addAudit("job.created", { job_id: job.job_id, vault_id: job.vault_id, reward: job.reward, policy_id: policyId });
    persist();
    return json(res, 201, { ok: true, job });
  }

  if (segments[0] === "ai" && segments[1] === "jobs" && segments[2]) {
    const jobId = segments[2];
    const action = segments[3] || "";
    const job = findJob(jobId);
    if (!job) return json(res, 404, { ok: false, error: "job_not_found" });

    if (req.method === "GET" && !action) {
      return json(res, 200, { ok: true, job });
    }

    if (req.method === "POST" && action === "commit") {
      const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      if (!canTransitionJob(job, "committed")) {
        return json(res, 400, { ok: false, error: "invalid_transition", status: job.status });
      }
      const auth = await authorizeViaWeb4(req, "ai.job.commit", {
        policy_id: job.policy_id,
        amount: 0,
        consume: true,
        request_id: job.job_id,
        resource: "ai/job/commit",
        reason: "ai-job-commit",
      });
      if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
      if (job.onchain?.job_id) {
        const onchain = await commitJobOnchain(job, body);
        if (!onchain.ok) return json(res, 502, { ok: false, error: "onchain_job_commit_failed", detail: onchain.error, job });
        job.onchain = { ...job.onchain, ...onchain.onchain };
      }
      job.worker = body.worker || job.worker;
      job.result_hash = body.result_hash || job.result_hash;
      job.attestation_uri = body.attestation_uri || job.attestation_uri;
      job.status = "committed";
      job.updated_at = nowIso();
      addAudit("job.committed", { job_id: job.job_id, worker: job.worker });
      persist();
      return json(res, 200, { ok: true, job });
    }

    if (req.method === "POST" && action === "challenge") {
      const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      if (!canTransitionJob(job, "challenged")) {
        return json(res, 400, { ok: false, error: "invalid_transition", status: job.status });
      }
      const auth = await authorizeViaWeb4(req, "ai.job.challenge", {
        policy_id: body.policy_id || job.policy_id,
        amount: 0,
        consume: true,
        request_id: job.job_id,
        resource: "ai/job/challenge",
        reason: "ai-job-challenge",
      });
      if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
      if (job.onchain?.job_id) {
        const onchain = await transitionJobOnchain(job, "challenge");
        if (!onchain.ok) return json(res, 502, { ok: false, error: "onchain_job_challenge_failed", detail: onchain.error, job });
        job.onchain = { ...job.onchain, ...onchain.onchain, challenged_tx_hash: onchain.onchain.tx_hash };
      }
      job.status = "challenged";
      job.updated_at = nowIso();
      addAudit("job.challenged", { job_id: job.job_id });
      persist();
      return json(res, 200, { ok: true, job });
    }

    if (req.method === "POST" && action === "finalize") {
      const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const nextStatus = body.status === "slashed" ? "slashed" : "finalized";
      if (!canTransitionJob(job, nextStatus)) {
        return json(res, 400, { ok: false, error: "invalid_transition", status: job.status });
      }

      const finalizeAuth = await authorizeViaWeb4(req, "ai.job.finalize", {
        policy_id: body.policy_id || job.policy_id,
        amount: 0,
        consume: true,
        request_id: job.job_id,
        resource: "ai/job/finalize",
        reason: "ai-job-finalize",
      });
      if (!finalizeAuth.ok) return json(res, finalizeAuth.status, { ok: false, error: finalizeAuth.error });

      if (job.onchain?.job_id) {
        const onchainAction = nextStatus === "slashed" ? "slash" : "finalize";
        const onchain = await transitionJobOnchain(job, onchainAction);
        if (!onchain.ok) {
          return json(res, 502, {
            ok: false,
            error: `onchain_job_${onchainAction}_failed`,
            detail: onchain.error,
            job,
          });
        }
        job.onchain = {
          ...job.onchain,
          ...onchain.onchain,
          [`${onchainAction}_tx_hash`]: onchain.onchain.tx_hash,
        };
      }

      job.status = nextStatus;
      job.finalized_at = nowIso();
      job.updated_at = nowIso();

      if (job.status === "finalized" && job.vault_id && toNumber(job.reward, 0) > 0) {
        const vault = findVault(job.vault_id);
        const paymentAuth = await authorizeViaWeb4(req, "ai.payment.charge", {
          policy_id: vault?.policy_id || body.policy_id || job.policy_id,
          amount: toNumber(job.reward, 0),
          consume: true,
          request_id: job.job_id,
          resource: "ai/job/reward",
          reason: "ai-job-reward",
        });
        if (!paymentAuth.ok) {
          addAudit("job.reward.authorization_failed", {
            job_id: job.job_id,
            vault_id: job.vault_id,
            error: paymentAuth.error,
          });
          persist();
          return json(res, paymentAuth.status, { ok: false, error: paymentAuth.error, job });
        }

        const charged = chargeVault(vault, toNumber(job.reward, 0), {
          reason: "ai-job-reward",
          request_id: job.job_id,
          resource: "ai/job/reward",
        });
        if (charged.ok) {
          job.payout_payment_id = charged.payment.payment_id;
          addAudit("job.reward.settled", {
            job_id: job.job_id,
            vault_id: job.vault_id,
            payment_id: charged.payment.payment_id,
            amount: charged.payment.amount,
          });
        } else {
          addAudit("job.reward.failed", { job_id: job.job_id, vault_id: job.vault_id, error: charged.error });
          persist();
          return json(res, 400, { ok: false, error: charged.error, job });
        }
      }

      addAudit("job.finalized", { job_id: job.job_id, status: job.status });
      persist();
      return json(res, 200, { ok: true, job });
    }
  }

  if (req.method === "GET" && url.pathname === "/ai/vaults") {
    return json(res, 200, { ok: true, items: state.vaults });
  }

  if (req.method === "POST" && url.pathname === "/ai/vaults") {
    const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (!body.owner) return json(res, 400, { ok: false, error: "owner_required" });
    if (body.vault_id && !ensureUnique(state.vaults, "vault_id", body.vault_id)) {
      return json(res, 409, { ok: false, error: "vault_id_exists" });
    }
    const auth = await authorizeViaWeb4(req, "ai.vault.create", {
      policy_id: body.policy_id || "",
      amount: 0,
      consume: true,
      request_id: body.vault_id || "",
      resource: "ai/vault/create",
      reason: "ai-vault-create",
    });
    if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
    const vault = createVault(body);
    if (body.onchain === true || body.onchain === "1") {
      const onchain = await createVaultOnchain(vault, body);
      if (!onchain.ok) return json(res, 502, { ok: false, error: "onchain_vault_create_failed", detail: onchain.error });
      vault.onchain = onchain.onchain;
    }
    state.vaults.unshift(vault);
    addAudit("vault.created", { vault_id: vault.vault_id, owner: vault.owner, balance: vault.balance, policy_id: vault.policy_id });
    persist();
    return json(res, 201, { ok: true, vault });
  }

  if (segments[0] === "ai" && segments[1] === "vaults" && segments[2]) {
    const vaultId = segments[2];
    const action = segments[3] || "";
    const vault = findVault(vaultId);
    if (!vault) return json(res, 404, { ok: false, error: "vault_not_found" });

    if (req.method === "GET" && !action) return json(res, 200, { ok: true, vault });

    if (req.method === "POST" && action === "deposit") {
      const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const amount = toNumber(body.amount, 0);
      if (amount <= 0) return json(res, 400, { ok: false, error: "invalid_amount" });
      const auth = await authorizeViaWeb4(req, "ai.vault.deposit", {
        policy_id: vault.policy_id,
        amount: 0,
        consume: true,
        request_id: vault.vault_id,
        resource: "ai/vault/deposit",
        reason: "ai-vault-deposit",
      });
      if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
      if (vault.onchain?.vault_id && (body.onchain === true || body.onchain === "1" || body.onchain_value_wei || body.amount_wei)) {
        const onchain = await depositVaultOnchain(vault, body);
        if (!onchain.ok) return json(res, 502, { ok: false, error: "onchain_vault_deposit_failed", detail: onchain.error, vault });
        vault.onchain = { ...vault.onchain, last_deposit_tx_hash: onchain.onchain.tx_hash };
      }
      vault.balance += amount;
      vault.updated_at = nowIso();
      addAudit("vault.deposited", { vault_id: vault.vault_id, amount });
      persist();
      return json(res, 200, { ok: true, vault });
    }

    if (req.method === "POST" && action === "set-status") {
      const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const next = body.status;
      if (!["active", "paused", "revoked"].includes(next)) {
        return json(res, 400, { ok: false, error: "invalid_status" });
      }
      const auth = await authorizeViaWeb4(req, "ai.vault.admin", {
        policy_id: vault.policy_id,
        amount: 0,
        consume: true,
        request_id: vault.vault_id,
        resource: "ai/vault/status",
        reason: "ai-vault-status",
      });
      if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
      vault.status = next;
      vault.updated_at = nowIso();
      addAudit("vault.status.changed", { vault_id: vault.vault_id, status: next });
      persist();
      return json(res, 200, { ok: true, vault });
    }
  }

  if (req.method === "GET" && url.pathname === "/ai/payments") {
    return json(res, 200, { ok: true, items: state.payments });
  }

  if (req.method === "POST" && url.pathname === "/ai/payments/quote") {
    const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const quote = quoteFromRequest(body);
    return json(res, 200, {
      ok: true,
      quote: {
        quote_id: randomId("quote"),
        amount: quote.amount,
        units: quote.units,
        unit_price: quote.unit_price,
        denom: AI_X402_DENOM,
        resource: body.resource || "generic",
      },
    });
  }

  if (req.method === "POST" && url.pathname === "/ai/payments/charge") {
    const body = await parseBody(req, AI_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const vault = findVault(body.vault_id || "");
    const amount = toNumber(body.amount, 0);
    const auth = await authorizeViaWeb4(req, "ai.payment.charge", {
      policy_id: vault?.policy_id || body.policy_id || "",
      amount,
      consume: true,
      request_id: body.request_id || "",
      resource: body.resource || "",
      reason: body.reason || "api-charge",
    });
    if (!auth.ok) return json(res, auth.status, { ok: false, error: auth.error });
    const result = chargeVault(vault, amount, {
      request_id: body.request_id || "",
      reason: body.reason || "api-charge",
      resource: body.resource || "",
      denom: body.denom || AI_X402_DENOM,
    });
    if (!result.ok) return json(res, 400, { ok: false, error: result.error });
    addAudit("payment.charged", {
      payment_id: result.payment.payment_id,
      vault_id: result.payment.vault_id,
      amount: result.payment.amount,
      resource: result.payment.resource,
    });
    persist();
    return json(res, 200, { ok: true, payment: result.payment, vault });
  }

  if (segments[0] === "ai" && segments[1] === "payments" && segments[2] && req.method === "GET") {
    const payment = state.payments.find((item) => item.payment_id === segments[2]);
    if (!payment) return json(res, 404, { ok: false, error: "payment_not_found" });
    return json(res, 200, { ok: true, payment });
  }

  if (req.method === "GET" && url.pathname === "/x402/resource") {
    const resource = url.searchParams.get("resource") || "default-resource";
    const units = Math.max(1, parseInt(url.searchParams.get("units") || "1", 10) || 1);
    const requiredAmount = units * AI_X402_UNIT_PRICE;
    const paymentId = req.headers["x-ynx-payment"] || "";
    if (!paymentId) {
      return json(
        res,
        402,
        {
          ok: false,
          error: "payment_required",
          requirement: {
            protocol: "x402",
            resource,
            amount: requiredAmount,
            denom: AI_X402_DENOM,
            settle_endpoint: "/ai/payments/charge",
          },
        },
        { "x-ynx-payment-required": "1" }
      );
    }
    const payment = state.payments.find((item) => item.payment_id === paymentId);
    if (!payment || payment.status !== "settled") {
      return json(res, 402, { ok: false, error: "invalid_payment" }, { "x-ynx-payment-required": "1" });
    }
    if (payment.resource && payment.resource !== resource) {
      return json(res, 402, { ok: false, error: "invalid_payment_resource" }, { "x-ynx-payment-required": "1" });
    }
    if (toNumber(payment.amount, 0) < requiredAmount) {
      return json(res, 402, { ok: false, error: "payment_amount_insufficient" }, { "x-ynx-payment-required": "1" });
    }
    return json(res, 200, {
      ok: true,
      resource,
      payment_id: payment.payment_id,
      delivered_at: nowIso(),
      payload: `resource:${resource}:delivered`,
    });
  }

  return json(res, 404, { ok: false, error: "not_found" });
});

server.listen(AI_GATEWAY_PORT, () => {
  console.log(`YNX AI gateway listening on :${AI_GATEWAY_PORT}`);
});

async function gracefulShutdown(signal) {
  console.log(`[ai-gateway] received ${signal}, flushing state...`);
  if (persistRuntime.timer) {
    clearTimeout(persistRuntime.timer);
    persistRuntime.timer = null;
  }
  try {
    if (persistRuntime.pending || persistRuntime.writing) await flushPersist();
    else persistSync();
  } catch (error) {
    console.error("[ai-gateway] graceful flush failed:", error);
  }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1500).unref();
}

process.on("SIGINT", () => {
  void gracefulShutdown("SIGINT");
});
process.on("SIGTERM", () => {
  void gracefulShutdown("SIGTERM");
});
