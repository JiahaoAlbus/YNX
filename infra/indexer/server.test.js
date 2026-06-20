const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
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

function startMockRpcServer(port) {
  const server = require("node:http").createServer((req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    res.setHeader("content-type", "application/json");

    if (url.pathname === "/status") {
      return res.end(JSON.stringify({
        result: {
          node_info: { network: "ynx_9102-1" },
          sync_info: { latest_block_height: "100" },
        },
      }));
    }

    if (url.pathname === "/validators") {
      return res.end(JSON.stringify({
        result: {
          total: "1",
          validators: [
            {
              address: "ABCDEF1234567890",
              voting_power: "1000",
              proposer_priority: "7",
            },
          ],
        },
      }));
    }

    if (url.pathname === "/block") {
      return res.end(JSON.stringify({
        result: {
          block: {
            last_commit: {
              signatures: [
                {
                  block_id_flag: 2,
                  validator_address: "ABCDEF1234567890",
                },
              ],
            },
          },
        },
      }));
    }

    if (url.pathname === "/genesis") {
      return res.end(JSON.stringify({
        result: {
          genesis: {
            app_state: {
              ynx: {
                params: {
                  founder_address: "ynx1founder",
                  treasury_address: "ynx1treasury",
                  fee_burn_bps: 4000,
                  fee_treasury_bps: 1000,
                  fee_founder_bps: 0,
                  inflation_treasury_bps: 3000,
                },
                system: {
                  team_beneficiary_address: "ynx1team",
                  community_recipient_address: "ynx1community",
                },
              },
              feemarket: {
                params: {
                  no_base_fee: true,
                  base_fee: "",
                },
              },
            },
          },
        },
      }));
    }

    if (url.pathname === "/bridge/health") {
      return res.end(JSON.stringify({
        ok: true,
        stats: {
          routes: 5,
          validators: 4,
        },
        route_readiness: {
          ok: true,
          summary: {
            routes: 5,
            full_loop_ready: 2,
            full_loop_tested: 2,
            automatic_loop_ready: 2,
            deposit_tested: 4,
            release_evidence_observed: 5,
            mapped_route_only: 1,
          },
        },
      }));
    }

    res.statusCode = 404;
    return res.end(JSON.stringify({ error: "not_found" }));
  });

  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

test("supports validator detail and unified search", async (t) => {
  const rpcPort = await getFreePort();
  const indexerPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-indexer-test-");
  const rpc = await startMockRpcServer(rpcPort);
  t.after(() => new Promise((resolve) => rpc.close(resolve)));

  await writeJson(path.join(dataDir, "state.json"), {
    last_height: 100,
    blocks_indexed: 1,
    txs_indexed: 1,
  });
  await fs.writeFile(
    path.join(dataDir, "blocks.jsonl"),
    `${JSON.stringify({
      height: 88,
      hash: "BLOCKHASH88",
      time: "2026-06-20T00:00:00Z",
      proposer: "ABCDEF1234567890",
      num_txs: 1,
      app_hash: "APPHASH",
    })}\n`,
  );
  await fs.writeFile(
    path.join(dataDir, "txs.jsonl"),
    `${JSON.stringify({
      hash: "0xTXHASH88",
      height: 88,
      index: 0,
      code: 0,
      gas_wanted: 21000,
      gas_used: 21000,
    })}\n`,
  );

  const server = await startNodeServer(
    serverPath,
    {
      INDEXER_RPC: `http://127.0.0.1:${rpcPort}`,
      INDEXER_PORT: String(indexerPort),
      INDEXER_DATA_DIR: dataDir,
      YNX_PUBLIC_RPC: `http://127.0.0.1:${rpcPort}`,
      YNX_PUBLIC_BRIDGE_HEALTH: `http://127.0.0.1:${rpcPort}/bridge/health`,
    },
    `http://127.0.0.1:${indexerPort}/health`,
  );
  t.after(async () => server.stop());

  const validator = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/validators/ABCDEF1234567890`), 200);
  assert.equal(validator.validator.address, "ABCDEF1234567890");
  assert.equal(validator.validator.signed_last_block, true);

  const validatorSearch = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/search?q=ABCDEF1234567890`), 200);
  assert.equal(validatorSearch.kind, "validator");

  const blockSearch = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/search?q=88`), 200);
  assert.equal(blockSearch.kind, "block");
  assert.equal(blockSearch.block.hash, "BLOCKHASH88");

  const txSearch = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/search?q=0xTXHASH88`), 200);
  assert.equal(txSearch.kind, "tx");
  assert.equal(txSearch.tx.height, 88);

  const overview = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/ynx/overview`), 200);
  assert.equal(overview.endpoints.bridge_health, `http://127.0.0.1:${rpcPort}/bridge/health`);
  assert.equal(overview.bridge.ok, true);
  assert.equal(overview.bridge.route_readiness.summary.deposit_tested, 4);
  assert.equal(overview.bridge.route_readiness.summary.automatic_loop_ready, 2);
});
