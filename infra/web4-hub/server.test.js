const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { setTimeout: delay } = require("node:timers/promises");
const { ethers } = require("ethers");

const {
  assertJson,
  getFreePort,
  makeTempDir,
  requestJson,
  startNodeServer,
} = require("../test-helpers");

const serverPath = path.join(__dirname, "server.js");

function startToolServer(port) {
  const calls = [];
  const server = http.createServer((req, res) => {
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk.toString();
    });
    req.on("end", () => {
      calls.push({ method: req.method, url: req.url, raw });
      if (req.url === "/v1/run" && req.method === "POST") {
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify({ ok: true, provider: "generic-third-party", received: JSON.parse(raw || "{}") }));
        return;
      }
      res.writeHead(404, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: false, error: "not_found" }));
    });
  });
  return new Promise((resolve, reject) => {
    server.listen(port, "127.0.0.1", () => resolve({ server, calls }));
    server.on("error", reject);
  });
}

test("reports ready when policy enforcement and internal authorization are configured", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-ready-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const ready = assertJson(await requestJson(`http://127.0.0.1:${port}/ready`), 200);
  assert.equal(ready.ok, true);
  assert.equal(ready.checks.policy_enforcement, true);
  assert.equal(ready.checks.internal_authorizer, true);
});

test("honors configured CORS allowlist for preflight requests", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-cors-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
      WEB4_CORS_ALLOWED_ORIGINS: "https://app.ynxweb4.com,https://ops.ynxweb4.com",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const response = await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
    method: "OPTIONS",
    headers: { origin: "https://ops.ynxweb4.com" },
  });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("access-control-allow-origin"), "https://ops.ynxweb4.com");
  assert.equal(response.headers.get("vary"), "origin");

  const ready = await requestJson(`http://127.0.0.1:${port}/ready`, {
    headers: { origin: "https://ops.ynxweb4.com" },
  });
  assert.equal(ready.headers.get("access-control-allow-origin"), "https://ops.ynxweb4.com");
});

test("internal authorization consumes session ops and spend for AI actions", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-authz-");
  const internalToken = "web4-secret";

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: internalToken,
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-authz",
        name: "policy-authz",
        max_daily_spend: 500,
        max_total_spend: 500,
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["ai.payment.charge"],
        ttl_sec: 600,
        max_ops: 2,
        max_spend: 100,
      },
    }),
    201
  );

  const unauthorized = await requestJson(`http://127.0.0.1:${port}/web4/internal/authorize`, {
    method: "POST",
    headers: { "x-ynx-internal-token": internalToken },
    body: {
      policy_id: created.policy.policy_id,
      action: "ai.payment.charge",
      amount: 25,
    },
  });
  assert.equal(unauthorized.status, 401);
  assert.equal(unauthorized.body.error, "session_required");

  const authorized = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/internal/authorize`, {
      method: "POST",
      headers: {
        "x-ynx-internal-token": internalToken,
        "x-ynx-session": session.token,
      },
      body: {
        policy_id: created.policy.policy_id,
        action: "ai.payment.charge",
        amount: 25,
        context: { reason: "test-charge" },
      },
    }),
    200
  );
  assert.equal(authorized.ok, true);
  assert.equal(authorized.remaining_ops, 1);
  assert.equal(authorized.remaining_spend, 75);
});

test("policy owner actions require owner secret, not public owner name", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-owner-secret-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "public-owner-name",
        name: "policy-owner-secret",
      },
    }),
    201
  );

  const publicOwnerAttempt = await requestJson(
    `http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`,
    {
      method: "POST",
      headers: { "x-ynx-owner": "public-owner-name" },
      body: { capabilities: ["intent.create"] },
    }
  );
  assert.equal(publicOwnerAttempt.status, 401);
  assert.equal(publicOwnerAttempt.body.error, "owner_auth_failed");

  const secretAttempt = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: { capabilities: ["intent.create"] },
    }),
    201
  );
  assert.equal(secretAttempt.ok, true);
  assert.ok(secretAttempt.token);
});

test("wallet bootstrap verify requires a valid wallet signature", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-wallet-verify-");
  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const wallet = ethers.Wallet.createRandom();
  const bootstrap = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/bootstrap`, {
      method: "POST",
      body: {
        wallet_address: wallet.address,
      },
    }),
    201
  );

  const badVerify = await requestJson(`http://127.0.0.1:${port}/web4/wallet/verify`, {
    method: "POST",
    body: {
      bootstrap_id: bootstrap.bootstrap.bootstrap_id,
      signature: "0xdeadbeef",
    },
  });
  assert.equal(badVerify.status, 401);
  assert.equal(badVerify.body.error, "invalid_signature");

  const signature = await wallet.signMessage(bootstrap.siwe_message);
  const verified = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/verify`, {
      method: "POST",
      body: {
        bootstrap_id: bootstrap.bootstrap.bootstrap_id,
        signature,
      },
    }),
    200
  );
  assert.equal(verified.ok, true);
  assert.match(verified.api_key, /^api_/);
});

test("wallet bootstrap challenge expires before verify when ttl elapses", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-wallet-bootstrap-expire-");
  let server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_PERSIST_DEBOUNCE_MS: "0",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
      WEB4_BOOTSTRAP_CHALLENGE_TTL_SEC: "30",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const wallet = ethers.Wallet.createRandom();
  const expiredAt = new Date(Date.now() - 60_000).toISOString();
  const bootstrap = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/bootstrap`, {
      method: "POST",
      body: {
        wallet_address: wallet.address,
        bootstrap_id: "bootstrap_expired_test",
      },
    }),
    201
  );

  const statePath = path.join(dataDir, "state.json");
  await delay(50);
  await server.stop();
  const state = JSON.parse(fs.readFileSync(statePath, "utf8"));
  const item = state.wallet_bootstraps.find((entry) => entry.bootstrap_id === "bootstrap_expired_test");
  item.expires_at = expiredAt;
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_PERSIST_DEBOUNCE_MS: "0",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
      WEB4_BOOTSTRAP_CHALLENGE_TTL_SEC: "30",
    },
    `http://127.0.0.1:${port}/ready`
  );

  const signature = await wallet.signMessage(bootstrap.siwe_message);
  const verify = await requestJson(`http://127.0.0.1:${port}/web4/wallet/verify`, {
    method: "POST",
    body: {
      bootstrap_id: "bootstrap_expired_test",
      signature,
    },
  });
  assert.equal(verify.status, 400);
  assert.equal(verify.body.error, "bootstrap_expired");
});

test("policy creation requires bootstrap api key when bootstrap gating is enabled", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-policy-bootstrap-gate-");
  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_REQUIRE_BOOTSTRAP_FOR_POLICY_CREATE: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const denied = await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
    method: "POST",
    body: {
      owner: "ungated-owner",
      name: "no-bootstrap-policy",
    },
  });
  assert.equal(denied.status, 401);
  assert.equal(denied.body.error, "bootstrap_api_key_required");

  const wallet = ethers.Wallet.createRandom();
  const bootstrap = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/bootstrap`, {
      method: "POST",
      body: {
        wallet_address: wallet.address,
      },
    }),
    201
  );
  const signature = await wallet.signMessage(bootstrap.siwe_message);
  const verified = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/verify`, {
      method: "POST",
      body: {
        bootstrap_id: bootstrap.bootstrap.bootstrap_id,
        signature,
      },
    }),
    200
  );

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      headers: { "x-ynx-api-key": verified.api_key },
      body: {
        name: "bootstrap-backed-policy",
      },
    }),
    201
  );
  assert.equal(created.policy.owner, wallet.address);
  assert.equal(created.policy.owner_wallet_address, wallet.address);
  assert.equal(created.policy.bootstrap_id, bootstrap.bootstrap.bootstrap_id);

  const reused = await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
    method: "POST",
    headers: { "x-ynx-api-key": verified.api_key },
    body: {
      name: "bootstrap-backed-policy-reuse",
    },
  });
  assert.equal(reused.status, 403);
  assert.equal(reused.body.error, "bootstrap_api_key_exhausted");
});

test("bootstrap api key expires before policy creation when ttl elapses", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-bootstrap-api-expire-");
  let server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_REQUIRE_BOOTSTRAP_FOR_POLICY_CREATE: "1",
      WEB4_PERSIST_DEBOUNCE_MS: "0",
      WEB4_BOOTSTRAP_API_KEY_TTL_SEC: "30",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const wallet = ethers.Wallet.createRandom();
  const bootstrap = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/bootstrap`, {
      method: "POST",
      body: {
        wallet_address: wallet.address,
        bootstrap_id: "bootstrap_api_expired_test",
      },
    }),
    201
  );
  const signature = await wallet.signMessage(bootstrap.siwe_message);
  const verified = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/wallet/verify`, {
      method: "POST",
      body: {
        bootstrap_id: "bootstrap_api_expired_test",
        signature,
      },
    }),
    200
  );

  const statePath = path.join(dataDir, "state.json");
  await delay(50);
  await server.stop();
  const state = JSON.parse(fs.readFileSync(statePath, "utf8"));
  const item = state.wallet_bootstraps.find((entry) => entry.bootstrap_id === "bootstrap_api_expired_test");
  item.api_key_expires_at = new Date(Date.now() - 60_000).toISOString();
  fs.writeFileSync(statePath, JSON.stringify(state, null, 2));
  server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_REQUIRE_BOOTSTRAP_FOR_POLICY_CREATE: "1",
      WEB4_PERSIST_DEBOUNCE_MS: "0",
      WEB4_BOOTSTRAP_API_KEY_TTL_SEC: "30",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );

  const denied = await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
    method: "POST",
    headers: { "x-ynx-api-key": verified.api_key },
    body: {
      name: "expired-bootstrap-api-policy",
    },
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, "bootstrap_api_key_expired");
});

test("protects web4 audit reads and redacts sensitive audit payload values", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-audit-protected-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "audit-owner",
        owner_secret: "own_super_secret_value",
        allowed_actions: ["audit.read"],
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["audit.read"],
        ttl_sec: 600,
      },
    }),
    201
  );

  const missingPolicy = await requestJson(`http://127.0.0.1:${port}/web4/audit`, {
    headers: { "x-ynx-session": session.token },
  });
  assert.equal(missingPolicy.status, 400);
  assert.equal(missingPolicy.body.error, "policy_id_required");

  const audit = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/audit?policy_id=${encodeURIComponent(created.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(Array.isArray(audit.items), true);
  assert.equal(audit.items.some((item) => item.event === "policy.created"), true);
  const serialized = JSON.stringify(audit);
  assert.doesNotMatch(serialized, /own_super_secret_value/);
  assert.doesNotMatch(serialized, /ses_[a-z0-9]{12,}/i);
});

test("executes any third-party API through bounded tool policy", async (t) => {
  const port = await getFreePort();
  const toolPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-tools-");
  const toolServer = await startToolServer(toolPort);
  t.after(() => new Promise((resolve) => toolServer.server.close(resolve)));

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_ALLOW_PRIVATE_TOOL_URLS: "1",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const tool = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/tools`, {
      method: "POST",
      body: {
        tool_id: "thirdparty-api",
        name: "Third-party API",
        base_url: `http://127.0.0.1:${toolPort}`,
        allowed_methods: ["POST"],
        allowed_paths: ["/v1/*"],
        cost_per_call: 1.5,
      },
    }),
    201
  );
  assert.equal(tool.tool.tool_id, "thirdparty-api");

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-tools",
        name: "third-party-tools",
        allowed_actions: ["tool.execute"],
        allowed_tools: ["thirdparty-api"],
        allowed_tool_hosts: ["127.0.0.1"],
        max_daily_spend: 3,
        max_total_spend: 3,
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["tool.execute"],
        ttl_sec: 600,
        max_ops: 1,
        max_spend: 2,
      },
    }),
    201
  );

  const executed = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/tools/thirdparty-api/execute`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        policy_id: created.policy.policy_id,
        method: "POST",
        path: "/v1/run",
        body: { task: "summarize", input: "hello" },
      },
    }),
    200
  );
  assert.equal(executed.ok, true);
  assert.equal(executed.call.status, "succeeded");
  assert.equal(executed.call.amount, 1.5);
  assert.equal(executed.upstream.body.provider, "generic-third-party");
  assert.equal(toolServer.calls.length, 1);

  const overOps = await requestJson(`http://127.0.0.1:${port}/web4/tools/thirdparty-api/execute`, {
    method: "POST",
    headers: { "x-ynx-session": session.token },
    body: {
      policy_id: created.policy.policy_id,
      method: "POST",
      path: "/v1/run",
      body: { task: "second" },
    },
  });
  assert.equal(overOps.status, 403);
  assert.equal(overOps.body.error, "session_ops_exceeded");
});

test("authorizes generic third-party actions with host allowlist", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-generic-authorize-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-generic-authorize",
        name: "generic-third-party-policy",
        allowed_actions: ["service.invoke", "service.read.*"],
        allowed_service_hosts: ["api.partner.example.com"],
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["service.invoke"],
        max_ops: 3,
        max_spend: 100,
      },
    }),
    201
  );

  const allowed = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/authorize`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        policy_id: created.policy.policy_id,
        action: "service.invoke",
        amount: 12.5,
        resource_host: "api.partner.example.com",
        resource: "crm/ticket/update",
      },
    }),
    200
  );
  assert.equal(allowed.ok, true);
  assert.equal(allowed.remaining_ops, 2);
  assert.equal(allowed.remaining_spend, 87.5);
});

test("rejects generic third-party actions outside service host allowlist", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-generic-authorize-deny-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-generic-deny",
        allowed_actions: ["service.invoke"],
        allowed_service_hosts: ["api.partner.example.com"],
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: { capabilities: ["service.invoke"], max_ops: 2, max_spend: 20 },
    }),
    201
  );

  const denied = await requestJson(`http://127.0.0.1:${port}/web4/authorize`, {
    method: "POST",
    headers: { "x-ynx-session": session.token },
    body: {
      policy_id: created.policy.policy_id,
      action: "service.invoke",
      amount: 1,
      resource_host: "evil.example.net",
      resource: "crm/ticket/delete",
    },
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, "policy_service_host_denied");
});

test("authorizes a batch of third-party actions with single session", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-generic-batch-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-batch",
        allowed_actions: ["service.invoke"],
        allowed_service_hosts: ["api.partner.example.com"],
        max_total_spend: 200,
        max_daily_spend: 200,
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["service.invoke"],
        max_ops: 10,
        max_spend: 100,
      },
    }),
    201
  );

  const batch = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/authorize/batch`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        requests: [
          {
            policy_id: created.policy.policy_id,
            action: "service.invoke",
            amount: 3,
            resource_host: "api.partner.example.com",
            resource: "crm/ticket/create",
          },
          {
            policy_id: created.policy.policy_id,
            action: "service.invoke",
            amount: 4,
            resource_host: "api.partner.example.com",
            resource: "crm/ticket/update",
          },
        ],
      },
    }),
    200
  );
  assert.equal(batch.ok, true);
  assert.equal(batch.count, 2);
  assert.equal(batch.items[1].remaining_spend, 93);
});

test("rejects third-party tool calls outside registered paths", async (t) => {
  const port = await getFreePort();
  const toolPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-tools-deny-");
  const toolServer = await startToolServer(toolPort);
  t.after(() => new Promise((resolve) => toolServer.server.close(resolve)));

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_ALLOW_PRIVATE_TOOL_URLS: "1",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  await requestJson(`http://127.0.0.1:${port}/web4/tools`, {
    method: "POST",
    body: {
      tool_id: "restricted-api",
      base_url: `http://127.0.0.1:${toolPort}`,
      allowed_methods: ["POST"],
      allowed_paths: ["/safe/*"],
    },
  });

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-deny",
        allowed_actions: ["tool.execute"],
        allowed_tools: ["restricted-api"],
        allowed_tool_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: { capabilities: ["tool.execute"], max_ops: 2 },
    }),
    201
  );

  const denied = await requestJson(`http://127.0.0.1:${port}/web4/tools/restricted-api/execute`, {
    method: "POST",
    headers: { "x-ynx-session": session.token },
    body: {
      policy_id: created.policy.policy_id,
      method: "POST",
      path: "/admin/delete-everything",
      body: { dangerous: true },
    },
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, "tool_path_denied");
  assert.equal(toolServer.calls.length, 0);
});

test("creates a YNX Card mock and authorizes an agent-bounded spend within rules", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-card-mock-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "card-owner",
        allowed_actions: ["agent.create", "card.authorize"],
        max_total_spend: 500,
        max_daily_spend: 500,
      },
    }),
    201
  );

  const ownerSession = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["agent.create", "card.authorize"],
        max_ops: 10,
        max_spend: 100,
      },
    }),
    201
  );

  const agent = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/agents`, {
      method: "POST",
      headers: { "x-ynx-session": ownerSession.token },
      body: {
        policy_id: created.policy.policy_id,
        owner: "card-owner",
        name: "shopping-agent",
        capabilities: ["spend"],
      },
    }),
    201
  );

  const card = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        policy_id: created.policy.policy_id,
        label: "Ops Card",
        asset_ref: "YUSD.test",
        require_agent: true,
        allowed_agents: [agent.agent.agent_id],
        allowed_merchants: ["OpenAI"],
        allowed_mccs: ["5734"],
        max_per_txn: 50,
        max_daily_spend: 100,
      },
    }),
    201
  );
  assert.equal(card.card.label, "Ops Card");

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["card.authorize"],
        max_ops: 3,
        max_spend: 80,
      },
    }),
    201
  );

  const approved = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}/authorize`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        policy_id: created.policy.policy_id,
        agent_id: agent.agent.agent_id,
        amount: 20,
        merchant: "OpenAI",
        mcc: "5734",
        country: "US",
      },
    }),
    200
  );
  assert.equal(approved.ok, true);
  assert.equal(approved.authorization.approved, true);
  assert.equal(approved.authorization.amount, 20);
  assert.equal(approved.remaining_spend, 60);

  const detail = assertJson(await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}`), 200);
  assert.equal(detail.card.spent_total, 20);
  assert.equal(detail.authorizations[0].approved, true);
  assert.equal(detail.authorizations[0].status, "authorized");
});

test("declines YNX Card mock spends outside rules and records the denial", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-card-decline-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "decline-owner",
        allowed_actions: ["card.authorize", "audit.read"],
        max_total_spend: 500,
        max_daily_spend: 500,
      },
    }),
    201
  );

  const card = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        policy_id: created.policy.policy_id,
        label: "Strict Card",
        allowed_merchants: ["Notion"],
        max_per_txn: 10,
      },
    }),
    201
  );

  const session = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["card.authorize", "audit.read"],
        max_ops: 5,
        max_spend: 100,
      },
    }),
    201
  );

  const denied = await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}/authorize`, {
    method: "POST",
    headers: { "x-ynx-session": session.token },
    body: {
      policy_id: created.policy.policy_id,
      amount: 25,
      merchant: "OpenAI",
      mcc: "5734",
      country: "US",
    },
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.ok, false);
  assert.equal(denied.body.authorization.approved, false);
  assert.deepEqual(denied.body.authorization.reasons.sort(), ["card_per_txn_limit_exceeded", "merchant_not_allowed"].sort());

  const audit = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/audit?policy_id=${encodeURIComponent(created.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(audit.items.some((item) => item.event === "card.declined"), true);
});

test("records YNX Card mock settlement, reversal, and refund lifecycle events", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-web4-card-ledger-");

  const server = await startNodeServer(
    serverPath,
    {
      WEB4_PORT: String(port),
      WEB4_DATA_DIR: dataDir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: "internal-token",
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "ledger-owner",
        allowed_actions: ["agent.create", "card.authorize", "audit.read"],
        max_total_spend: 500,
        max_daily_spend: 500,
      },
    }),
    201
  );

  const ownerSession = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["agent.create", "card.authorize", "audit.read"],
        max_ops: 10,
        max_spend: 200,
      },
    }),
    201
  );

  const agent = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/agents`, {
      method: "POST",
      headers: { "x-ynx-session": ownerSession.token },
      body: {
        policy_id: created.policy.policy_id,
        owner: "ledger-owner",
        name: "ledger-agent",
        capabilities: ["spend"],
      },
    }),
    201
  );

  const card = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        policy_id: created.policy.policy_id,
        label: "Ledger Card",
        asset_ref: "YUSD.test",
        require_agent: true,
        allowed_agents: [agent.agent.agent_id],
        allowed_merchants: ["OpenAI"],
        max_per_txn: 100,
      },
    }),
    201
  );

  const spendSession = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/policies/${created.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        capabilities: ["card.authorize", "audit.read"],
        max_ops: 10,
        max_spend: 150,
      },
    }),
    201
  );

  const approved = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}/authorize`, {
      method: "POST",
      headers: { "x-ynx-session": spendSession.token },
      body: {
        policy_id: created.policy.policy_id,
        agent_id: agent.agent.agent_id,
        amount: 40,
        merchant: "OpenAI",
        mcc: "5734",
        country: "US",
      },
    }),
    200
  );
  assert.equal(approved.authorization.status, "authorized");

  const settled = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}/settle`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        authorization_id: approved.authorization.authorization_id,
        amount: 25,
        external_ref: "issuer-settle-1",
      },
    }),
    200
  );
  assert.equal(settled.authorization.capture_total, 25);
  assert.equal(settled.authorization.remaining_authorized, 15);
  assert.equal(settled.authorization.status, "partially_settled");
  assert.equal(settled.transaction.type, "settled");

  const reversed = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}/reverse`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        authorization_id: approved.authorization.authorization_id,
        amount: 15,
        external_ref: "issuer-reversal-1",
      },
    }),
    200
  );
  assert.equal(reversed.authorization.reversed_total, 15);
  assert.equal(reversed.authorization.remaining_authorized, 0);
  assert.equal(reversed.authorization.status, "settled");
  assert.equal(reversed.transaction.type, "reversed");

  const refunded = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}/refund`, {
      method: "POST",
      headers: { "x-ynx-owner": created.owner_secret },
      body: {
        authorization_id: approved.authorization.authorization_id,
        amount: 5,
        external_ref: "issuer-refund-1",
      },
    }),
    200
  );
  assert.equal(refunded.authorization.refunded_total, 5);
  assert.equal(refunded.authorization.net_settled_total, 20);
  assert.equal(refunded.authorization.status, "partially_refunded");
  assert.equal(refunded.transaction.type, "refunded");

  const detail = assertJson(await requestJson(`http://127.0.0.1:${port}/web4/cards/${card.card.card_id}`), 200);
  assert.equal(detail.authorizations[0].authorization_id, approved.authorization.authorization_id);
  assert.equal(detail.authorizations[0].status, "partially_refunded");
  assert.equal(detail.transactions.length, 3);
  assert.deepEqual(detail.transactions.map((item) => item.type), ["refunded", "reversed", "settled"]);

  const audit = assertJson(
    await requestJson(`http://127.0.0.1:${port}/web4/audit?policy_id=${encodeURIComponent(created.policy.policy_id)}`, {
      headers: { "x-ynx-session": spendSession.token },
    }),
    200
  );
  assert.equal(audit.items.some((item) => item.event === "card.settled"), true);
  assert.equal(audit.items.some((item) => item.event === "card.reversed"), true);
  assert.equal(audit.items.some((item) => item.event === "card.refunded"), true);
});
