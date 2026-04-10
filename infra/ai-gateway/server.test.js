const test = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");

const {
  assertJson,
  getFreePort,
  makeTempDir,
  requestJson,
  startNodeServer,
  writeJson,
} = require("../test-helpers");

const serverPath = path.join(__dirname, "server.js");

test("loads legacy array-backed jobs data", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-legacy-");
  await writeJson(path.join(dataDir, "jobs.json"), [
    {
      job_id: "job_legacy",
      creator: "legacy_creator",
      worker: "",
      reward: "10",
      stake: "1",
      status: "finalized",
      input_uri: "ipfs://legacy",
      attestation_uri: "",
      result_hash: "",
      vault_id: "",
      payout_payment_id: "",
      created_at: "2026-01-01T00:00:00.000Z",
      updated_at: "2026-01-01T00:00:00.000Z",
    },
  ]);

  const server = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(port),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const jobs = await requestJson(`http://127.0.0.1:${port}/ai/jobs`);
  const body = assertJson(jobs, 200);
  assert.equal(body.ok, true);
  assert.equal(body.items.length, 1);
  assert.equal(body.items[0].job_id, "job_legacy");
});

test("enforces web4-backed policy authorization for vault creation", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-enforce-");
  const web4Dir = await makeTempDir("ynx-web4-enforce-");
  const internalToken = "test-internal-token";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");

  const web4 = await startNodeServer(
    web4ServerPath,
    {
      WEB4_PORT: String(web4Port),
      WEB4_DATA_DIR: web4Dir,
      WEB4_ENFORCE_POLICY: "1",
      WEB4_INTERNAL_TOKEN: internalToken,
      WEB4_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${web4Port}/ready`
  );
  t.after(async () => web4.stop());

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "1",
      AI_WEB4_HUB_URL: `http://127.0.0.1:${web4Port}`,
      AI_WEB4_INTERNAL_TOKEN: internalToken,
      AI_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const policy = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: { owner: "owner-test", name: "policy-test", max_daily_spend: 1000, max_total_spend: 1000 },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.vault.create"],
        ttl_sec: 600,
        max_ops: 10,
        max_spend: 1000,
      },
    }),
    201
  );

  const missingSession = await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`, {
    method: "POST",
    body: {
      owner: "owner-test",
      balance: 100,
      policy_id: policy.policy.policy_id,
    },
  });
  assert.equal(missingSession.status, 401);
  assert.equal(missingSession.body.error, "session_required");

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        owner: "owner-test",
        balance: 100,
        policy_id: policy.policy.policy_id,
      },
    }),
    201
  );
  assert.equal(created.vault.policy_id, policy.policy.policy_id);
});

test("rejects x402 delivery when settled payment resource does not match request", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-x402-");
  const server = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(port),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${port}/ready`
  );
  t.after(async () => server.stop());

  const vault = assertJson(
    await requestJson(`http://127.0.0.1:${port}/ai/vaults`, {
      method: "POST",
      body: {
        owner: "owner-x402",
        balance: 100,
        max_daily_spend: 100,
        max_per_payment: 100,
      },
    }),
    201
  );

  const payment = assertJson(
    await requestJson(`http://127.0.0.1:${port}/ai/payments/charge`, {
      method: "POST",
      body: {
        vault_id: vault.vault.vault_id,
        amount: 25,
        resource: "resource-a",
        reason: "test-charge",
      },
    }),
    200
  );

  const delivery = await requestJson(`http://127.0.0.1:${port}/x402/resource?resource=resource-b&units=1`, {
    headers: { "x-ynx-payment": payment.payment.payment_id },
  });
  assert.equal(delivery.status, 402);
  assert.equal(delivery.body.error, "invalid_payment_resource");
});
