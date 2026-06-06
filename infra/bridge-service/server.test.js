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

test("marks manually released withdrawals with source proof", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-release-");
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
        route_id: "tron-shasta-usdt",
        burn_tx_hash: "0xburn",
        destination_recipient: "TManualReleaseRecipient",
        amount: "3.5",
      },
    }),
    201,
  );

  const released = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/withdrawals/${created.withdrawal.withdrawal_id}/mark-released`, {
      method: "POST",
      body: {
        release_tx_hash: "tron-shasta-release-tx",
        proof: { mode: "operator-manual-release" },
      },
    }),
    200,
  );
  assert.equal(released.withdrawal.status, "released");
  assert.equal(released.withdrawal.release.manual, true);
  assert.equal(released.withdrawal.release.tx_hash, "tron-shasta-release-tx");
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
      BRIDGE_ONCHAIN_ENABLED: "1",
      BRIDGE_YNX_RPC_URL: "http://127.0.0.1:1",
      BRIDGE_RELAYER_MODE: "private-key",
      BRIDGE_ATTESTER_PRIVATE_KEY: "0x1111111111111111111111111111111111111111111111111111111111111111",
      BRIDGE_RELAYER_PRIVATE_KEY: "0x2222222222222222222222222222222222222222222222222222222222222222",
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

test("reports per-route bridge readiness without claiming unsupported full loops", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-route-readiness-");
  const fixtureRoutesFile = path.join(dataDir, "routes-readiness.json");
  fs.writeFileSync(
    fixtureRoutesFile,
    JSON.stringify(
      {
        network: "test",
        ynxChainId: 9102,
        gateway: "0x3a2948da8f35b86dce1440ebfb56b8ae041cebfe",
        routes: [
          {
            routeId: "btc-testnet-btc",
            asset: "BTC",
            displayName: "Bitcoin Testnet BTC",
            sourceKind: "bitcoin-mock",
            sourceNetwork: "bitcoin-testnet",
            sourceChainId: "18332",
            sourceAssetId: "0x42dce463fe146e09f3002678bf279aadb46a211e0d8f482f6e768bbb7222f6d6",
            wrappedToken: "0x1887Eb24feefB6538CBc2140B148ba831f313991",
            wrappedSymbol: "wBTC.y",
            decimals: 8,
            rpc: "http://127.0.0.1:1",
          },
        ],
      },
      null,
      2,
    ),
  );
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: fixtureRoutesFile,
      BRIDGE_ONCHAIN_ENABLED: "1",
      BRIDGE_YNX_RPC_URL: "http://127.0.0.1:1",
      BRIDGE_RELAYER_MODE: "private-key",
      BRIDGE_ATTESTER_PRIVATE_KEY: "0x1111111111111111111111111111111111111111111111111111111111111111",
      BRIDGE_RELAYER_PRIVATE_KEY: "0x2222222222222222222222222222222222222222222222222222222222222222",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const readiness = assertJson(await requestJson(`http://127.0.0.1:${port}/bridge/route-readiness`), 200);
  assert.equal(readiness.items.length, 1);
  assert.equal(readiness.items[0].routeId, "btc-testnet-btc");
  assert.equal(readiness.items[0].phase, "mapped_route_only");
  assert.equal(readiness.items[0].full_loop_ready, false);
  assert.equal(readiness.items[0].capabilities.includes("operator_verified_deposit_proof"), true);
  assert.equal(readiness.items[0].capabilities.includes("manual_deposit_proof"), true);
  assert.equal(readiness.items[0].blockers.includes("automatic_source_release_not_supported"), true);
  assert.equal(readiness.summary.mapped_route_only, 1);
});
