const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  assertJson,
  getFreePort,
  makeTempDir,
  requestJson,
  startNodeServer,
} = require("../test-helpers");

const serverPath = path.join(__dirname, "server.js");
const routesFile = path.join(__dirname, "config", "testnet-routes.json");

test("reports configured testnet routes and readiness in dry-run mode", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-routes-");
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: routesFile,
      BRIDGE_ONCHAIN_ENABLED: "0",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const ready = assertJson(await requestJson(`http://127.0.0.1:${port}/ready`), 200);
  assert.equal(ready.ok, true);

  const routes = assertJson(await requestJson(`http://127.0.0.1:${port}/bridge/routes`), 200);
  assert.equal(routes.items.length, 5);
  assert.equal(routes.items.some((item) => item.routeId === "eth-sepolia-eth"), true);
  assert.equal(routes.items.some((item) => item.routeId === "btc-testnet-btc"), true);

  const assets = assertJson(await requestJson(`http://127.0.0.1:${port}/bridge/assets`), 200);
  assert.equal(assets.ok, true);
  assert.equal(assets.assets.some((item) => item.symbol === "YUSD.test"), true);
  assert.equal(assets.pairs.some((item) => item.label === "wUSDC.y/YUSD.test"), true);
});

test("accepts a deposit proof once and preserves idempotency", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-deposit-");
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: routesFile,
      BRIDGE_ONCHAIN_ENABLED: "0",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const proof = {
    route_id: "eth-sepolia-eth",
    source_tx_hash: "0xabc123",
    log_index: 0,
    recipient: "0x000000000000000000000000000000000000dEaD",
    amount: "0.25",
    confirmations: 3,
    proof: { mode: "manual-test-proof" },
  };

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/deposits/prove`, {
      method: "POST",
      body: proof,
    }),
    201,
  );
  assert.equal(created.deposit.status, "accepted_dry_run");
  assert.equal(created.deposit.amount_base_units, "250000000000000000");

  const duplicate = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/deposits/prove`, {
      method: "POST",
      body: proof,
    }),
    200,
  );
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.deposit.deposit_id, created.deposit.deposit_id);
});

test("rejects deposits before route confirmation threshold", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-confirmations-");
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: routesFile,
      BRIDGE_ONCHAIN_ENABLED: "0",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const rejected = await requestJson(`http://127.0.0.1:${port}/bridge/deposits/prove`, {
    method: "POST",
    body: {
      route_id: "btc-testnet-btc",
      source_tx_hash: "btc-testnet-tx",
      output_index: 1,
      recipient: "0x000000000000000000000000000000000000dEaD",
      amount: "0.01",
      confirmations: 0,
    },
  });
  assert.equal(rejected.status, 400);
  assert.equal(rejected.body.error, "insufficient_confirmations");
});

test("queues outbound withdrawal requests", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-withdraw-");
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: routesFile,
      BRIDGE_ONCHAIN_ENABLED: "0",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/withdrawals/request`, {
      method: "POST",
      body: {
        route_id: "bnb-testnet-bnb",
        burn_tx_hash: "0xburn",
        destination_recipient: "tbnb1destination",
        amount: "1.5",
      },
    }),
    201,
  );
  assert.equal(created.withdrawal.status, "queued");
  assert.equal(created.withdrawal.amount_base_units, "1500000000000000000");
});

test("reports watcher state and scans configured routes without lockboxes", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-watchers-");
  const routes = JSON.parse(fs.readFileSync(routesFile, "utf8"));
  for (const route of routes.routes) {
    delete route.lockboxAddress;
    delete route.lockboxStartBlock;
  }
  const fixtureRoutesFile = path.join(dataDir, "routes-without-lockboxes.json");
  fs.writeFileSync(fixtureRoutesFile, JSON.stringify(routes, null, 2));
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: fixtureRoutesFile,
      BRIDGE_ONCHAIN_ENABLED: "0",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const watchers = assertJson(await requestJson(`http://127.0.0.1:${port}/bridge/watchers`), 200);
  assert.equal(watchers.ok, true);
  assert.deepEqual(watchers.items, {});

  const scan = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/watchers/scan`, {
      method: "POST",
      body: { route_id: "eth-sepolia-eth" },
    }),
    200,
  );
  assert.equal(scan.items[0].skipped, true);
  assert.equal(scan.items[0].reason, "lockbox_unconfigured");
});
