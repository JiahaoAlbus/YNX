const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
const crypto = require("crypto");

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

function postJson(targetUrl, payload, extraHeaders = {}) {
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

    req.on("error", reject);
    req.write(body);
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

function persist() {
  atomicWriteJson(AI_DATA_FILE, state);
}

function addAudit(event, payload) {
  state.audit_logs.unshift({
    audit_id: randomId("audit"),
    event,
    payload,
    created_at: nowIso(),
  });
  if (state.audit_logs.length > 5000) {
    state.audit_logs = state.audit_logs.slice(0, 5000);
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

async function authorizeViaWeb4(req, action, options = {}) {
  const policyId = options.policy_id || "";
  if (!policyId) {
    if (AI_ENFORCE_POLICY) return { ok: false, status: 400, error: "policy_required" };
    return { ok: true };
  }
  if (!AI_WEB4_HUB_URL) return { ok: false, status: 503, error: "web4_authorizer_unavailable" };
  const sessionToken = req.headers["x-ynx-session"] || "";
  if (!sessionToken) return { ok: false, status: 401, error: "session_required" };

  try {
    const response = await postJson(
      `${AI_WEB4_HUB_URL}/web4/internal/authorize`,
      {
        policy_id: policyId,
        action,
        amount: toNumber(options.amount, 0),
        consume: options.consume !== false,
        context: {
          request_id: options.request_id || req.headers["x-request-id"] || "",
          resource: options.resource || "",
          reason: options.reason || "",
        },
      },
      {
        "x-ynx-session": sessionToken,
        ...(AI_WEB4_INTERNAL_TOKEN ? { "x-ynx-internal-token": AI_WEB4_INTERNAL_TOKEN } : {}),
      }
    );
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
      stats: summarizeStats(),
    });
  }

  if ((req.method === "GET" || req.method === "HEAD") && url.pathname === "/ready") {
    const checks = {
      persistence: fs.existsSync(AI_DATA_DIR),
      policy_authorizer: !AI_ENFORCE_POLICY || Boolean(AI_WEB4_HUB_URL),
    };
    return json(res, checks.persistence && checks.policy_authorizer ? 200 : 503, {
      ok: checks.persistence && checks.policy_authorizer,
      checks,
      data_file: AI_DATA_FILE,
      chain_id: AI_CHAIN_ID,
      enforce_policy: AI_ENFORCE_POLICY,
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
