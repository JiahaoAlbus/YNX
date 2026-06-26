const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
const crypto = require("crypto");
const net = require("net");

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
if (process.env.WEB4_ENV_FILE) envCandidates.push(process.env.WEB4_ENV_FILE);
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
  const allowOrigin = resolveCorsOrigin(origin, WEB4_CORS_ALLOWED_ORIGINS);
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
  const status = body.__parse_error === "payload_too_large" ? 413 : 400;
  json(res, status, { ok: false, error: body.__parse_error });
  return false;
}

function requestRaw(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(targetUrl);
    const transport = url.protocol === "https:" ? https : http;
    const body = options.body === undefined || options.body === null ? "" : String(options.body);
    const req = transport.request(
      {
        method: options.method || "GET",
        hostname: url.hostname,
        port: url.port || (url.protocol === "https:" ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        timeout: options.timeout_ms || 10000,
        headers: {
          ...(body ? { "content-length": Buffer.byteLength(body) } : {}),
          ...(options.headers || {}),
        },
      },
      (upstream) => {
        const chunks = [];
        let size = 0;
        const maxBytes = options.max_response_bytes || 65536;
        upstream.on("data", (chunk) => {
          if (size >= maxBytes) return;
          const remaining = maxBytes - size;
          const slice = chunk.length > remaining ? chunk.subarray(0, remaining) : chunk;
          chunks.push(slice);
          size += slice.length;
        });
        upstream.on("end", () => {
          resolve({
            status: upstream.statusCode || 0,
            headers: upstream.headers,
            body: Buffer.concat(chunks).toString("utf8"),
            truncated: size >= maxBytes,
          });
        });
      }
    );
    req.on("timeout", () => req.destroy(new Error("upstream_timeout")));
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function nowIso() {
  return new Date().toISOString();
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function randomId(prefix) {
  return `${prefix}_${crypto.randomBytes(8).toString("hex")}`;
}

function hashSecret(input) {
  return crypto.createHash("sha256").update(String(input)).digest("hex");
}

function readHeader(req, name) {
  const value = req.headers[name];
  if (Array.isArray(value)) return value[0] || "";
  return value || "";
}

function timingSafeEqualHex(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  if (!/^[0-9a-f]{64}$/i.test(a) || !/^[0-9a-f]{64}$/i.test(b)) return false;
  return crypto.timingSafeEqual(Buffer.from(a, "hex"), Buffer.from(b, "hex"));
}

function secretMatchesHash(secret, expectedHash) {
  if (!secret || !expectedHash) return false;
  return timingSafeEqualHex(hashSecret(secret), String(expectedHash));
}

function secretEquals(candidate, expected) {
  if (!candidate || !expected) return false;
  return timingSafeEqualHex(hashSecret(candidate), hashSecret(expected));
}

function toNumber(value, fallback = 0) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
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

function uniqueStrings(items) {
  return [...new Set((Array.isArray(items) ? items : []).filter((item) => typeof item === "string" && item.trim()))];
}

const DEFAULT_ALLOWED_ACTIONS = [
  "identity.create",
  "agent.create",
  "agent.modify",
  "agent.replicate",
  "intent.create",
  "intent.claim",
  "intent.challenge",
  "intent.finalize",
  "ai.vault.create",
  "ai.vault.read",
  "ai.vault.deposit",
  "ai.vault.admin",
  "ai.job.create",
  "ai.job.read",
  "ai.job.commit",
  "ai.job.challenge",
  "ai.job.finalize",
  "ai.audit.read",
  "ai.forensics.case.read",
  "ai.forensics.case.create",
  "ai.forensics.case.review",
  "ai.trace.report",
  "ai.payment.read",
  "ai.payment.charge",
  "tool.execute",
];
const DEFAULT_ALLOWED_SERVICE_HOSTS = ["*"];

function normalizeState(loaded) {
  const source = loaded && typeof loaded === "object" ? loaded : {};
  return {
    identities: Array.isArray(source.identities) ? source.identities : [],
    agents: Array.isArray(source.agents) ? source.agents : [],
    intents: Array.isArray(source.intents) ? source.intents : [],
    claims: Array.isArray(source.claims) ? source.claims : [],
    policies: Array.isArray(source.policies) ? source.policies : [],
    sessions: Array.isArray(source.sessions) ? source.sessions : [],
    tools: Array.isArray(source.tools) ? source.tools : [],
    tool_calls: Array.isArray(source.tool_calls) ? source.tool_calls : [],
    wallet_bootstraps: Array.isArray(source.wallet_bootstraps) ? source.wallet_bootstraps : [],
    audit_logs: Array.isArray(source.audit_logs) ? source.audit_logs : [],
  };
}

const WEB4_PORT = parseInt(process.env.WEB4_PORT || "8091", 10);
const WEB4_CHAIN_ID = process.env.WEB4_CHAIN_ID || "ynx_9102-1";
const WEB4_TRACK = process.env.WEB4_TRACK || "v2-web4";
const WEB4_DATA_DIR = process.env.WEB4_DATA_DIR || path.resolve(__dirname, "data");
const WEB4_DATA_FILE = path.join(WEB4_DATA_DIR, "state.json");
const WEB4_INTENT_TTL_SEC = parseInt(process.env.WEB4_INTENT_TTL_SEC || "900", 10);
const WEB4_ENFORCE_POLICY = process.env.WEB4_ENFORCE_POLICY !== "0";
const WEB4_DEFAULT_SESSION_TTL_SEC = parseInt(process.env.WEB4_DEFAULT_SESSION_TTL_SEC || "900", 10);
const WEB4_DEFAULT_MAX_OPS = parseInt(process.env.WEB4_DEFAULT_MAX_OPS || "50", 10);
const WEB4_DEFAULT_MAX_SPEND = Number(process.env.WEB4_DEFAULT_MAX_SPEND || "10000");
const WEB4_AUDIT_LIMIT = parseInt(process.env.WEB4_AUDIT_LIMIT || "5000", 10);
const WEB4_BODY_LIMIT_BYTES = parseInt(process.env.WEB4_BODY_LIMIT_BYTES || "1048576", 10);
const WEB4_SERVER_HEADERS_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.WEB4_SERVER_HEADERS_TIMEOUT_MS || "15000", 10) || 15000,
);
const WEB4_SERVER_REQUEST_TIMEOUT_MS = Math.max(
  WEB4_SERVER_HEADERS_TIMEOUT_MS,
  parseInt(process.env.WEB4_SERVER_REQUEST_TIMEOUT_MS || "30000", 10) || 30000,
);
const WEB4_SERVER_KEEP_ALIVE_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.WEB4_SERVER_KEEP_ALIVE_TIMEOUT_MS || "5000", 10) || 5000,
);
const WEB4_SERVER_MAX_REQUESTS_PER_SOCKET = Math.max(
  1,
  parseInt(process.env.WEB4_SERVER_MAX_REQUESTS_PER_SOCKET || "100", 10) || 100,
);
const WEB4_SERVER_MAX_HEADERS_COUNT = Math.max(
  1,
  parseInt(process.env.WEB4_SERVER_MAX_HEADERS_COUNT || "100", 10) || 100,
);
const WEB4_CORS_ALLOWED_ORIGINS = parseAllowedOrigins(process.env.WEB4_CORS_ALLOWED_ORIGINS || "*");
const WEB4_INTERNAL_TOKEN = process.env.WEB4_INTERNAL_TOKEN || "";
const WEB4_MAX_IDENTITIES = parseInt(process.env.WEB4_MAX_IDENTITIES || "200000", 10);
const WEB4_MAX_AGENTS = parseInt(process.env.WEB4_MAX_AGENTS || "200000", 10);
const WEB4_MAX_INTENTS = parseInt(process.env.WEB4_MAX_INTENTS || "200000", 10);
const WEB4_MAX_CLAIMS = parseInt(process.env.WEB4_MAX_CLAIMS || "200000", 10);
const WEB4_MAX_POLICIES = parseInt(process.env.WEB4_MAX_POLICIES || "100000", 10);
const WEB4_MAX_SESSIONS = parseInt(process.env.WEB4_MAX_SESSIONS || "300000", 10);
const WEB4_MAX_TOOLS = parseInt(process.env.WEB4_MAX_TOOLS || "50000", 10);
const WEB4_MAX_TOOL_CALLS = parseInt(process.env.WEB4_MAX_TOOL_CALLS || "500000", 10);
const WEB4_MAX_BOOTSTRAPS = parseInt(process.env.WEB4_MAX_BOOTSTRAPS || "100000", 10);
const WEB4_PERSIST_DEBOUNCE_MS = Math.max(0, parseInt(process.env.WEB4_PERSIST_DEBOUNCE_MS || "200", 10));
const WEB4_TOOL_TIMEOUT_MS = Math.max(1000, parseInt(process.env.WEB4_TOOL_TIMEOUT_MS || "10000", 10) || 10000);
const WEB4_TOOL_RESPONSE_LIMIT_BYTES = Math.max(1024, parseInt(process.env.WEB4_TOOL_RESPONSE_LIMIT_BYTES || "65536", 10) || 65536);
const WEB4_ALLOW_PRIVATE_TOOL_URLS = process.env.WEB4_ALLOW_PRIVATE_TOOL_URLS === "1";

if (!fs.existsSync(WEB4_DATA_DIR)) fs.mkdirSync(WEB4_DATA_DIR, { recursive: true });

let state = normalizeState({});

if (fs.existsSync(WEB4_DATA_FILE)) {
  try {
    const loaded = JSON.parse(fs.readFileSync(WEB4_DATA_FILE, "utf8"));
    state = normalizeState(loaded);
  } catch {
    state = normalizeState({});
  }
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
  if (WEB4_MAX_IDENTITIES > 0 && state.identities.length > WEB4_MAX_IDENTITIES) state.identities = state.identities.slice(0, WEB4_MAX_IDENTITIES);
  if (WEB4_MAX_AGENTS > 0 && state.agents.length > WEB4_MAX_AGENTS) state.agents = state.agents.slice(0, WEB4_MAX_AGENTS);
  if (WEB4_MAX_INTENTS > 0 && state.intents.length > WEB4_MAX_INTENTS) state.intents = state.intents.slice(0, WEB4_MAX_INTENTS);
  if (WEB4_MAX_CLAIMS > 0 && state.claims.length > WEB4_MAX_CLAIMS) state.claims = state.claims.slice(0, WEB4_MAX_CLAIMS);
  if (WEB4_MAX_POLICIES > 0 && state.policies.length > WEB4_MAX_POLICIES) state.policies = state.policies.slice(0, WEB4_MAX_POLICIES);
  if (WEB4_MAX_SESSIONS > 0 && state.sessions.length > WEB4_MAX_SESSIONS) state.sessions = state.sessions.slice(0, WEB4_MAX_SESSIONS);
  if (WEB4_MAX_TOOLS > 0 && state.tools.length > WEB4_MAX_TOOLS) state.tools = state.tools.slice(0, WEB4_MAX_TOOLS);
  if (WEB4_MAX_TOOL_CALLS > 0 && state.tool_calls.length > WEB4_MAX_TOOL_CALLS) state.tool_calls = state.tool_calls.slice(0, WEB4_MAX_TOOL_CALLS);
  if (WEB4_MAX_BOOTSTRAPS > 0 && state.wallet_bootstraps.length > WEB4_MAX_BOOTSTRAPS) {
    state.wallet_bootstraps = state.wallet_bootstraps.slice(0, WEB4_MAX_BOOTSTRAPS);
  }
  if (WEB4_AUDIT_LIMIT > 0 && state.audit_logs.length > WEB4_AUDIT_LIMIT) state.audit_logs = state.audit_logs.slice(0, WEB4_AUDIT_LIMIT);
}

function persistSync() {
  trimStateForRetention();
  atomicWriteJson(WEB4_DATA_FILE, state);
  persistRuntime.writes += 1;
  persistRuntime.last_persist_at = nowIso();
}

async function flushPersist() {
  if (!persistRuntime.pending || persistRuntime.writing) return;
  persistRuntime.writing = true;
  persistRuntime.pending = false;
  try {
    trimStateForRetention();
    await atomicWriteJsonAsync(WEB4_DATA_FILE, state);
    persistRuntime.writes += 1;
    persistRuntime.last_persist_at = nowIso();
    persistRuntime.last_error = "";
  } catch (error) {
    persistRuntime.last_error = error && error.message ? error.message : "persist_failed";
    console.error("[web4-hub] persist error:", error);
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
  if (WEB4_PERSIST_DEBOUNCE_MS === 0) {
    void flushPersist();
    return;
  }
  if (persistRuntime.timer) return;
  persistRuntime.timer = setTimeout(() => {
    persistRuntime.timer = null;
    void flushPersist();
  }, WEB4_PERSIST_DEBOUNCE_MS);
}

function findIntent(intentId) {
  return state.intents.find((item) => item.intent_id === intentId);
}

function findAgent(agentId) {
  return state.agents.find((item) => item.agent_id === agentId);
}

function findPolicy(policyId) {
  return state.policies.find((item) => item.policy_id === policyId);
}

function findTool(toolId) {
  return state.tools.find((item) => item.tool_id === toolId);
}

function addAudit(event, payload) {
  state.audit_logs.unshift({
    audit_id: randomId("audit"),
    event,
    payload,
    created_at: nowIso(),
  });
  if (state.audit_logs.length > WEB4_AUDIT_LIMIT) {
    state.audit_logs = state.audit_logs.slice(0, WEB4_AUDIT_LIMIT);
  }
}

function transitionIntent(intent, nextStatus) {
  const allowed = {
    created: ["claimed", "expired", "cancelled"],
    claimed: ["challenged", "finalized", "failed"],
    challenged: ["finalized", "failed"],
    finalized: [],
    failed: [],
    expired: [],
    cancelled: [],
  };
  const current = intent.status;
  if (!allowed[current] || !allowed[current].includes(nextStatus)) return false;
  intent.status = nextStatus;
  intent.updated_at = nowIso();
  return true;
}

function summarizeStats() {
  const intentByStatus = state.intents.reduce((acc, item) => {
    acc[item.status] = (acc[item.status] || 0) + 1;
    return acc;
  }, {});
  const agentByStatus = state.agents.reduce((acc, item) => {
    acc[item.status] = (acc[item.status] || 0) + 1;
    return acc;
  }, {});
  const policyByStatus = state.policies.reduce((acc, item) => {
    acc[item.status] = (acc[item.status] || 0) + 1;
    return acc;
  }, {});
  return {
    identities: state.identities.length,
    agents: state.agents.length,
    intents: state.intents.length,
    claims: state.claims.length,
    policies: state.policies.length,
    sessions_active: state.sessions.filter((item) => item.status === "active").length,
    tools: state.tools.length,
    tool_calls: state.tool_calls.length,
    bootstraps: state.wallet_bootstraps.length,
    intent_by_status: intentByStatus,
    agent_by_status: agentByStatus,
    policy_by_status: policyByStatus,
  };
}

function resetPolicyDaily(policy) {
  const key = todayKey();
  if (policy.spent_day_key !== key) {
    policy.spent_day_key = key;
    policy.spent_day = 0;
  }
}

function verifyOwner(req, policy) {
  return secretMatchesHash(readHeader(req, "x-ynx-owner"), policy.owner_secret_hash);
}

function findSessionByToken(token) {
  if (!token) return null;
  const tokenHash = hashSecret(token);
  return state.sessions.find((item) => timingSafeEqualHex(tokenHash, String(item.token_hash || ""))) || null;
}

function validateSessionForAction(session, action, amount) {
  if (!session) return { ok: false, error: "session_required" };
  if (session.status !== "active") return { ok: false, error: "session_inactive" };
  if (new Date(session.expires_at).getTime() <= Date.now()) return { ok: false, error: "session_expired" };
  if (!allowsPattern(session.capabilities, action)) {
    return { ok: false, error: "capability_denied" };
  }
  if (session.ops_used >= session.max_ops) return { ok: false, error: "session_ops_exceeded" };
  if (session.spend_used + amount > session.max_spend) return { ok: false, error: "session_spend_exceeded" };
  return { ok: true };
}

function allowsPattern(patterns, value) {
  if (!Array.isArray(patterns) || patterns.length === 0) return false;
  if (patterns.includes("*") || patterns.includes(value)) return true;
  return patterns.some((pattern) => {
    if (typeof pattern !== "string" || !pattern.endsWith("*")) return false;
    return value.startsWith(pattern.slice(0, -1));
  });
}

function validatePolicyAction(policy, amount) {
  if (!policy) return { ok: false, error: "policy_not_found" };
  if (policy.status !== "active") return { ok: false, error: `policy_${policy.status}` };
  resetPolicyDaily(policy);
  if (policy.max_total_spend > 0 && policy.spent_total + amount > policy.max_total_spend) {
    return { ok: false, error: "policy_total_spend_exceeded" };
  }
  if (policy.max_daily_spend > 0 && policy.spent_day + amount > policy.max_daily_spend) {
    return { ok: false, error: "policy_daily_spend_exceeded" };
  }
  return { ok: true };
}

function applySpend(policy, session, amount) {
  if (policy) {
    resetPolicyDaily(policy);
    policy.spent_total += amount;
    policy.spent_day += amount;
    policy.updated_at = nowIso();
  }
  if (session) {
    session.ops_used += 1;
    session.spend_used += amount;
    session.updated_at = nowIso();
  }
}

function policyGuard(req, action, policyId, amount = 0) {
  if (!policyId) {
    if (WEB4_ENFORCE_POLICY) return { ok: false, status: 400, error: "policy_required" };
    return { ok: true, policy: null, session: null };
  }
  const policy = findPolicy(policyId);
  const policyCheck = validatePolicyAction(policy, amount);
  if (!policyCheck.ok) return { ok: false, status: 403, error: policyCheck.error };
  if (policy.allowed_actions.length && !allowsPattern(policy.allowed_actions, action)) {
    return { ok: false, status: 403, error: "policy_action_denied" };
  }
  const token = readHeader(req, "x-ynx-session");
  if (!token) return { ok: false, status: 401, error: "session_required" };
  const session = findSessionByToken(token);
  if (!session || session.policy_id !== policyId) return { ok: false, status: 401, error: "invalid_session" };
  const sessionCheck = validateSessionForAction(session, action, amount);
  if (!sessionCheck.ok) return { ok: false, status: 403, error: sessionCheck.error };
  return { ok: true, policy, session };
}

function createPolicy(body) {
  const ownerSecret = body.owner_secret || `own_${crypto.randomBytes(16).toString("hex")}`;
  const policy = {
    policy_id: body.policy_id || randomId("policy"),
    owner: body.owner || "",
    name: body.name || "default-policy",
    status: "active",
    allowed_actions: uniqueStrings(
      Array.isArray(body.allowed_actions) && body.allowed_actions.length
        ? body.allowed_actions
        : DEFAULT_ALLOWED_ACTIONS
    ),
    allowed_tools: uniqueStrings(Array.isArray(body.allowed_tools) && body.allowed_tools.length ? body.allowed_tools : ["*"]),
    allowed_tool_hosts: uniqueStrings(
      Array.isArray(body.allowed_tool_hosts) && body.allowed_tool_hosts.length ? body.allowed_tool_hosts : ["*"]
    ).map((item) => item.toLowerCase()),
    allowed_service_hosts: uniqueStrings(
      Array.isArray(body.allowed_service_hosts) && body.allowed_service_hosts.length ? body.allowed_service_hosts : DEFAULT_ALLOWED_SERVICE_HOSTS
    ).map((item) => item.toLowerCase()),
    max_total_spend: toNumber(body.max_total_spend, 0),
    max_daily_spend: toNumber(body.max_daily_spend, 0),
    max_children: Math.max(0, parseInt(body.max_children || "0", 10) || 0),
    replicate_cooldown_sec: Math.max(0, parseInt(body.replicate_cooldown_sec || "60", 10) || 60),
    session_ttl_sec: Math.max(30, parseInt(body.session_ttl_sec || WEB4_DEFAULT_SESSION_TTL_SEC, 10) || WEB4_DEFAULT_SESSION_TTL_SEC),
    default_session_max_ops: Math.max(1, parseInt(body.default_session_max_ops || WEB4_DEFAULT_MAX_OPS, 10) || WEB4_DEFAULT_MAX_OPS),
    default_session_max_spend: toNumber(body.default_session_max_spend, WEB4_DEFAULT_MAX_SPEND),
    spent_total: 0,
    spent_day: 0,
    spent_day_key: todayKey(),
    owner_secret_hash: hashSecret(ownerSecret),
    created_at: nowIso(),
    updated_at: nowIso(),
  };
  return { policy, owner_secret: ownerSecret };
}

function sanitizeHeaders(headers) {
  const out = {};
  if (!headers || typeof headers !== "object" || Array.isArray(headers)) return out;
  for (const [key, value] of Object.entries(headers)) {
    const normalizedKey = key.toLowerCase();
    if (!/^[a-z0-9-]+$/.test(normalizedKey)) continue;
    if (["host", "connection", "content-length", "transfer-encoding"].includes(normalizedKey)) continue;
    if (typeof value === "string" && value.length <= 4096) out[normalizedKey] = value;
  }
  return out;
}

function isPrivateHost(hostname) {
  const host = hostname.toLowerCase();
  if (host === "localhost" || host.endsWith(".localhost")) return true;
  const ipType = net.isIP(host);
  if (ipType === 4) {
    const parts = host.split(".").map((part) => Number(part));
    return (
      parts[0] === 10 ||
      parts[0] === 127 ||
      (parts[0] === 169 && parts[1] === 254) ||
      (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
      (parts[0] === 192 && parts[1] === 168)
    );
  }
  if (ipType === 6) return host === "::1" || host.startsWith("fc") || host.startsWith("fd") || host.startsWith("fe80");
  return false;
}

function normalizeTool(body) {
  const baseUrl = new URL(String(body.base_url || ""));
  if (!["http:", "https:"].includes(baseUrl.protocol)) throw new Error("invalid_base_url_protocol");
  if (baseUrl.username || baseUrl.password) throw new Error("base_url_credentials_not_allowed");
  if (!WEB4_ALLOW_PRIVATE_TOOL_URLS && isPrivateHost(baseUrl.hostname)) throw new Error("private_tool_url_not_allowed");
  return {
    tool_id: body.tool_id || randomId("tool"),
    name: body.name || body.tool_id || "external-tool",
    description: body.description || "",
    kind: body.kind || "http",
    status: "active",
    base_url: baseUrl.origin,
    allowed_methods: uniqueStrings(Array.isArray(body.allowed_methods) && body.allowed_methods.length ? body.allowed_methods : ["GET", "POST"]).map((item) =>
      item.toUpperCase()
    ),
    allowed_paths: uniqueStrings(Array.isArray(body.allowed_paths) && body.allowed_paths.length ? body.allowed_paths : ["/"]),
    default_headers: sanitizeHeaders(body.default_headers || {}),
    cost_per_call: toNumber(body.cost_per_call, 0),
    owner: body.owner || "",
    metadata: body.metadata && typeof body.metadata === "object" ? body.metadata : {},
    created_at: nowIso(),
    updated_at: nowIso(),
  };
}

function pathAllowed(patterns, pathname) {
  return patterns.some((pattern) => {
    if (pattern === "*" || pattern === "/*") return true;
    if (pattern.endsWith("*")) return pathname.startsWith(pattern.slice(0, -1));
    return pathname === pattern;
  });
}

function validateToolCall(policy, tool, body) {
  if (!tool) return { ok: false, status: 404, error: "tool_not_found" };
  if (tool.status !== "active") return { ok: false, status: 403, error: `tool_${tool.status}` };
  if (policy) {
    if (!allowsPattern(policy.allowed_tools || ["*"], tool.tool_id)) return { ok: false, status: 403, error: "policy_tool_denied" };
    const host = new URL(tool.base_url).hostname.toLowerCase();
    if (!allowsPattern(policy.allowed_tool_hosts || ["*"], host)) return { ok: false, status: 403, error: "policy_tool_host_denied" };
  }
  const method = String(body.method || "GET").toUpperCase();
  if (!tool.allowed_methods.includes(method)) return { ok: false, status: 403, error: "tool_method_denied" };
  const rawPath = String(body.path || "/");
  if (!rawPath.startsWith("/")) return { ok: false, status: 400, error: "tool_path_must_be_absolute" };
  const target = new URL(rawPath, tool.base_url);
  if (target.origin !== new URL(tool.base_url).origin) return { ok: false, status: 403, error: "tool_origin_escape_denied" };
  if (!pathAllowed(tool.allowed_paths, target.pathname)) return { ok: false, status: 403, error: "tool_path_denied" };
  return { ok: true, method, target };
}

function hashBody(body) {
  return crypto.createHash("sha256").update(String(body || "")).digest("hex");
}

function issueSession(policy, body) {
  const ttlSec = Math.max(30, parseInt(body.ttl_sec || policy.session_ttl_sec, 10) || policy.session_ttl_sec);
  const expiresAt = new Date(Date.now() + ttlSec * 1000).toISOString();
  const token = body.token || `ses_${crypto.randomBytes(18).toString("hex")}`;
  const capabilities = uniqueStrings(
    Array.isArray(body.capabilities) && body.capabilities.length
      ? body.capabilities
      : policy.allowed_actions
  );
  const session = {
    session_id: body.session_id || randomId("session"),
    policy_id: policy.policy_id,
    status: "active",
    capabilities,
    token_hash: hashSecret(token),
    expires_at: expiresAt,
    max_ops: Math.max(1, parseInt(body.max_ops || policy.default_session_max_ops, 10) || policy.default_session_max_ops),
    max_spend: toNumber(body.max_spend, policy.default_session_max_spend),
    ops_used: 0,
    spend_used: 0,
    created_at: nowIso(),
    updated_at: nowIso(),
  };
  return { session, token };
}

function authorizeAction(req, body, options = {}) {
  if (!body || typeof body !== "object") return { ok: false, status: 400, error: "invalid_body" };
  if (!body.policy_id) return { ok: false, status: 400, error: "policy_id_required" };
  if (!body.action) return { ok: false, status: 400, error: "action_required" };

  const amount = toNumber(body.amount, 0);
  const guard = policyGuard(req, body.action, body.policy_id, amount);
  if (!guard.ok) return { ok: false, status: guard.status, error: guard.error };

  const resourceHost = String(body.resource_host || body.host || "").trim().toLowerCase();
  if (resourceHost && guard.policy) {
    if (!allowsPattern(guard.policy.allowed_service_hosts || DEFAULT_ALLOWED_SERVICE_HOSTS, resourceHost)) {
      return { ok: false, status: 403, error: "policy_service_host_denied" };
    }
  }

  const consume = options.forceConsume === true || body.consume !== false;
  if (consume) {
    applySpend(guard.policy, guard.session, amount);
    addAudit("policy.authorized", {
      policy_id: body.policy_id,
      action: body.action,
      amount,
      session_id: guard.session?.session_id || "",
      resource_host: resourceHost,
      resource: body.resource || "",
      context: body.context || {},
      source: options.source || "unknown",
    });
    persist();
  }

  return {
    ok: true,
    status: 200,
    payload: {
      ok: true,
      policy_id: guard.policy?.policy_id || body.policy_id,
      session_id: guard.session?.session_id || "",
      action: body.action,
      consumed: consume,
      resource_host: resourceHost || "",
      resource: body.resource || "",
      remaining_ops: guard.session ? Math.max(0, guard.session.max_ops - guard.session.ops_used) : null,
      remaining_spend: guard.session ? Math.max(0, guard.session.max_spend - guard.session.spend_used) : null,
      session_expires_at: guard.session?.expires_at || "",
      authorized_at: nowIso(),
    },
  };
}

function createWalletBootstrap(body) {
  const walletAddress = body.wallet_address || `0x${crypto.randomBytes(20).toString("hex")}`;
  const nonce = crypto.randomBytes(12).toString("hex");
  return {
    bootstrap_id: body.bootstrap_id || randomId("bootstrap"),
    wallet_address: walletAddress,
    nonce,
    owner: body.owner || "",
    status: "pending",
    created_at: nowIso(),
    verified_at: "",
    api_key_hash: "",
  };
}

function ensureUnique(collection, key, value) {
  return !value || !collection.some((item) => item[key] === value);
}

const server = http.createServer(async (req, res) => {
  for (const [key, value] of Object.entries(corsHeaders(req))) {
    res.setHeader(key, value);
  }
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      ...corsHeaders(req),
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "content-type,x-ynx-owner,x-ynx-session,x-ynx-internal-token",
    });
    return res.end();
  }

  const url = new URL(req.url, "http://localhost");
  const segments = url.pathname.split("/").filter(Boolean);

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/health") {
    return json(res, 200, {
      ok: true,
      service: "ynx-web4-hub",
      chain_id: WEB4_CHAIN_ID,
      track: WEB4_TRACK,
      enforce_policy: WEB4_ENFORCE_POLICY,
      internal_authorizer_enabled: Boolean(WEB4_INTERNAL_TOKEN),
      persistence: {
        debounce_ms: WEB4_PERSIST_DEBOUNCE_MS,
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
      persistence: fs.existsSync(WEB4_DATA_DIR),
      policy_enforcement: WEB4_ENFORCE_POLICY,
      internal_authorizer: Boolean(WEB4_INTERNAL_TOKEN),
    };
    return json(res, checks.persistence && checks.policy_enforcement && checks.internal_authorizer ? 200 : 503, {
      ok: checks.persistence && checks.policy_enforcement && checks.internal_authorizer,
      checks,
      chain_id: WEB4_CHAIN_ID,
      track: WEB4_TRACK,
      data_file: WEB4_DATA_FILE,
      persistence: {
        debounce_ms: WEB4_PERSIST_DEBOUNCE_MS,
        pending: persistRuntime.pending,
        writing: persistRuntime.writing,
        last_error: persistRuntime.last_error,
      },
    });
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/web4/overview") {
    return json(res, 200, {
      ok: true,
      chain_id: WEB4_CHAIN_ID,
      track: WEB4_TRACK,
      positioning: {
        statement: "AI-native Web4 chain coordination and settlement surface",
        features: [
          "wallet-identity bootstrap",
          "owner-rule-session sovereignty model",
          "intent market",
          "claim/challenge/finalize lifecycle",
          "controlled self-modification and replication",
          "audit-first operation logs",
          "AI settlement policy enforcement",
        ],
      },
      defaults: {
        intent_ttl_sec: WEB4_INTENT_TTL_SEC,
        enforce_policy: WEB4_ENFORCE_POLICY,
      },
      stats: summarizeStats(),
    });
  }

  if (req.method === "GET" && url.pathname === "/web4/stats") {
    return json(res, 200, { ok: true, ...summarizeStats() });
  }

  if (req.method === "GET" && url.pathname === "/web4/audit") {
    const limit = Math.max(1, Math.min(500, parseInt(url.searchParams.get("limit") || "100", 10) || 100));
    return json(res, 200, { ok: true, items: state.audit_logs.slice(0, limit) });
  }

  if (req.method === "GET" && url.pathname === "/web4/tools") {
    return json(res, 200, { ok: true, items: state.tools });
  }

  if (req.method === "POST" && url.pathname === "/web4/tools") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (body.tool_id && !ensureUnique(state.tools, "tool_id", body.tool_id)) {
      return json(res, 409, { ok: false, error: "tool_id_exists" });
    }
    let tool;
    try {
      tool = normalizeTool(body);
    } catch (error) {
      return json(res, 400, { ok: false, error: error && error.message ? error.message : "invalid_tool" });
    }
    state.tools.unshift(tool);
    addAudit("tool.registered", { tool_id: tool.tool_id, base_url: tool.base_url, allowed_paths: tool.allowed_paths });
    persist();
    return json(res, 201, { ok: true, tool });
  }

  if (segments[0] === "web4" && segments[1] === "tools" && segments[2]) {
    const toolId = segments[2];
    const action = segments[3] || "";
    const tool = findTool(toolId);

    if (req.method === "GET" && !action) {
      if (!tool) return json(res, 404, { ok: false, error: "tool_not_found" });
      return json(res, 200, { ok: true, tool });
    }

    if (req.method === "POST" && action === "execute") {
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const policyId = body.policy_id || "";
      const amount = toNumber(body.amount, tool?.cost_per_call || 0);
      const guard = policyGuard(req, "tool.execute", policyId, amount);
      if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });
      const toolCheck = validateToolCall(guard.policy, tool, body);
      if (!toolCheck.ok) return json(res, toolCheck.status, { ok: false, error: toolCheck.error });

      const requestBody =
        body.body === undefined || body.body === null
          ? ""
          : typeof body.body === "string"
            ? body.body
            : JSON.stringify(body.body);
      const headers = {
        ...tool.default_headers,
        ...sanitizeHeaders(body.headers || {}),
        ...(requestBody && !sanitizeHeaders(body.headers || {})["content-type"] ? { "content-type": "application/json" } : {}),
      };
      const callId = body.call_id || randomId("call");
      const startedAt = nowIso();
      applySpend(guard.policy, guard.session, amount);

      try {
        const upstream = await requestRaw(toolCheck.target.toString(), {
          method: toolCheck.method,
          headers,
          body: requestBody,
          timeout_ms: Math.min(WEB4_TOOL_TIMEOUT_MS, Math.max(1000, parseInt(body.timeout_ms || WEB4_TOOL_TIMEOUT_MS, 10) || WEB4_TOOL_TIMEOUT_MS)),
          max_response_bytes: WEB4_TOOL_RESPONSE_LIMIT_BYTES,
        });
        const responseHash = hashBody(upstream.body);
        let parsedBody = null;
        try {
          parsedBody = upstream.body ? JSON.parse(upstream.body) : null;
        } catch {
          parsedBody = null;
        }
        const call = {
          call_id: callId,
          tool_id: tool.tool_id,
          policy_id: guard.policy?.policy_id || policyId,
          session_id: guard.session?.session_id || "",
          method: toolCheck.method,
          path: `${toolCheck.target.pathname}${toolCheck.target.search}`,
          target_host: toolCheck.target.hostname,
          amount,
          request_hash: hashBody(requestBody),
          response_hash: responseHash,
          status: upstream.status >= 200 && upstream.status < 400 ? "succeeded" : "failed",
          upstream_status: upstream.status,
          truncated: upstream.truncated,
          started_at: startedAt,
          completed_at: nowIso(),
        };
        state.tool_calls.unshift(call);
        addAudit("tool.executed", {
          call_id: call.call_id,
          tool_id: tool.tool_id,
          policy_id: call.policy_id,
          session_id: call.session_id,
          upstream_status: call.upstream_status,
          amount,
        });
        persist();
        return json(res, 200, {
          ok: true,
          call,
          upstream: {
            status: upstream.status,
            content_type: upstream.headers["content-type"] || "",
            body: parsedBody === null ? upstream.body : parsedBody,
            response_hash: responseHash,
            truncated: upstream.truncated,
          },
        });
      } catch (error) {
        const call = {
          call_id: callId,
          tool_id: tool.tool_id,
          policy_id: guard.policy?.policy_id || policyId,
          session_id: guard.session?.session_id || "",
          method: toolCheck.method,
          path: `${toolCheck.target.pathname}${toolCheck.target.search}`,
          target_host: toolCheck.target.hostname,
          amount,
          request_hash: hashBody(requestBody),
          response_hash: "",
          status: "failed",
          upstream_status: 0,
          error: error && error.message ? error.message : "tool_call_failed",
          started_at: startedAt,
          completed_at: nowIso(),
        };
        state.tool_calls.unshift(call);
        addAudit("tool.failed", { call_id: call.call_id, tool_id: tool.tool_id, error: call.error, amount });
        persist();
        return json(res, 502, { ok: false, error: call.error, call });
      }
    }
  }

  if (req.method === "POST" && url.pathname === "/web4/internal/authorize") {
    if (WEB4_INTERNAL_TOKEN && !secretEquals(readHeader(req, "x-ynx-internal-token"), WEB4_INTERNAL_TOKEN)) {
      return json(res, 401, { ok: false, error: "internal_auth_failed" });
    }
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const decision = authorizeAction(req, body, { source: "internal_authorizer" });
    if (!decision.ok) return json(res, decision.status, { ok: false, error: decision.error });
    return json(res, 200, decision.payload);
  }

  if (req.method === "POST" && url.pathname === "/web4/authorize") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const decision = authorizeAction(req, body, { source: "third_party_gateway" });
    if (!decision.ok) return json(res, decision.status, { ok: false, error: decision.error });
    return json(res, 200, decision.payload);
  }

  if (req.method === "POST" && url.pathname === "/web4/authorize/batch") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const requests = Array.isArray(body.requests) ? body.requests : [];
    if (!requests.length) return json(res, 400, { ok: false, error: "requests_required" });
    if (requests.length > 100) return json(res, 400, { ok: false, error: "too_many_requests" });

    // Pass 1: validate all operations in dry-run mode (no consumption).
    const dryResults = [];
    for (let i = 0; i < requests.length; i += 1) {
      const reqBody = { ...requests[i], consume: false };
      const dry = authorizeAction(req, reqBody, { source: "third_party_gateway_batch_dryrun" });
      if (!dry.ok) {
        return json(res, dry.status, { ok: false, error: dry.error, index: i, dry_results: dryResults });
      }
      dryResults.push(dry.payload);
    }

    // Pass 2: consume in order once all checks pass.
    const consumed = [];
    for (let i = 0; i < requests.length; i += 1) {
      const reqBody = { ...requests[i], consume: true };
      const live = authorizeAction(req, reqBody, { source: "third_party_gateway_batch" });
      if (!live.ok) {
        return json(res, live.status, { ok: false, error: live.error, index: i, consumed });
      }
      consumed.push(live.payload);
    }
    return json(res, 200, { ok: true, count: consumed.length, items: consumed });
  }

  if (req.method === "POST" && url.pathname === "/web4/wallet/bootstrap") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (body.bootstrap_id && !ensureUnique(state.wallet_bootstraps, "bootstrap_id", body.bootstrap_id)) {
      return json(res, 409, { ok: false, error: "bootstrap_id_exists" });
    }
    const item = createWalletBootstrap(body);
    state.wallet_bootstraps.unshift(item);
    addAudit("wallet.bootstrap.requested", { bootstrap_id: item.bootstrap_id, wallet_address: item.wallet_address });
    persist();
    return json(res, 201, {
      ok: true,
      bootstrap: item,
      siwe_message: `Sign-In With Ethereum\nAddress: ${item.wallet_address}\nNonce: ${item.nonce}\nChain: ${WEB4_CHAIN_ID}`,
    });
  }

  if (req.method === "POST" && url.pathname === "/web4/wallet/verify") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    const item = state.wallet_bootstraps.find((entry) => entry.bootstrap_id === body.bootstrap_id);
    if (!item) return json(res, 404, { ok: false, error: "bootstrap_not_found" });
    if (item.status !== "pending") return json(res, 400, { ok: false, error: "bootstrap_already_used" });
    if (!body.signature) return json(res, 400, { ok: false, error: "signature_required" });
    const apiKey = `api_${crypto.randomBytes(18).toString("hex")}`;
    item.status = "verified";
    item.verified_at = nowIso();
    item.api_key_hash = hashSecret(apiKey);
    addAudit("wallet.bootstrap.verified", { bootstrap_id: item.bootstrap_id, wallet_address: item.wallet_address });
    persist();
    return json(res, 200, { ok: true, bootstrap_id: item.bootstrap_id, api_key: apiKey });
  }

  if (req.method === "GET" && url.pathname === "/web4/policies") {
    const items = state.policies.map((item) => ({
      ...item,
      owner_secret_hash: undefined,
    }));
    return json(res, 200, { ok: true, items });
  }

  if (req.method === "POST" && url.pathname === "/web4/policies") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (!body.owner) return json(res, 400, { ok: false, error: "owner_required" });
    if (body.policy_id && !ensureUnique(state.policies, "policy_id", body.policy_id)) {
      return json(res, 409, { ok: false, error: "policy_id_exists" });
    }
    const created = createPolicy(body);
    state.policies.unshift(created.policy);
    addAudit("policy.created", { policy_id: created.policy.policy_id, owner: created.policy.owner });
    persist();
    return json(res, 201, {
      ok: true,
      policy: { ...created.policy, owner_secret_hash: undefined },
      owner_secret: created.owner_secret,
    });
  }

  if (segments[0] === "web4" && segments[1] === "policies" && segments[2]) {
    const policyId = segments[2];
    const action = segments[3] || "";
    const policy = findPolicy(policyId);
    if (!policy) return json(res, 404, { ok: false, error: "policy_not_found" });

    if (req.method === "GET" && !action) {
      return json(res, 200, { ok: true, policy: { ...policy, owner_secret_hash: undefined } });
    }

    if (req.method === "POST" && action === "sessions") {
      if (!verifyOwner(req, policy)) return json(res, 401, { ok: false, error: "owner_auth_failed" });
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      if (body.session_id && !ensureUnique(state.sessions, "session_id", body.session_id)) {
        return json(res, 409, { ok: false, error: "session_id_exists" });
      }
      const issued = issueSession(policy, body);
      state.sessions.unshift(issued.session);
      addAudit("policy.session.issued", { policy_id: policyId, session_id: issued.session.session_id });
      persist();
      return json(res, 201, { ok: true, session: issued.session, token: issued.token });
    }

    if (req.method === "POST" && action === "pause") {
      if (!verifyOwner(req, policy)) return json(res, 401, { ok: false, error: "owner_auth_failed" });
      policy.status = "paused";
      policy.updated_at = nowIso();
      addAudit("policy.paused", { policy_id: policyId });
      persist();
      return json(res, 200, { ok: true, policy: { ...policy, owner_secret_hash: undefined } });
    }

    if (req.method === "POST" && action === "resume") {
      if (!verifyOwner(req, policy)) return json(res, 401, { ok: false, error: "owner_auth_failed" });
      policy.status = "active";
      policy.updated_at = nowIso();
      addAudit("policy.resumed", { policy_id: policyId });
      persist();
      return json(res, 200, { ok: true, policy: { ...policy, owner_secret_hash: undefined } });
    }

    if (req.method === "POST" && action === "revoke") {
      if (!verifyOwner(req, policy)) return json(res, 401, { ok: false, error: "owner_auth_failed" });
      policy.status = "revoked";
      policy.updated_at = nowIso();
      for (const session of state.sessions.filter((item) => item.policy_id === policyId && item.status === "active")) {
        session.status = "revoked";
        session.updated_at = nowIso();
      }
      addAudit("policy.revoked", { policy_id: policyId });
      persist();
      return json(res, 200, { ok: true, policy: { ...policy, owner_secret_hash: undefined } });
    }
  }

  if (req.method === "GET" && url.pathname === "/web4/identities") {
    return json(res, 200, { ok: true, items: state.identities });
  }

  if (req.method === "POST" && url.pathname === "/web4/identities") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (!body.address) return json(res, 400, { ok: false, error: "address_required" });
    if (body.identity_id && !ensureUnique(state.identities, "identity_id", body.identity_id)) {
      return json(res, 409, { ok: false, error: "identity_id_exists" });
    }
    const guard = policyGuard(req, "identity.create", body.policy_id || "", 0);
    if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });
    const identity = {
      identity_id: body.identity_id || randomId("identity"),
      policy_id: body.policy_id || "",
      address: body.address,
      did: body.did || "",
      profile_uri: body.profile_uri || "",
      tags: Array.isArray(body.tags) ? body.tags : [],
      status: "active",
      created_at: nowIso(),
      updated_at: nowIso(),
    };
    applySpend(guard.policy, guard.session, 0);
    state.identities.unshift(identity);
    addAudit("identity.created", { identity_id: identity.identity_id, policy_id: identity.policy_id });
    persist();
    return json(res, 201, { ok: true, identity });
  }

  if (req.method === "GET" && url.pathname === "/web4/agents") {
    return json(res, 200, { ok: true, items: state.agents });
  }

  if (req.method === "POST" && url.pathname === "/web4/agents") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (!body.owner) return json(res, 400, { ok: false, error: "owner_required" });
    if (body.agent_id && !ensureUnique(state.agents, "agent_id", body.agent_id)) {
      return json(res, 409, { ok: false, error: "agent_id_exists" });
    }
    const guard = policyGuard(req, "agent.create", body.policy_id || "", toNumber(body.stake, 0));
    if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });
    const agent = {
      agent_id: body.agent_id || randomId("agent"),
      policy_id: body.policy_id || "",
      parent_agent_id: body.parent_agent_id || "",
      owner: body.owner,
      name: body.name || "unnamed-agent",
      model: body.model || "unspecified",
      endpoint: body.endpoint || "",
      capabilities: uniqueStrings(body.capabilities),
      stake: body.stake || "0",
      status: "active",
      created_at: nowIso(),
      updated_at: nowIso(),
      last_replicated_at: "",
    };
    applySpend(guard.policy, guard.session, toNumber(body.stake, 0));
    state.agents.unshift(agent);
    addAudit("agent.created", { agent_id: agent.agent_id, policy_id: agent.policy_id, parent_agent_id: agent.parent_agent_id });
    persist();
    return json(res, 201, { ok: true, agent });
  }

  if (req.method === "GET" && url.pathname === "/web4/intents") {
    return json(res, 200, { ok: true, items: state.intents });
  }

  if (req.method === "POST" && url.pathname === "/web4/intents") {
    const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
    if (!requireValidBody(res, body)) return;
    if (!body.creator) return json(res, 400, { ok: false, error: "creator_required" });
    if (body.intent_id && !ensureUnique(state.intents, "intent_id", body.intent_id)) {
      return json(res, 409, { ok: false, error: "intent_id_exists" });
    }
    const amount = toNumber(body.budget, 0);
    const guard = policyGuard(req, "intent.create", body.policy_id || "", amount);
    if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });
    const expiresAt = new Date(Date.now() + WEB4_INTENT_TTL_SEC * 1000).toISOString();
    const intent = {
      intent_id: body.intent_id || randomId("intent"),
      policy_id: body.policy_id || "",
      creator: body.creator,
      target_agent_id: body.target_agent_id || "",
      payload_uri: body.payload_uri || "",
      constraints: body.constraints || {},
      budget: body.budget || "0",
      settlement_policy: body.settlement_policy || "challenge-window",
      status: "created",
      created_at: nowIso(),
      updated_at: nowIso(),
      expires_at: expiresAt,
      finalized_at: "",
    };
    applySpend(guard.policy, guard.session, amount);
    state.intents.unshift(intent);
    addAudit("intent.created", { intent_id: intent.intent_id, policy_id: intent.policy_id, budget: intent.budget });
    persist();
    return json(res, 201, { ok: true, intent });
  }

  if (segments[0] === "web4" && segments[1] === "agents" && segments[2]) {
    const agentId = segments[2];
    const action = segments[3] || "";
    const agent = findAgent(agentId);
    if (!agent) return json(res, 404, { ok: false, error: "agent_not_found" });

    if (req.method === "GET" && !action) return json(res, 200, { ok: true, agent });

    if (req.method === "POST" && action === "self-update") {
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const policyId = body.policy_id || agent.policy_id || "";
      const guard = policyGuard(req, "agent.modify", policyId, 0);
      if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });

      const patch = body.patch || {};
      const allow = ["name", "model", "endpoint", "capabilities"];
      for (const key of allow) {
        if (key in patch) {
          agent[key] = key === "capabilities" ? uniqueStrings(patch[key]) : patch[key];
        }
      }
      agent.updated_at = nowIso();
      applySpend(guard.policy, guard.session, 0);
      addAudit("agent.self_update", { agent_id: agent.agent_id, policy_id: policyId, fields: Object.keys(patch) });
      persist();
      return json(res, 200, { ok: true, agent });
    }

    if (req.method === "POST" && action === "replicate") {
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const policyId = body.policy_id || agent.policy_id || "";
      const replicateStake = toNumber(body.stake, 0);
      const guard = policyGuard(req, "agent.replicate", policyId, replicateStake);
      if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });

      const policy = guard.policy;
      if (policy) {
        const children = state.agents.filter((item) => item.parent_agent_id === agent.agent_id).length;
        if (policy.max_children > 0 && children >= policy.max_children) {
          return json(res, 403, { ok: false, error: "replication_limit_reached" });
        }
        if (agent.last_replicated_at) {
          const elapsed = Date.now() - new Date(agent.last_replicated_at).getTime();
          if (elapsed < policy.replicate_cooldown_sec * 1000) {
            return json(res, 429, { ok: false, error: "replication_cooldown" });
          }
        }
      }

      if (body.agent_id && !ensureUnique(state.agents, "agent_id", body.agent_id)) {
        return json(res, 409, { ok: false, error: "agent_id_exists" });
      }

      const child = {
        agent_id: body.agent_id || randomId("agent"),
        policy_id: policyId,
        parent_agent_id: agent.agent_id,
        owner: body.owner || agent.owner,
        name: body.name || `${agent.name}-child`,
        model: body.model || agent.model,
        endpoint: body.endpoint || agent.endpoint,
        capabilities: Array.isArray(body.capabilities) ? uniqueStrings(body.capabilities) : agent.capabilities,
        stake: String(body.stake || agent.stake || "0"),
        status: "active",
        created_at: nowIso(),
        updated_at: nowIso(),
        last_replicated_at: "",
      };
      agent.last_replicated_at = nowIso();
      agent.updated_at = nowIso();
      applySpend(guard.policy, guard.session, replicateStake);
      state.agents.unshift(child);
      addAudit("agent.replicated", { parent_agent_id: agent.agent_id, child_agent_id: child.agent_id, policy_id: policyId });
      persist();
      return json(res, 201, { ok: true, parent: agent, child });
    }
  }

  if (segments[0] === "web4" && segments[1] === "intents" && segments[2]) {
    const intentId = segments[2];
    const action = segments[3] || "";
    const intent = findIntent(intentId);
    if (!intent) return json(res, 404, { ok: false, error: "intent_not_found" });

    if (req.method === "GET" && !action) {
      const claims = state.claims.filter((item) => item.intent_id === intentId);
      return json(res, 200, { ok: true, intent, claims });
    }

    if (req.method === "POST" && action === "claim") {
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      if (!body.agent_id || !body.result_hash) {
        return json(res, 400, { ok: false, error: "agent_id_and_result_hash_required" });
      }
      if (body.claim_id && !ensureUnique(state.claims, "claim_id", body.claim_id)) {
        return json(res, 409, { ok: false, error: "claim_id_exists" });
      }
      if (!findAgent(body.agent_id)) return json(res, 400, { ok: false, error: "agent_not_found" });
      if (intent.status !== "created" && intent.status !== "claimed") {
        return json(res, 400, { ok: false, error: "intent_not_claimable", status: intent.status });
      }
      const policyId = body.policy_id || intent.policy_id || "";
      const guard = policyGuard(req, "intent.claim", policyId, 0);
      if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });

      if (intent.status === "created") transitionIntent(intent, "claimed");
      else intent.updated_at = nowIso();
      const claim = {
        claim_id: body.claim_id || randomId("claim"),
        intent_id: intent.intent_id,
        policy_id: policyId,
        agent_id: body.agent_id,
        result_hash: body.result_hash,
        proof_uri: body.proof_uri || "",
        metadata: body.metadata || {},
        status: "submitted",
        created_at: nowIso(),
      };
      applySpend(guard.policy, guard.session, 0);
      state.claims.unshift(claim);
      addAudit("intent.claimed", { intent_id: intent.intent_id, claim_id: claim.claim_id, policy_id: policyId });
      persist();
      return json(res, 201, { ok: true, intent, claim });
    }

    if (req.method === "POST" && action === "challenge") {
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const policyId = body.policy_id || intent.policy_id || "";
      const guard = policyGuard(req, "intent.challenge", policyId, 0);
      if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });
      if (!transitionIntent(intent, "challenged")) {
        return json(res, 400, { ok: false, error: "invalid_transition", status: intent.status });
      }
      applySpend(guard.policy, guard.session, 0);
      addAudit("intent.challenged", { intent_id: intent.intent_id, policy_id: policyId });
      persist();
      return json(res, 200, { ok: true, intent });
    }

    if (req.method === "POST" && action === "finalize") {
      const body = await parseBody(req, WEB4_BODY_LIMIT_BYTES);
      if (!requireValidBody(res, body)) return;
      const policyId = body.policy_id || intent.policy_id || "";
      const guard = policyGuard(req, "intent.finalize", policyId, 0);
      if (!guard.ok) return json(res, guard.status, { ok: false, error: guard.error });
      const target = body.status === "failed" ? "failed" : "finalized";
      if (!transitionIntent(intent, target)) {
        return json(res, 400, { ok: false, error: "invalid_transition", status: intent.status });
      }
      intent.finalized_at = nowIso();
      applySpend(guard.policy, guard.session, 0);
      addAudit("intent.finalized", { intent_id: intent.intent_id, status: intent.status, policy_id: policyId });
      persist();
      return json(res, 200, { ok: true, intent });
    }
  }

  return json(res, 404, { ok: false, error: "not_found" });
});

server.headersTimeout = WEB4_SERVER_HEADERS_TIMEOUT_MS;
server.requestTimeout = WEB4_SERVER_REQUEST_TIMEOUT_MS;
server.keepAliveTimeout = WEB4_SERVER_KEEP_ALIVE_TIMEOUT_MS;
server.maxRequestsPerSocket = WEB4_SERVER_MAX_REQUESTS_PER_SOCKET;
server.maxHeadersCount = WEB4_SERVER_MAX_HEADERS_COUNT;

server.listen(WEB4_PORT, () => {
  console.log(`YNX Web4 hub listening on :${WEB4_PORT}`);
});

async function gracefulShutdown(signal) {
  console.log(`[web4-hub] received ${signal}, flushing state...`);
  if (persistRuntime.timer) {
    clearTimeout(persistRuntime.timer);
    persistRuntime.timer = null;
  }
  try {
    if (persistRuntime.pending || persistRuntime.writing) await flushPersist();
    else persistSync();
  } catch (error) {
    console.error("[web4-hub] graceful flush failed:", error);
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
