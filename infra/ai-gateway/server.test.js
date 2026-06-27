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
  writeJson,
} = require("../test-helpers");

const serverPath = path.join(__dirname, "server.js");

function startMockIntelligenceUpstreams(port) {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    res.setHeader("content-type", "application/json");
    if (url.pathname === "/bridge/health") {
      return res.end(JSON.stringify({ ok: true, stats: { minted_deposits: 3, released_withdrawals: 2 } }));
    }
    if (url.pathname === "/bridge/route-readiness") {
      return res.end(JSON.stringify({
        ok: true,
        summary: { routes: 5, deposit_tested: 4, release_evidence_observed: 5, full_loop_tested: 2, automatic_loop_ready: 2 },
        items: [
          { routeId: "btc-testnet-btc", phase: "full_loop_tested", full_loop_tested: true, automatic_loop_ready: true, evidence: { released_withdrawals: 1 } },
          { routeId: "eth-sepolia-eth", phase: "deposit_tested", evidence: { released_withdrawals: 1 } },
          { routeId: "bnb-testnet-bnb", phase: "mapped_route_only", blockers: ["source_lockbox_unconfigured"], evidence: { released_withdrawals: 1 } },
          { routeId: "tron-shasta-usdt", phase: "full_loop_tested", full_loop_tested: true, automatic_loop_ready: true, evidence: { released_withdrawals: 1 } },
          { routeId: "eth-sepolia-usdc", phase: "deposit_tested", evidence: { released_withdrawals: 1 } },
        ],
      }));
    }
    if (url.pathname === "/bridge/assets") {
      return res.end(JSON.stringify({
        ok: true,
        assets: [
          { symbol: "NYXT", kind: "native", decimals: 18, denom: "anyxt", evmContract: "0x0000000000000000000000000000000000000009", status: "live" },
          { symbol: "YUSD.test", kind: "synthetic-test-stable-asset", decimals: 6, contract: "0x0000000000000000000000000000000000000001", redeemable: false, mainnetValue: false, status: "live" },
          { symbol: "wUSDC.y", kind: "wrapped-testnet-asset", decimals: 6, contract: "0x0000000000000000000000000000000000000002", routeId: "eth-sepolia-usdc", status: "live" },
          { symbol: "wETH.y", kind: "wrapped-testnet-asset", decimals: 18, contract: "0x0000000000000000000000000000000000000003", routeId: "eth-sepolia-eth", status: "live" },
        ],
        pairs: [
          { label: "wUSDC.y/YUSD.test", pair: "0x0000000000000000000000000000000000000011", type: "constant-product-amm", feeBps: 30, status: "live" },
          { label: "wETH.y/YUSD.test", pair: "0x0000000000000000000000000000000000000012", type: "constant-product-amm", feeBps: 30, status: "live" },
        ],
        riskNotice: "Public-testnet assets only.",
      }));
    }
    if (req.method === "POST" && url.pathname === "/bridge/watchers/scan") {
      if (req.headers["x-ynx-bridge-token"] !== "bridge-token-test") {
        res.statusCode = 401;
        return res.end(JSON.stringify({ ok: false, error: "operator_token_required" }));
      }
      return res.end(JSON.stringify({ ok: true, scanned: [{ routeId: "eth-sepolia-usdc", events_seen: 1 }] }));
    }
    if (req.method === "POST" && url.pathname === "/bridge/withdrawal-watchers/scan") {
      if (req.headers["x-ynx-bridge-token"] !== "bridge-token-test") {
        res.statusCode = 401;
        return res.end(JSON.stringify({ ok: false, error: "operator_token_required" }));
      }
      return res.end(JSON.stringify({ ok: true, scanned: [{ routeId: "eth-sepolia-usdc", withdrawals_queued: 1 }] }));
    }
    if (url.pathname === "/ready") {
      return res.end(JSON.stringify({ ok: true, checks: { persistence: true } }));
    }
    if (url.pathname === "/ynx/overview") {
      return res.end(JSON.stringify({ ok: true, chain_id: "ynx_9102-1", latest_height: 42, track: "v2-web4" }));
    }
    if (url.pathname === "/validators") {
      return res.end(JSON.stringify({
        ok: true,
        latest_height: 42,
        total: 2,
        signed_count: 2,
        validators: [
          { address: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", voting_power: 1000, proposer_priority: 3, signed_last_block: true },
          { address: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", voting_power: 501, proposer_priority: -3, signed_last_block: true },
        ],
      }));
    }
    if (url.pathname === "/trace/addresses/ynx1victim") {
      if (req.headers["x-ynx-trace-token"] !== "trace-token-test") {
        res.statusCode = 401;
        return res.end(JSON.stringify({ ok: false, error: "trace_token_required" }));
      }
      return res.end(JSON.stringify({
        ok: true,
        address: "ynx1victim",
        balances: [
          {
            denom: "anyxt",
            total_amount: "50",
            tainted_amount: "20",
            risk_basis_points: 4000,
            lots: [
              { lot_id: "lot_00000009", amount: "20", tainted_amount: "20", risk_basis_points: 10000, root_origin_lot_id: "lot_00000001" },
              { lot_id: "lot_00000010", amount: "30", tainted_amount: "0", risk_basis_points: 0, root_origin_lot_id: "lot_00000008" },
            ],
          },
        ],
      }));
    }
    if (url.pathname === "/trace/graph" && url.searchParams.get("target") === "ynx1victim") {
      if (req.headers["x-ynx-trace-token"] !== "trace-token-test") {
        res.statusCode = 401;
        return res.end(JSON.stringify({ ok: false, error: "trace_token_required" }));
      }
      return res.end(JSON.stringify({
        ok: true,
        kind: "address",
        target: "ynx1victim",
        options: {
          direction: url.searchParams.get("direction") || "both",
          max_depth: Number(url.searchParams.get("max_depth") || 4),
          denom: url.searchParams.get("denom") || "",
          min_amount: "0",
          min_tainted_amount: "0",
          since_height: 0,
          until_height: 0,
        },
        nodes: {
          addresses: [
            { id: "ynx1origin", type: "address", address: "ynx1origin" },
            { id: "ynx1source", type: "address", address: "ynx1source" },
            { id: "ynx1bridgea", type: "address", address: "ynx1bridgea" },
            { id: "ynx1bridgeb", type: "address", address: "ynx1bridgeb" },
            { id: "ynx1victim", type: "address", address: "ynx1victim" },
          ],
          lots: [
            { id: "lot_00000000", type: "lot", lot_id: "lot_00000000", owner: "ynx1origin", denom: "anyxt", current_amount: "0", tainted_amount: "20", root_origin_lot_id: "lot_00000000" },
            { id: "lot_00000001", type: "lot", lot_id: "lot_00000001", owner: "ynx1source", denom: "anyxt", current_amount: "0", tainted_amount: "20", root_origin_lot_id: "lot_00000001" },
            { id: "lot_00000005", type: "lot", lot_id: "lot_00000005", owner: "ynx1bridgea", denom: "wETH.y", current_amount: "0", tainted_amount: "20", root_origin_lot_id: "lot_00000001" },
            { id: "lot_00000007", type: "lot", lot_id: "lot_00000007", owner: "ynx1bridgeb", denom: "wUSDC.y", current_amount: "0", tainted_amount: "20", root_origin_lot_id: "lot_00000001" },
            { id: "lot_00000009", type: "lot", lot_id: "lot_00000009", owner: "ynx1victim", denom: "anyxt", current_amount: "20", tainted_amount: "20", root_origin_lot_id: "lot_00000001" },
          ],
          txs: [
            { id: "0xTRACECASEPRE", type: "tx", tx_hash: "0xTRACECASEPRE", height: 10, index: 0 },
            { id: "0xTRACECASE00", type: "tx", tx_hash: "0xTRACECASE00", height: 75, index: 0 },
            { id: "0xTRACECASE00B", type: "tx", tx_hash: "0xTRACECASE00B", height: 76, index: 0 },
            { id: "0xTRACECASE01", type: "tx", tx_hash: "0xTRACECASE01", height: 77, index: 0 },
          ],
        },
        edges: [
          {
            tx_hash: "0xTRACECASEPRE",
            height: 10,
            index: 0,
            from: "ynx1origin",
            to: "ynx1source",
            denom: "anyxt",
            amount: "20",
            tainted_amount: "20",
            risk_basis_points: 10000,
            source_lot_id: "lot_00000000",
            child_lot_id: "lot_00000001",
            root_origin_lot_id: "lot_00000001",
            traversal_direction: "upstream",
            depth: 4,
          },
          {
            tx_hash: "0xTRACECASE00",
            height: 75,
            index: 0,
            from: "ynx1source",
            to: "ynx1bridgea",
            denom: "wETH.y",
            amount: "20",
            tainted_amount: "20",
            risk_basis_points: 10000,
            source_lot_id: "lot_00000001",
            child_lot_id: "lot_00000005",
            root_origin_lot_id: "lot_00000001",
            traversal_direction: "upstream",
            depth: 3,
          },
          {
            tx_hash: "0xTRACECASE00B",
            height: 76,
            index: 0,
            from: "ynx1bridgea",
            to: "ynx1bridgeb",
            denom: "wUSDC.y",
            amount: "20",
            tainted_amount: "20",
            risk_basis_points: 10000,
            source_lot_id: "lot_00000005",
            child_lot_id: "lot_00000007",
            root_origin_lot_id: "lot_00000001",
            traversal_direction: "upstream",
            depth: 2,
          },
          {
            tx_hash: "0xTRACECASE01",
            height: 77,
            index: 0,
            from: "ynx1bridgeb",
            to: "ynx1victim",
            denom: "wUSDC.y",
            amount: "20",
            tainted_amount: "20",
            risk_basis_points: 10000,
            source_lot_id: "lot_00000007",
            child_lot_id: "lot_00000009",
            root_origin_lot_id: "lot_00000001",
            traversal_direction: "upstream",
            depth: 1,
          },
        ],
        stats: {
          address_count: 5,
          lot_count: 5,
          tx_count: 4,
          edge_count: 4,
          max_depth_reached: 4,
        },
        updated_at: "2026-06-26T00:00:00.000Z",
      }));
    }
    res.statusCode = 404;
    return res.end(JSON.stringify({ ok: false, error: "not_found" }));
  });
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

function startMockOllama(port) {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    res.setHeader("content-type", "application/json");
    if (req.method === "POST" && url.pathname === "/api/chat") {
      let raw = "";
      req.on("data", (chunk) => {
        raw += chunk.toString();
      });
      req.on("end", () => {
        const body = raw ? JSON.parse(raw) : {};
        return res.end(JSON.stringify({
          model: body.model || "qwen2.5:1.5b",
          message: { role: "assistant", content: "mock ollama intelligence answer" },
        }));
      });
      return;
    }
    res.statusCode = 404;
    return res.end(JSON.stringify({ ok: false, error: "not_found" }));
  });
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

function startMockEvmRpc(port) {
  const txHash = "0x1111111111111111111111111111111111111111111111111111111111111111";
  const server = http.createServer((req, res) => {
    res.setHeader("content-type", "application/json");
    if (req.method !== "POST") {
      res.statusCode = 404;
      return res.end(JSON.stringify({ ok: false, error: "not_found" }));
    }
    let raw = "";
    req.on("data", (chunk) => {
      raw += chunk.toString();
    });
    req.on("end", () => {
      const body = raw ? JSON.parse(raw) : {};
      if (body.method === "eth_getBlockByNumber") {
        return res.end(JSON.stringify({
          jsonrpc: "2.0",
          id: body.id,
          result: {
            number: "0x2a",
            hash: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            timestamp: "0x69400000",
            transactions: [
              {
                hash: txHash,
                from: "0x0000000000000000000000000000000000000001",
                to: "0x0000000000000000000000000000000000000002",
                value: "0x64",
                nonce: "0x1",
                gas: "0x5208",
                gasPrice: "0x1",
                input: "0x",
              },
            ],
          },
        }));
      }
      if (body.method === "eth_getTransactionReceipt") {
        return res.end(JSON.stringify({
          jsonrpc: "2.0",
          id: body.id,
          result: {
            transactionHash: txHash,
            status: "0x1",
            gasUsed: "0x5208",
            logs: [],
          },
        }));
      }
      if (body.method === "eth_call") {
        return res.end(JSON.stringify({
          jsonrpc: "2.0",
          id: body.id,
          result: "0x00000000000000000000000000000000000000000000000000000000000186a0",
        }));
      }
      return res.end(JSON.stringify({ jsonrpc: "2.0", id: body.id, result: null }));
    });
  });
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve({ server, txHash }));
  });
}

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

test("honors configured CORS allowlist for preflight requests", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-cors-");
  const server = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(port),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_CORS_ALLOWED_ORIGINS: "https://app.ynxweb4.com,https://ops.ynxweb4.com",
    },
    `http://127.0.0.1:${port}/ready`,
  );
  t.after(async () => server.stop());

  const response = await requestJson(`http://127.0.0.1:${port}/ai/jobs`, {
    method: "OPTIONS",
    headers: { origin: "https://app.ynxweb4.com" },
  });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("access-control-allow-origin"), "https://app.ynxweb4.com");
  assert.equal(response.headers.get("vary"), "origin");

  const ready = await requestJson(`http://127.0.0.1:${port}/ready`, {
    headers: { origin: "https://app.ynxweb4.com" },
  });
  assert.equal(ready.headers.get("access-control-allow-origin"), "https://app.ynxweb4.com");
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
      AI_ENFORCE_POLICY: "0",
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
        policy_id: policy.policy.policy_id,
      },
    }),
    201
  );
  assert.equal(created.vault.policy_id, policy.policy.policy_id);
});

test("rejects direct balance bootstrap on vault creation by default", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-vault-bootstrap-disabled-");
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

  const created = await requestJson(`http://127.0.0.1:${port}/ai/vaults`, {
    method: "POST",
    body: {
      owner: "owner-bootstrap",
      balance: 100,
    },
  });
  assert.equal(created.status, 400);
  assert.equal(created.body.error, "vault_balance_bootstrap_disabled");
});

test("rejects local vault deposits by default", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-local-deposit-disabled-");
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
        owner: "owner-local-deposit",
      },
    }),
    201
  );

  const deposit = await requestJson(`http://127.0.0.1:${port}/ai/vaults/${vault.vault.vault_id}/deposit`, {
    method: "POST",
    body: {
      amount: 10,
    },
  });
  assert.equal(deposit.status, 400);
  assert.equal(deposit.body.error, "local_vault_deposit_disabled");
});

test("protects job and vault read surfaces behind scoped Web4 sessions", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-read-scope-");
  const web4Dir = await makeTempDir("ynx-web4-read-scope-");
  const internalToken = "test-internal-token-read-scope";
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
      AI_ALLOW_LOCAL_VAULT_DEPOSITS: "1",
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
      body: {
        owner: "owner-read-scope",
        allowed_actions: ["ai.vault.create", "ai.vault.read", "ai.job.create", "ai.job.read"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.vault.create", "ai.vault.read", "ai.job.create", "ai.job.read"],
        ttl_sec: 600,
        max_ops: 6,
      },
    }),
    201
  );

  const createdVault = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        owner: "ynx1owner",
        policy_id: policy.policy.policy_id,
      },
    }),
    201
  );

  const createdJob = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/jobs`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        creator: "ops",
        reward: "0",
        stake: "0",
        input_uri: "ynx://job/read-scope",
        policy_id: policy.policy.policy_id,
      },
    }),
    201
  );

  const publicJobsDenied = await requestJson(`http://127.0.0.1:${aiPort}/ai/jobs`);
  assert.equal(publicJobsDenied.status, 400);
  assert.equal(publicJobsDenied.body.error, "policy_id_required");

  const publicVaultsDenied = await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`);
  assert.equal(publicVaultsDenied.status, 400);
  assert.equal(publicVaultsDenied.body.error, "policy_id_required");

  const scopedJobs = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/jobs?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(scopedJobs.items.length, 1);
  assert.equal(scopedJobs.items[0].job_id, createdJob.job.job_id);

  const scopedVaults = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(scopedVaults.items.length, 1);
  assert.equal(scopedVaults.items[0].vault_id, createdVault.vault.vault_id);

  const scopedJob = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/jobs/${createdJob.job.job_id}?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(scopedJob.job.job_id, createdJob.job.job_id);

  const scopedVault = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults/${createdVault.vault.vault_id}?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(scopedVault.vault.vault_id, createdVault.vault.vault_id);
});

test("protects payment detail reads behind scoped Web4 sessions", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-payment-read-scope-");
  const web4Dir = await makeTempDir("ynx-web4-payment-read-scope-");
  const internalToken = "test-internal-token-payment-read-scope";
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
      AI_ALLOW_LOCAL_VAULT_DEPOSITS: "1",
      AI_WEB4_HUB_URL: `http://127.0.0.1:${web4Port}`,
      AI_WEB4_INTERNAL_TOKEN: internalToken,
      AI_CHAIN_ID: "ynx_9102-1",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const policyA = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-payment-a",
        allowed_actions: ["ai.vault.create", "ai.vault.deposit", "ai.payment.charge", "ai.payment.read"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const sessionA = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policyA.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policyA.owner_secret },
      body: {
        capabilities: ["ai.vault.create", "ai.vault.deposit", "ai.payment.charge", "ai.payment.read"],
        ttl_sec: 600,
        max_ops: 6,
        max_spend: 100,
      },
    }),
    201
  );

  const policyB = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-payment-b",
        allowed_actions: ["ai.payment.read"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const sessionB = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policyB.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policyB.owner_secret },
      body: {
        capabilities: ["ai.payment.read"],
        ttl_sec: 600,
        max_ops: 6,
      },
    }),
    201
  );

  const vault = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`, {
      method: "POST",
      headers: { "x-ynx-session": sessionA.token },
      body: {
        owner: "owner-payment-a",
        policy_id: policyA.policy.policy_id,
      },
    }),
    201
  );

  assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults/${vault.vault.vault_id}/deposit`, {
      method: "POST",
      headers: { "x-ynx-session": sessionA.token },
      body: {
        amount: 50,
      },
    }),
    200
  );

  const charged = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/payments/charge`, {
      method: "POST",
      headers: { "x-ynx-session": sessionA.token },
      body: {
        vault_id: vault.vault.vault_id,
        policy_id: policyA.policy.policy_id,
        amount: 5,
        resource: "safe-resource",
      },
    }),
    200
  );

  const publicDenied = await requestJson(`http://127.0.0.1:${aiPort}/ai/payments/${charged.payment.payment_id}`);
  assert.equal(publicDenied.status, 401);
  assert.equal(publicDenied.body.error, "session_required");

  const ownRead = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/payments/${charged.payment.payment_id}?policy_id=${encodeURIComponent(policyA.policy.policy_id)}`, {
      headers: { "x-ynx-session": sessionA.token },
    }),
    200
  );
  assert.equal(ownRead.payment.payment_id, charged.payment.payment_id);

  const crossRead = await requestJson(`http://127.0.0.1:${aiPort}/ai/payments/${charged.payment.payment_id}?policy_id=${encodeURIComponent(policyB.policy.policy_id)}`, {
    headers: { "x-ynx-session": sessionB.token },
  });
  assert.equal(crossRead.status, 404);
  assert.equal(crossRead.body.error, "payment_not_found");
});

test("redacts sensitive values from AI audit read surfaces", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-audit-redact-");
  const web4Dir = await makeTempDir("ynx-web4-ai-audit-redact-");
  const internalToken = "test-internal-token-ai-audit-redact";
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
      body: {
        owner: "owner-audit-redact",
        allowed_actions: ["ai.vault.create", "ai.audit.read"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.vault.create", "ai.audit.read"],
        ttl_sec: 600,
      },
    }),
    201
  );

  await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`, {
    method: "POST",
    headers: { "x-ynx-session": session.token },
    body: {
      owner: "owner-audit-redact",
      policy_id: policy.policy.policy_id,
    },
  });

  const audit = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/audit?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
      headers: { "x-ynx-session": session.token },
    }),
    200
  );
  assert.equal(Array.isArray(audit.items), true);
  const serialized = JSON.stringify(audit);
  assert.doesNotMatch(serialized, /ses_[a-z0-9]{12,}/i);
  assert.doesNotMatch(serialized, /owner_secret|private[_-]?key|mnemonic/i);
});

test("denies AI action when policy service host allowlist does not include gateway host", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-host-deny-");
  const web4Dir = await makeTempDir("ynx-web4-host-deny-");
  const internalToken = "test-internal-token-host-deny";
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
      body: {
        owner: "owner-host-deny",
        allowed_actions: ["ai.vault.create"],
        allowed_service_hosts: ["api.partner.example.com"],
      },
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
      },
    }),
    201
  );

  const denied = await requestJson(`http://127.0.0.1:${aiPort}/ai/vaults`, {
    method: "POST",
    headers: { "x-ynx-session": session.token },
    body: {
      owner: "owner-host-deny",
      policy_id: policy.policy.policy_id,
    },
  });
  assert.equal(denied.status, 403);
  assert.equal(denied.body.error, "policy_service_host_denied");
});

test("rejects x402 delivery when settled payment resource does not match request", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-x402-");
  const server = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(port),
      AI_DATA_DIR: dataDir,
      AI_ALLOW_LOCAL_VAULT_DEPOSITS: "1",
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
        max_daily_spend: 100,
        max_per_payment: 100,
      },
    }),
    201
  );

  assertJson(
    await requestJson(`http://127.0.0.1:${port}/ai/vaults/${vault.vault.vault_id}/deposit`, {
      method: "POST",
      body: {
        amount: 100,
      },
    }),
    200
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

test("reports on-chain readiness and fails requested on-chain writes when signer config is missing", async (t) => {
  const port = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-onchain-missing-");
  const server = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(port),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_ONCHAIN_ENABLED: "1",
      AI_ONCHAIN_RPC_URL: "http://127.0.0.1:18545",
      AI_SETTLEMENT_CONTRACT: "0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf",
    },
    `http://127.0.0.1:${port}/health`
  );
  t.after(async () => server.stop());

  const ready = await requestJson(`http://127.0.0.1:${port}/ready`);
  assert.equal(ready.status, 503);
  assert.equal(ready.body.checks.onchain, false);

  const health = assertJson(await requestJson(`http://127.0.0.1:${port}/health`), 200);
  assert.equal(health.onchain.enabled, true);
  assert.equal(health.onchain.ready, false);
  assert.equal(health.onchain.configuration_status.rpc_configured, true);
  assert.equal(health.onchain.configuration_status.signer_configured, false);
  assert.equal(health.onchain.configuration_status.settlement_contract_configured, true);
  assert.equal(health.onchain.signer_configured, false);
  assert.equal(health.onchain.settlement_contract, "0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf");
  assert.ok(health.onchain.missing_requirements.includes("onchain_private_key_required"));
  assert.match(health.onchain.recommended_action, /missing AI onchain gateway configuration/i);

  const created = await requestJson(`http://127.0.0.1:${port}/ai/vaults`, {
    method: "POST",
    body: {
      owner: "owner-onchain",
      balance: 0,
      onchain: true,
      onchain_value_wei: "0",
    },
  });
  assert.equal(created.status, 502);
  assert.equal(created.body.error, "onchain_vault_create_failed");
  assert.match(created.body.detail, /private_key|required/i);
});

test("answers intelligence chat from live context without an LLM key", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-intelligence-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_API_KEY: "",
      OPENAI_API_KEY: "",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_WEB4_HUB_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const health = assertJson(await requestJson(`http://127.0.0.1:${aiPort}/health`), 200);
  assert.equal(health.intelligence.enabled, true);
  assert.equal(health.intelligence.mode, "live-deterministic");

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "我们现在 AI 和交易状态怎么样？" },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.equal(chat.mode, "live-deterministic");
  assert.match(chat.answer, /YNX Intelligence/);
  assert.match(chat.answer, /full-loop-tested|full_loop_tested|闭环/);
});

test("answers validator status questions from live indexer data", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-validators-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_API_KEY: "",
      OPENAI_API_KEY: "",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "我们链验证人的状态怎么样？" },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.match(chat.answer, /验证人状态/);
  assert.match(chat.answer, /上一块签名：2\/2/);
  assert.doesNotMatch(chat.answer, /交易\/桥状态/);
});

test("answers circulating asset questions from live bridge asset data", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-assets-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_API_KEY: "",
      OPENAI_API_KEY: "",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "给我我们 chain 上面现在能够流通的货币？" },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.match(chat.answer, /NYXT/);
  assert.match(chat.answer, /YUSD\.test/);
  assert.match(chat.answer, /wUSDC\.y/);
  assert.match(chat.answer, /wETH\.y/);
  assert.match(chat.answer, /wUSDC\.y\/YUSD\.test/);
  assert.doesNotMatch(chat.answer, /产品定位建议/);
});

test("answers combined asset layer and trading requests without dropping intent", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-combined-trade-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_API_KEY: "",
      OPENAI_API_KEY: "",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "帮我查看我们链现在有哪些货币以及现在的层数和你帮我交易一下" },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.match(chat.answer, /NYXT/);
  assert.match(chat.answer, /L1|层级|层/);
  assert.match(chat.answer, /trade\.preflight|交易前检查/);
  assert.match(chat.answer, /trade\.prepare|交易参数/);
  assert.match(chat.answer, /钱包签名|wallet signature/);
});

test("quotes, preflights, and prepares public AMM trades as AI actions", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const evmPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-trade-quote-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  const evm = await startMockEvmRpc(evmPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));
  t.after(() => new Promise((resolve) => evm.server.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "1",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_WEB4_HUB_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_EVM_RPC_URL: `http://127.0.0.1:${evmPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const quote = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      body: { action: "trade.quote", from_symbol: "YUSD.test", to_symbol: "wUSDC.y", amount: "0.1" },
    }),
    200
  );
  assert.equal(quote.ok, true);
  assert.equal(quote.result.from_symbol, "YUSD.test");
  assert.equal(quote.result.to_symbol, "wUSDC.y");
  assert.equal(quote.result.amount_out, "0.1");
  assert.match(quote.result.execution_boundary, /quote_only/);

  const preflight = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      body: { action: "trade.preflight", from_symbol: "YUSD.test", to_symbol: "wUSDC.y", amount: "0.1" },
    }),
    200
  );
  assert.equal(preflight.ok, true);
  assert.equal(preflight.result.pair.label, "wUSDC.y/YUSD.test");
  assert.equal(preflight.result.validators.all_signed_last_block, true);
  assert.match(preflight.result.risk_notice, /Public-testnet/);
  assert.match(preflight.result.execution_boundary, /preflight_only/);

  const prepared = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      body: {
        action: "trade.prepare",
        from_symbol: "YUSD.test",
        to_symbol: "wUSDC.y",
        amount: "0.1",
        recipient: "0x00000000000000000000000000000000000000aa",
      },
    }),
    200
  );
  assert.equal(prepared.ok, true);
  assert.equal(prepared.result.approve.to, "0x0000000000000000000000000000000000000001");
  assert.equal(prepared.result.swap.to, "0x0000000000000000000000000000000000000011");
  assert.match(prepared.result.approve.data, /^0x095ea7b3/);
  assert.match(prepared.result.swap.data, /^0xf3e6ea8a/);
  assert.match(prepared.result.risk.boundary, /wallet_signature_required/);
  const serialized = JSON.stringify(prepared);
  assert.doesNotMatch(serialized, /private[_-]?key|mnemonic|seed phrase/i);
  assert.doesNotMatch(serialized, /server signer/i);

  const execute = await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
    method: "POST",
    body: {
      action: "trade.execute",
      from_symbol: "YUSD.test",
      to_symbol: "wUSDC.y",
      amount: "0.1",
      recipient: "0x00000000000000000000000000000000000000aa",
    },
  });
  assert.equal(execute.status, 400);
  assert.equal(execute.body.ok, false);
  assert.equal(execute.body.error, "policy_required");
});

test("grounds feature suggestions in live YNX assets and settlement context", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-grounded-features-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_PROVIDER: "ollama",
      AI_LLM_MODEL: "qwen2.5:1.5b",
      AI_LLM_BASE_URL: "http://127.0.0.1:1/api/chat",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "给 YNX AI 交易助手第一版提三个功能建议，简短。" },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.equal(chat.mode, "live-deterministic");
  assert.match(chat.answer, /wUSDC\.y\/YUSD\.test/);
  assert.match(chat.answer, /验证人签名/);
  assert.match(chat.answer, /AI vault\/payment\/job|AI 结算/);
  assert.doesNotMatch(chat.answer, /行情预测/);
});

test("exposes AI actions and runs public read actions", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-actions-read-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const actions = assertJson(await requestJson(`http://127.0.0.1:${aiPort}/ai/actions`), 200);
  assert.equal(actions.ok, true);
  assert.ok(actions.actions.some((item) => item.action === "assets.list"));
  assert.ok(actions.actions.some((item) => item.action === "trade.preflight"));
  assert.ok(actions.actions.some((item) => item.action === "trade.prepare"));
  assert.ok(actions.actions.some((item) => item.action === "trade.execute" && /web4-session/.test(item.auth)));
  assert.ok(actions.actions.some((item) => item.action === "ai.monitor.create"));

  const assets = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      body: { action: "assets.list" },
    }),
    200
  );
  assert.equal(assets.ok, true);
  assert.equal(assets.result.assets[0].symbol, "NYXT");
  assert.equal(assets.result.pairs[0].label, "wUSDC.y/YUSD.test");
});

test("protects AI action writes with Web4 policy sessions", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const mockPort = await getFreePort();
  const evmPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-actions-write-");
  const web4Dir = await makeTempDir("ynx-web4-actions-write-");
  const internalToken = "test-internal-token-actions";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  const evm = await startMockEvmRpc(evmPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));
  t.after(() => new Promise((resolve) => evm.server.close(resolve)));

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
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_EVM_RPC_URL: `http://127.0.0.1:${evmPort}`,
      AI_BRIDGE_OPERATOR_TOKEN: "bridge-token-test",
      AI_TRADE_AGENT_MOCK: "1",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const denied = await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
    method: "POST",
    body: { action: "ai.monitor.create", target: "validators" },
  });
  assert.equal(denied.status, 400);
  assert.equal(denied.body.error, "policy_required");

  const policy = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-actions",
        allowed_actions: ["ai.job.create", "ai.bridge.watchers.scan", "ai.trade.execute"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.job.create", "ai.bridge.watchers.scan", "ai.trade.execute"],
        ttl_sec: 600,
        max_ops: 4,
      },
    }),
    201
  );

  const monitor = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "ai.monitor.create",
        policy_id: policy.policy.policy_id,
        target: "validators",
      },
    }),
    201
  );
  assert.equal(monitor.ok, true);
  assert.equal(monitor.job.metadata.kind, "monitor");
  assert.equal(monitor.job.policy_id, policy.policy.policy_id);

  const scan = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "bridge.watchers.scan",
        policy_id: policy.policy.policy_id,
        route_id: "eth-sepolia-usdc",
      },
    }),
    200
  );
  assert.equal(scan.ok, true);
  assert.equal(scan.upstream.ok, true);

  const trade = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "trade.execute",
        policy_id: policy.policy.policy_id,
        from_symbol: "YUSD.test",
        to_symbol: "wUSDC.y",
        amount: "0.1",
        recipient: "0x00000000000000000000000000000000000000aa",
      },
    }),
    200
  );
  assert.equal(trade.ok, true);
  assert.equal(trade.result.mode, "testnet-agent-mock");
  assert.match(trade.result.swap_tx_hash, /^0x[0-9a-f]{64}$/);
  assert.doesNotMatch(JSON.stringify(trade), /private[_-]?key|mnemonic|seed phrase|raw signer/i);
});

test("builds protected AI trace reports through Web4 policy and internal trace token", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-trace-");
  const web4Dir = await makeTempDir("ynx-web4-trace-");
  const internalToken = "test-internal-token-trace";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

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
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_TRACE_INDEXER_TOKEN: "trace-token-test",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const denied = await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
    method: "POST",
    body: { action: "ai.trace.report", target: "ynx1victim" },
  });
  assert.equal(denied.status, 400);
  assert.equal(denied.body.error, "policy_required");

  const policy = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-trace",
        allowed_actions: ["ai.trace.report"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.trace.report"],
        ttl_sec: 600,
        max_ops: 3,
      },
    }),
    201
  );

  const report = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "ai.trace.report",
        policy_id: policy.policy.policy_id,
        target: "ynx1victim",
        kind: "address",
      },
    }),
    200
  );
  assert.equal(report.ok, true);
  assert.equal(report.report.kind, "address");
  assert.equal(report.report.trace.address, "ynx1victim");
  assert.equal(report.report.trace.balances[0].tainted_amount, "20");
  assert.equal(report.report.guardrails.observation_only, true);
  assert.equal(report.report.guardrails.transfer_authority_granted, false);
  assert.match(report.report.summary, /not authorize|不代表/i);
});

test("creates protected structured forensics cases with risk and evidence", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-forensics-case-");
  const web4Dir = await makeTempDir("ynx-web4-forensics-case-");
  const internalToken = "test-internal-token-forensics";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

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
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_TRACE_INDEXER_TOKEN: "trace-token-test",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const policy = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-case",
        allowed_actions: ["ai.forensics.case.create", "ai.forensics.case.read"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.forensics.case.create", "ai.forensics.case.read"],
        ttl_sec: 600,
        max_ops: 3,
      },
    }),
    201
  );

  const forensicCase = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "ai.forensics.case.create",
        policy_id: policy.policy.policy_id,
        target: "ynx1victim",
        kind: "address",
      },
    }),
    201
  );
  assert.equal(forensicCase.ok, true);
  assert.equal(forensicCase.case.subject, "ynx1victim");
  assert.equal(forensicCase.case.risk.score, 40);
  assert.equal(forensicCase.case.risk.severity, "medium");
  assert.equal(forensicCase.case.taint_models.poison.tainted, true);
  assert.equal(forensicCase.case.taint_models.proRata.taintRatio, 0.4);
  assert.ok(Array.isArray(forensicCase.case.taint_models.fifo.matchedTaintedLots));
  assert.ok(Array.isArray(forensicCase.case.taint_models.lifo.matchedTaintedLots));
  assert.equal(forensicCase.case.taint_models.specificTrace.exactLineageAvailable, true);
  assert.ok(Array.isArray(forensicCase.case.evidence_chain));
  assert.ok(forensicCase.case.evidence_chain.length > 0);
  assert.ok(Array.isArray(forensicCase.case.traced_paths));
  assert.ok(forensicCase.case.traced_paths.some((item) => item.tx_hash === "0xTRACECASE01"));
  assert.equal(forensicCase.case.flow_graph.stats.edge_count, 4);
  assert.ok(Array.isArray(forensicCase.case.suspicious_patterns));
  assert.ok(forensicCase.case.suspicious_patterns.some((item) => item.pattern_type === "mixed_exposure"));
  assert.ok(forensicCase.case.suspicious_patterns.some((item) => item.pattern_type === "rapid_multi_hop_transfers"));
  assert.ok(forensicCase.case.suspicious_patterns.some((item) => item.pattern_type === "time_correlated_routing"));
  assert.ok(forensicCase.case.suspicious_patterns.some((item) => item.pattern_type === "dormant_wallet_reactivated"));
  assert.ok(forensicCase.case.suspicious_patterns.some((item) => item.pattern_type === "bridge_hop_exposure"));
  assert.ok(forensicCase.case.suspicious_patterns.some((item) => item.pattern_type === "pass_through_wallet_behavior"));
  assert.equal(forensicCase.case.entity_attribution.entity_type, "bridge_exposed_account");
  assert.ok(Array.isArray(forensicCase.case.address_clusters));
  assert.ok(forensicCase.case.address_clusters.length > 0);
  assert.equal(forensicCase.case.address_clusters[0].reasons.some((item) => item.type === "linked_counterparties"), true);
  assert.equal(forensicCase.case.address_clusters[0].reasons.some((item) => item.type === "bridge_route_exposure"), true);
  assert.equal(forensicCase.case.cluster_summary.total_clusters, 1);
  assert.equal(forensicCase.case.cluster_summary.total_addresses >= 2, true);
  assert.equal(forensicCase.case.cluster_summary.by_reason_type.bridge_route_exposure >= 1, true);
  assert.equal(forensicCase.case.case_dossier.primary_disposition, "manual review required");
  assert.equal(forensicCase.case.case_dossier.operational_state.review_status, "open");
  assert.equal(forensicCase.case.case_dossier.subject_profile.label, "bridge_exposed_account");
  assert.equal(Array.isArray(forensicCase.case.case_dossier.key_findings), true);
  assert.equal(forensicCase.case.case_dossier.key_findings.some((item) => item.type === "risk_summary"), true);
  assert.equal(Array.isArray(forensicCase.case.case_dossier.evidence_index), true);
  assert.equal(forensicCase.case.case_dossier.evidence_index.length > 0, true);
  assert.equal(Array.isArray(forensicCase.case.case_dossier.action_queue), true);
  assert.equal(forensicCase.case.case_dossier.action_queue[0].status, "pending");
  assert.ok(forensicCase.case.recommended_next_actions.includes("manual review required"));
  assert.equal(forensicCase.case.guardrails.transfer_authority_granted, false);

  const listed = assertJson(await requestJson(`http://127.0.0.1:${aiPort}/ai/forensics/cases?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
    headers: { "x-ynx-session": session.token },
  }), 200);
  assert.equal(listed.items.length, 1);
  assert.equal(listed.items[0].case_id, forensicCase.case.case_id);
});

test("prefers configured static entity label providers over inferred attribution when present", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-forensics-label-provider-");
  const web4Dir = await makeTempDir("ynx-web4-forensics-label-provider-");
  const internalToken = "test-internal-token-forensics-label-provider";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

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
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_TRACE_INDEXER_TOKEN: "trace-token-test",
      AI_ENTITY_LABELS_JSON: JSON.stringify({
        labels: [
          {
            match: { address: "ynx1victim" },
            entity_type: "known_exchange_deposit",
            label: "Mock Exchange Deposit Cluster",
            confidence: 0.99,
            reasons: ["matched local investigator label fixture"],
            tags: ["exchange", "deposit_cluster"],
          },
        ],
      }),
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const policy = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-case-label-provider",
        allowed_actions: ["ai.forensics.case.create"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.forensics.case.create"],
        ttl_sec: 600,
        max_ops: 3,
      },
    }),
    201
  );

  const forensicCase = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "ai.forensics.case.create",
        policy_id: policy.policy.policy_id,
        target: "ynx1victim",
        kind: "address",
      },
    }),
    201
  );

  assert.equal(forensicCase.case.entity_attribution.entity_type, "known_exchange_deposit");
  assert.equal(forensicCase.case.entity_attribution.label, "Mock Exchange Deposit Cluster");
  assert.equal(forensicCase.case.entity_attribution.provider, "static_labels");
  assert.equal(forensicCase.case.entity_attribution.tags.includes("exchange"), true);
  assert.equal(forensicCase.case.entity_attribution.matched_subjects.addresses.includes("ynx1victim"), true);
});

test("reviews and escalates forensics cases through protected operator flow", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-forensics-review-");
  const web4Dir = await makeTempDir("ynx-web4-forensics-review-");
  const internalToken = "test-internal-token-forensics-review";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

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
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_TRACE_INDEXER_TOKEN: "trace-token-test",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const policy = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-case-review",
        allowed_actions: ["ai.forensics.case.create", "ai.forensics.case.review", "ai.forensics.case.read"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const session = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policy.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policy.owner_secret },
      body: {
        capabilities: ["ai.forensics.case.create", "ai.forensics.case.review", "ai.forensics.case.read"],
        ttl_sec: 600,
        max_ops: 5,
      },
    }),
    201
  );

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        action: "ai.forensics.case.create",
        policy_id: policy.policy.policy_id,
        target: "ynx1victim",
        kind: "address",
      },
    }),
    201
  );

  const reviewed = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/forensics/cases/${created.case.case_id}/review`, {
      method: "POST",
      headers: { "x-ynx-session": session.token },
      body: {
        policy_id: policy.policy.policy_id,
        reviewer: "ops-1",
        review_action: "manual_review",
        next_status: "escalated",
        escalation_status: "compliance_queue",
        note: "High confidence taint exposure and bridge-linked flow.",
      },
    }),
    200
  );

  assert.equal(reviewed.ok, true);
  assert.equal(reviewed.case.review_status, "escalated");
  assert.equal(reviewed.case.escalation_status, "compliance_queue");
  assert.ok(Array.isArray(reviewed.case.review_logs));
  assert.equal(reviewed.case.review_logs[0].reviewer, "ops-1");
  assert.equal(reviewed.case.review_logs[0].next_status, "escalated");

  const fetched = assertJson(await requestJson(`http://127.0.0.1:${aiPort}/ai/forensics/cases/${created.case.case_id}?policy_id=${encodeURIComponent(policy.policy.policy_id)}`, {
    headers: { "x-ynx-session": session.token },
  }), 200);
  assert.equal(fetched.case.case_id, created.case.case_id);
  assert.equal(fetched.case.review_status, "escalated");
  assert.equal(fetched.case.case_dossier.operational_state.review_status, "escalated");
  assert.equal(fetched.case.guardrails.freeze_authority_granted, false);
});

test("protects forensic case reads and denies cross-policy case review access", async (t) => {
  const aiPort = await getFreePort();
  const web4Port = await getFreePort();
  const mockPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-forensics-policy-scope-");
  const web4Dir = await makeTempDir("ynx-web4-forensics-policy-scope-");
  const internalToken = "test-internal-token-forensics-scope";
  const web4ServerPath = path.join(__dirname, "..", "web4-hub", "server.js");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));

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
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_TRACE_INDEXER_TOKEN: "trace-token-test",
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const policyA = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-case-a",
        allowed_actions: ["ai.forensics.case.create", "ai.forensics.case.read", "ai.forensics.case.review"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const sessionA = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policyA.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policyA.owner_secret },
      body: {
        capabilities: ["ai.forensics.case.create", "ai.forensics.case.read", "ai.forensics.case.review"],
        ttl_sec: 600,
        max_ops: 6,
      },
    }),
    201
  );

  const policyB = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies`, {
      method: "POST",
      body: {
        owner: "owner-ai-case-b",
        allowed_actions: ["ai.forensics.case.read", "ai.forensics.case.review"],
        allowed_service_hosts: ["127.0.0.1"],
      },
    }),
    201
  );
  const sessionB = assertJson(
    await requestJson(`http://127.0.0.1:${web4Port}/web4/policies/${policyB.policy.policy_id}/sessions`, {
      method: "POST",
      headers: { "x-ynx-owner": policyB.owner_secret },
      body: {
        capabilities: ["ai.forensics.case.read", "ai.forensics.case.review"],
        ttl_sec: 600,
        max_ops: 6,
      },
    }),
    201
  );

  const created = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/actions/run`, {
      method: "POST",
      headers: { "x-ynx-session": sessionA.token },
      body: {
        action: "ai.forensics.case.create",
        policy_id: policyA.policy.policy_id,
        target: "ynx1victim",
        kind: "address",
      },
    }),
    201
  );

  const publicDenied = await requestJson(`http://127.0.0.1:${aiPort}/ai/forensics/cases`);
  assert.equal(publicDenied.status, 400);
  assert.equal(publicDenied.body.error, "policy_id_required");

  const wrongPolicyFetch = await requestJson(`http://127.0.0.1:${aiPort}/ai/forensics/cases/${created.case.case_id}?policy_id=${encodeURIComponent(policyB.policy.policy_id)}`, {
    headers: { "x-ynx-session": sessionB.token },
  });
  assert.equal(wrongPolicyFetch.status, 404);
  assert.equal(wrongPolicyFetch.body.error, "case_not_found");

  const wrongPolicyReview = await requestJson(`http://127.0.0.1:${aiPort}/ai/forensics/cases/${created.case.case_id}/review`, {
    method: "POST",
    headers: { "x-ynx-session": sessionB.token },
    body: {
      policy_id: policyB.policy.policy_id,
      reviewer: "ops-b",
      next_status: "escalated",
      escalation_status: "compliance_queue",
      note: "Should not be able to mutate another policy's case.",
    },
  });
  assert.equal(wrongPolicyReview.status, 403);
  assert.equal(wrongPolicyReview.body.error, "case_policy_denied");
});

test("answers intelligence chat through configured Ollama provider", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const ollamaPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-ollama-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  const ollama = await startMockOllama(ollamaPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));
  t.after(() => new Promise((resolve) => ollama.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_PROVIDER: "ollama",
      AI_LLM_MODEL: "qwen2.5:1.5b",
      AI_LLM_BASE_URL: `http://127.0.0.1:${ollamaPort}/api/chat`,
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const health = assertJson(await requestJson(`http://127.0.0.1:${aiPort}/health`), 200);
  assert.equal(health.intelligence.mode, "llm:ollama");
  assert.equal(health.intelligence.model, "qwen2.5:1.5b");

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "Summarize YNX.", include_model_answer: true },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.equal(chat.mode, "llm:ollama");
  assert.equal(chat.model, "qwen2.5:1.5b");
  assert.equal(chat.answer, "mock ollama intelligence answer");
  assert.equal(chat.model_answer, "mock ollama intelligence answer");
});

test("answers latest transaction questions from live EVM RPC data", async (t) => {
  const aiPort = await getFreePort();
  const mockPort = await getFreePort();
  const evmPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-ai-latest-tx-");
  const mock = await startMockIntelligenceUpstreams(mockPort);
  const evm = await startMockEvmRpc(evmPort);
  t.after(() => new Promise((resolve) => mock.close(resolve)));
  t.after(() => new Promise((resolve) => evm.server.close(resolve)));

  const ai = await startNodeServer(
    serverPath,
    {
      AI_GATEWAY_PORT: String(aiPort),
      AI_DATA_DIR: dataDir,
      AI_ENFORCE_POLICY: "0",
      AI_CHAIN_ID: "ynx_9102-1",
      AI_LLM_API_KEY: "",
      OPENAI_API_KEY: "",
      AI_PUBLIC_BRIDGE_URL: `http://127.0.0.1:${mockPort}/bridge`,
      AI_PUBLIC_WEB4_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_INDEXER_URL: `http://127.0.0.1:${mockPort}`,
      AI_PUBLIC_EVM_RPC_URL: `http://127.0.0.1:${evmPort}`,
    },
    `http://127.0.0.1:${aiPort}/ready`
  );
  t.after(async () => ai.stop());

  const chat = assertJson(
    await requestJson(`http://127.0.0.1:${aiPort}/ai/chat`, {
      method: "POST",
      body: { message: "用中文简短总结 YNX 链上最后一次交易数据。" },
    }),
    200
  );
  assert.equal(chat.ok, true);
  assert.match(chat.answer, new RegExp(evm.txHash));
  assert.match(chat.answer, /实时查询|EVM RPC/);
});
