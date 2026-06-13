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

function startMockSourceApis(port) {
  const server = require("node:http").createServer((req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    res.setHeader("content-type", "application/json");
    if (url.pathname === "/blocks/tip/height") return res.end("100");
    if (url.pathname === "/address/tb1qdeposit/txs") {
      return res.end(JSON.stringify([
        {
          txid: "btc-tx-1",
          status: { confirmed: true, block_height: 100 },
          vout: [{ scriptpubkey_address: "tb1qdeposit", value: 2500 }],
        },
      ]));
    }
    if (url.pathname === "/v1/accounts/TDeposit/transactions/trc20") {
      return res.end(JSON.stringify({
        data: [
          {
            transaction_id: "tron-tx-1",
            to: "TDeposit",
            from: "TSender",
            value: "4200000",
            block_timestamp: 12345,
          },
        ],
      }));
    }
    if (url.pathname === "/wallet/getnowblock") {
      return res.end(JSON.stringify({ block_header: { raw_data: { number: 100 } } }));
    }
    res.statusCode = 404;
    return res.end(JSON.stringify({ ok: false, error: "not_found" }));
  });
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

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

test("honors configured CORS allowlist for preflight requests", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-cors-");
  const server = await startNodeServer(
    serverPath,
    {
      BRIDGE_PORT: String(port),
      BRIDGE_DATA_DIR: dataDir,
      BRIDGE_ROUTES_FILE: routesFile,
      BRIDGE_ONCHAIN_ENABLED: "0",
      BRIDGE_CORS_ALLOWED_ORIGINS: "https://app.ynxweb4.com,https://ops.ynxweb4.com",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const response = await requestJson(`http://127.0.0.1:${port}/bridge/routes`, {
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

test("scans BTC and TRON testnet deposit watchers into automatic proofs", async (t) => {
  const port = await getFreePort();
  const sourcePort = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-non-evm-watchers-");
  const source = await startMockSourceApis(sourcePort);
  t.after(() => new Promise((resolve) => source.close(resolve)));
  const fixtureRoutesFile = path.join(dataDir, "routes-non-evm-watchers.json");
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
            sourceKind: "bitcoin",
            sourceNetwork: "bitcoin-testnet",
            sourceChainId: "18332",
            sourceAssetId: "0x42dce463fe146e09f3002678bf279aadb46a211e0d8f482f6e768bbb7222f6d6",
            wrappedToken: "0x1887Eb24feefB6538CBc2140B148ba831f313991",
            wrappedSymbol: "wBTC.y",
            decimals: 8,
            minConfirmations: 1,
            rpc: `http://127.0.0.1:${sourcePort}`,
            depositAddress: "tb1qdeposit",
            autoMintRecipient: "0x00000000000000000000000000000000000000aa",
          },
          {
            routeId: "tron-shasta-usdt",
            asset: "USDT",
            displayName: "Shasta TRC20 USDT",
            sourceKind: "tron",
            sourceNetwork: "tron-shasta",
            sourceChainId: "2494104990",
            sourceAssetId: "0xf83cc5a2424525ab621183d35781c7e4945cb1dfd40bbf20b896f30dd550972c",
            sourceContract: "TUsdt",
            wrappedToken: "0xB7fFfD780C1a1800d0bBD16FDbfb678cEbFe22E1",
            wrappedSymbol: "wUSDT.y",
            decimals: 6,
            minConfirmations: 1,
            rpc: `http://127.0.0.1:${sourcePort}`,
            depositAddress: "TDeposit",
            autoMintRecipient: "0x00000000000000000000000000000000000000aa",
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
      BRIDGE_ONCHAIN_ENABLED: "0",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const scan = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/watchers/scan`, {
      method: "POST",
      body: {},
    }),
    200,
  );
  assert.equal(scan.ok, true);
  assert.equal(scan.items.length, 2);
  assert.equal(scan.items[0].matched, 1);
  assert.equal(scan.items[1].matched, 1);

  const deposits = assertJson(await requestJson(`http://127.0.0.1:${port}/bridge/deposits`), 200);
  assert.equal(deposits.items.length, 2);
  assert.equal(deposits.items.every((item) => item.proof.automatic === true), true);
  assert.equal(deposits.items.every((item) => item.status === "accepted_dry_run"), true);
});

test("testnet non-EVM release adapter requires signer and enforces caps", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-bridge-non-evm-release-");
  const fixtureRoutesFile = path.join(dataDir, "routes-non-evm-release.json");
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
            sourceKind: "bitcoin",
            sourceNetwork: "bitcoin-testnet",
            sourceChainId: "18332",
            sourceAssetId: "0x42dce463fe146e09f3002678bf279aadb46a211e0d8f482f6e768bbb7222f6d6",
            wrappedToken: "0x1887Eb24feefB6538CBc2140B148ba831f313991",
            wrappedSymbol: "wBTC.y",
            decimals: 8,
            rpc: "http://127.0.0.1:1",
            maxAutoReleaseBaseUnits: "1000",
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
      BRIDGE_ONCHAIN_ENABLED: "0",
      BRIDGE_WITHDRAWAL_RELEASE_ENABLED: "1",
      BRIDGE_NON_EVM_RELEASE_MOCK: "1",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/withdrawals/request`, {
      method: "POST",
      body: {
        route_id: "btc-testnet-btc",
        destination_recipient: "tb1qrelease",
        amount_base_units: "500",
      },
    }),
    201,
  );
  assert.equal(created.withdrawal.status, "queued");

  const released = assertJson(
    await requestJson(`http://127.0.0.1:${port}/bridge/withdrawals/${created.withdrawal.withdrawal_id}/release`, {
      method: "POST",
      body: {},
    }),
    200,
  );
  assert.equal(released.ok, true);
  assert.equal(released.withdrawal.status, "released");
  assert.equal(released.withdrawal.release.automatic, true);
  assert.match(released.withdrawal.release.boundary, /public-testnet/);
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
  assert.equal(readiness.items[0].blockers.includes("release_unsupported"), true);
  assert.equal(readiness.summary.mapped_route_only, 1);
});
