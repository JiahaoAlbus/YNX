const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const path = require("node:path");

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
