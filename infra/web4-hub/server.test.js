const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");

const {
  assertJson,
  getFreePort,
  makeTempDir,
  requestJson,
  startNodeServer,
} = require("../test-helpers");

const serverPath = path.join(__dirname, "server.js");

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
