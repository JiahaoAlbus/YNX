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

    if (url.pathname === "/net_info") {
      return res.end(JSON.stringify({
        result: {
          n_peers: "2",
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

    if (url.pathname === "/cosmos/staking/v1beta1/validators") {
      return res.end(JSON.stringify({
        validators: [
          {
            operator_address: "ynxvaloper1alpha",
            jailed: false,
            status: "BOND_STATUS_BONDED",
            description: { moniker: "Alpha" },
          },
        ],
      }));
    }

    if (url.pathname === "/bridge/health") {
      return res.end(JSON.stringify({
        ok: true,
        onchain: {
          enabled: false,
          ready: false,
          missing_requirements: ["bridge_onchain_disabled", "source_evm_private_key_required"],
          configuration_status: {
            rpc_configured: true,
            relayer_configured: false,
            remote_signer_configured: false,
            attester_configured: false,
            source_relayer_configured: false,
            btc_testnet_release_signer_configured: true,
            tron_shasta_release_signer_configured: true,
          },
          gateway_signer_set: {
            configured: true,
            signers: ["0xSignerA"],
            threshold: 1,
            epoch: 2,
          },
        },
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
          blockers: {
            total_routes_with_blockers: 3,
            by_blocker: {
              release_pending_signer: ["eth-sepolia-eth", "eth-sepolia-usdc"],
              source_lockbox_unconfigured: ["bnb-testnet-bnb"],
            },
          },
          requirements: {
            total_routes_with_requirements: 3,
            by_requirement: {
              BRIDGE_SOURCE_EVM_PRIVATE_KEY: ["eth-sepolia-eth", "eth-sepolia-usdc", "bnb-testnet-bnb"],
              "source lockbox deployment": ["bnb-testnet-bnb"],
            },
          },
          actions: [
            {
              blocker_class: "service_config_missing",
              required_configuration: ["BRIDGE_SOURCE_EVM_PRIVATE_KEY"],
              recommended_action: "Load BRIDGE_SOURCE_EVM_PRIVATE_KEY on bridge service to enable automatic release for routes: eth-sepolia-eth, eth-sepolia-usdc.",
              routes: ["eth-sepolia-eth", "eth-sepolia-usdc"],
              priority: "high",
            },
            {
              blocker_class: "contract_deployment_missing",
              required_configuration: ["source lockbox deployment", "lockboxAddress", "BRIDGE_SOURCE_EVM_PRIVATE_KEY"],
              recommended_action: "Deploy source lockbox, set lockboxAddress, and load BRIDGE_SOURCE_EVM_PRIVATE_KEY for routes: bnb-testnet-bnb.",
              routes: ["bnb-testnet-bnb"],
              priority: "high",
            },
          ],
          items: [
            {
              routeId: "eth-sepolia-eth",
              displayName: "Sepolia ETH",
              phase: "deposit_tested",
              blockers: ["release_pending_signer"],
              source: { live_check: true },
              automatic_loop_ready: false,
              evidence: { minted_deposits: 1, released_withdrawals: 1 },
              blocker_class: "service_config_missing",
              required_configuration: ["BRIDGE_SOURCE_EVM_PRIVATE_KEY"],
              recommended_action: "Load BRIDGE_SOURCE_EVM_PRIVATE_KEY on bridge service to enable automatic ethereum-sepolia release for eth-sepolia-eth.",
            },
            {
              routeId: "bnb-testnet-bnb",
              displayName: "BSC Testnet BNB",
              phase: "mapped_route_only",
              blockers: ["source_lockbox_unconfigured"],
              source: { live_check: false },
              automatic_loop_ready: false,
              evidence: { minted_deposits: 0, released_withdrawals: 1 },
              blocker_class: "contract_deployment_missing",
              required_configuration: ["source lockbox deployment", "lockboxAddress", "BRIDGE_SOURCE_EVM_PRIVATE_KEY"],
              recommended_action: "Deploy bsc-testnet source lockbox, set lockboxAddress, and load BRIDGE_SOURCE_EVM_PRIVATE_KEY for bnb-testnet-bnb.",
            },
          ],
        },
      }));
    }

    if (url.pathname === "/ai/health") {
      return res.end(JSON.stringify({
        ok: true,
        intelligence: {
          enabled: true,
          llm_configured: true,
          llm_provider: "ollama",
          model: "qwen2.5:1.5b",
        },
        onchain: {
          enabled: false,
          ready: false,
          configuration_status: {
            enabled_flag_present: false,
            rpc_configured: true,
            signer_configured: false,
            settlement_contract_configured: true,
          },
          missing_requirements: ["onchain_disabled", "onchain_private_key_required"],
          settlement_contract: "0x87e8a50880584abaB283cDeC18d884A7BDc42Fcf",
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
      YNX_PUBLIC_REST: `http://127.0.0.1:${rpcPort}`,
      YNX_PUBLIC_BRIDGE_HEALTH: `http://127.0.0.1:${rpcPort}/bridge/health`,
      YNX_PUBLIC_AI_GATEWAY: `http://127.0.0.1:${rpcPort}/ai`,
      YNX_PUBLIC_AI_HEALTH: `http://127.0.0.1:${rpcPort}/ai/health`,
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
  assert.equal(Array.isArray(overview.bridge.route_readiness.items), true);
  assert.equal(overview.bridge.onchain.configuration_status.source_relayer_configured, false);
  assert.equal(overview.bridge.onchain.gateway_signer_set.signers[0], "0xSignerA");
  assert.equal(overview.bridge.route_readiness.actions.length, 2);
  assert.equal(overview.bridge.route_readiness.actions[0].blocker_class, "service_config_missing");
  assert.equal(overview.bridge.route_readiness.actions[0].routes.length, 2);
  assert.equal(overview.bridge.route_readiness.actions[0].priority, "high");
  assert.equal(overview.ai_runtime.onchain.missing_requirements[0], "onchain_disabled");
  assert.equal(overview.ai_runtime.onchain.configuration_status.signer_configured, false);
  assert.match(overview.ai_runtime.onchain.recommended_action, /AI onchain gateway configuration/i);
  assert.equal(overview.ai_runtime.intelligence.model, "qwen2.5:1.5b");
  assert.equal(overview.execution_backlog[0].area, "bridge");
  assert.equal(overview.execution_backlog.at(-1).area, "ai_runtime");
  assert.equal(overview.headline_metrics.routes_deposit_tested, 4);
  assert.equal(overview.headline_metrics.bridge_configured_checks, 3);
  assert.equal(overview.headline_metrics.bridge_total_checks, 7);
  assert.equal(overview.headline_metrics.ai_onchain_ready, false);
  assert.equal(overview.headline_metrics.ai_configured_checks, 2);
  assert.equal(overview.headline_metrics.ai_total_checks, 4);
  assert.equal(overview.public_operations.title, "The shortest live proof board");
  assert.equal(overview.public_operations.chain_id, "ynx_9102-1");
  assert.equal(overview.public_operations.validator.chain_id, "ynx_9102-1");
  assert.equal(overview.public_operations.validator.bonded_count, 1);
  assert.equal(overview.public_operations.validator.signed_count, 1);
  assert.equal(overview.public_operations.validator.public_peers, 2);
  assert.equal(overview.public_operations.validator.peer_gate_pass, true);
  assert.deepEqual(overview.public_operations.validator.errors, []);
  assert.equal(overview.public_operations.validator.validators[0].moniker, "Alpha");
  assert.equal(overview.public_operations.validator.validators[0].operator, "ynxvaloper1alpha");
  assert.equal(overview.public_operations.routes.deposit_tested, 4);
  assert.equal(overview.public_operations.routes.release_observed, 5);
  assert.equal(overview.public_operations.routes.deposit_watchers_live, 1);
  assert.equal(overview.public_operations.cards[1].label, "Routes with deposit proof");
  assert.equal(overview.public_operations.cards[1].value, "4/5");
  assert.equal(overview.public_operations.cards[2].label, "Routes with any release proof");
  assert.equal(overview.public_operations.routes.blockers.some((item) => item.routeId === "bnb-testnet-bnb"), true);
  assert.equal(overview.public_operations.routes.blockers.find((item) => item.routeId === "bnb-testnet-bnb").required_configuration.includes("lockboxAddress"), true);
  assert.equal(typeof overview.public_operations.routes.blockers.find((item) => item.routeId === "bnb-testnet-bnb").signer_diagnostics, "object");
  assert.equal(overview.next_step.area, "bridge");
  assert.equal(overview.next_step.priority, "high");
  assert.equal(overview.next_step.blocker_class, "service_config_missing");
  assert.ok(overview.next_step.required_configuration.includes("BRIDGE_SOURCE_EVM_PRIVATE_KEY"));
  assert.equal(overview.readiness_scorecard.bridge.deposit_tested.completed, 4);
  assert.equal(overview.readiness_scorecard.bridge.configuration.configured, 3);
  assert.equal(overview.readiness_scorecard.bridge.configuration.total, 7);
  assert.equal(overview.readiness_scorecard.bridge.configuration.items.find((item) => item.key === "source_relayer_configured").configured, false);
  assert.equal(overview.readiness_scorecard.ai_runtime.onchain_ready, false);
  assert.equal(overview.readiness_scorecard.ai_runtime.configuration.configured, 2);
  assert.equal(overview.readiness_scorecard.ai_runtime.configuration.total, 4);
  assert.equal(overview.readiness_scorecard.ai_runtime.configuration.items.find((item) => item.key === "signer_configured").configured, false);

  const publicOps = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/ynx/public-operations`), 200);
  assert.equal(publicOps.ok, true);
  assert.equal(publicOps.title, "The shortest live proof board");
  assert.equal(publicOps.validator.chain_id, "ynx_9102-1");
  assert.equal(publicOps.validator.public_peers, 2);
  assert.equal(publicOps.validator.validators[0].moniker, "Alpha");
  assert.equal(publicOps.routes.deposit_tested, 4);
  assert.equal(typeof publicOps.routes.blockers.find((item) => item.routeId === "bnb-testnet-bnb").signer_diagnostics, "object");
  assert.equal(publicOps.cards[2].value, "5/5");
});

test("builds lot lineage and pro-rata taint tracking traces", async (t) => {
  const rpcPort = await getFreePort();
  const indexerPort = await getFreePort();
  const dataDir = await makeTempDir("ynx-indexer-trace-");
  const rpc = await startMockRpcServer(rpcPort);
  t.after(() => new Promise((resolve) => rpc.close(resolve)));

  await writeJson(path.join(dataDir, "state.json"), {
    last_height: 100,
    blocks_indexed: 5,
    txs_indexed: 5,
  });
  await fs.writeFile(
    path.join(dataDir, "blocks.jsonl"),
    [
      { height: 10, hash: "BLOCK10", time: "2026-06-20T00:00:00Z", proposer: "P", num_txs: 1, app_hash: "A" },
      { height: 11, hash: "BLOCK11", time: "2026-06-20T00:01:00Z", proposer: "P", num_txs: 1, app_hash: "A" },
      { height: 12, hash: "BLOCK12", time: "2026-06-20T00:02:00Z", proposer: "P", num_txs: 1, app_hash: "A" },
      { height: 13, hash: "BLOCK13", time: "2026-06-20T00:03:00Z", proposer: "P", num_txs: 1, app_hash: "A" },
      { height: 14, hash: "BLOCK14", time: "2026-06-20T00:04:00Z", proposer: "P", num_txs: 1, app_hash: "A" },
    ].map((item) => JSON.stringify(item)).join("\n") + "\n",
  );
  const txFixtures = [
    {
      hash: "0xTRACE01",
      height: 10,
      index: 0,
      code: 0,
      gas_wanted: 1,
      gas_used: 1,
      messages: [
        {
          "@type": "/cosmos.bank.v1beta1.MsgSend",
          from_address: "ynx1risky",
          to_address: "ynx1alice",
          amount: [{ denom: "anyxt", amount: "100" }],
        },
      ],
      send_flows: [{ message_index: 0, type: "bank_send", from: "ynx1risky", to: "ynx1alice", denom: "anyxt", amount: "100" }],
    },
    {
      hash: "0xTRACE02",
      height: 11,
      index: 0,
      code: 0,
      gas_wanted: 1,
      gas_used: 1,
      messages: [
        {
          "@type": "/cosmos.bank.v1beta1.MsgSend",
          from_address: "ynx1alice",
          to_address: "ynx1bob",
          amount: [{ denom: "anyxt", amount: "40" }],
        },
      ],
      send_flows: [{ message_index: 0, type: "bank_send", from: "ynx1alice", to: "ynx1bob", denom: "anyxt", amount: "40" }],
    },
    {
      hash: "0xTRACE03",
      height: 12,
      index: 0,
      code: 0,
      gas_wanted: 1,
      gas_used: 1,
      messages: [
        {
          "@type": "/cosmos.bank.v1beta1.MsgSend",
          from_address: "ynx1alice",
          to_address: "ynx1carol",
          amount: [{ denom: "anyxt", amount: "60" }],
        },
      ],
      send_flows: [{ message_index: 0, type: "bank_send", from: "ynx1alice", to: "ynx1carol", denom: "anyxt", amount: "60" }],
    },
    {
      hash: "0xTRACE04",
      height: 13,
      index: 0,
      code: 0,
      gas_wanted: 1,
      gas_used: 1,
      messages: [
        {
          "@type": "/cosmos.bank.v1beta1.MsgSend",
          from_address: "ynx1clean",
          to_address: "ynx1bob",
          amount: [{ denom: "anyxt", amount: "60" }],
        },
      ],
      send_flows: [{ message_index: 0, type: "bank_send", from: "ynx1clean", to: "ynx1bob", denom: "anyxt", amount: "60" }],
    },
    {
      hash: "0xTRACE05",
      height: 14,
      index: 0,
      code: 0,
      gas_wanted: 1,
      gas_used: 1,
      messages: [
        {
          "@type": "/cosmos.bank.v1beta1.MsgSend",
          from_address: "ynx1bob",
          to_address: "ynx1dave",
          amount: [{ denom: "anyxt", amount: "50" }],
        },
      ],
      send_flows: [{ message_index: 0, type: "bank_send", from: "ynx1bob", to: "ynx1dave", denom: "anyxt", amount: "50" }],
    },
  ];
  await fs.writeFile(path.join(dataDir, "txs.jsonl"), txFixtures.map((item) => JSON.stringify(item)).join("\n") + "\n");

  const server = await startNodeServer(
    serverPath,
    {
      INDEXER_RPC: `http://127.0.0.1:${rpcPort}`,
      INDEXER_PORT: String(indexerPort),
      INDEXER_DATA_DIR: dataDir,
      INDEXER_TRACE_DENOMS: "anyxt",
      INDEXER_TRACE_RISKY_ADDRESSES: "ynx1risky",
      YNX_PUBLIC_RPC: `http://127.0.0.1:${rpcPort}`,
      YNX_PUBLIC_REST: `http://127.0.0.1:${rpcPort}`,
      YNX_PUBLIC_BRIDGE_HEALTH: `http://127.0.0.1:${rpcPort}/bridge/health`,
      YNX_PUBLIC_AI_GATEWAY: `http://127.0.0.1:${rpcPort}/ai`,
      YNX_PUBLIC_AI_HEALTH: `http://127.0.0.1:${rpcPort}/ai/health`,
    },
    `http://127.0.0.1:${indexerPort}/health`,
  );
  t.after(async () => server.stop());

  const bob = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/trace/addresses/ynx1bob?denom=anyxt`), 200);
  assert.equal(bob.address, "ynx1bob");
  assert.equal(bob.balances[0].total_amount, "50");
  assert.equal(bob.balances[0].tainted_amount, "20");
  assert.equal(bob.balances[0].risk_basis_points, 4000);

  const dave = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/trace/addresses/ynx1dave?denom=anyxt`), 200);
  assert.equal(dave.balances[0].total_amount, "50");
  assert.equal(dave.balances[0].tainted_amount, "20");
  assert.equal(dave.balances[0].risk_basis_points, 4000);
  assert.equal(dave.balances[0].lots.length, 2);

  const txTrace = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/trace/txs/0xTRACE05`), 200);
  assert.equal(txTrace.tx_effect.flows[0].amount, "50");
  assert.equal(txTrace.tx_effect.flows[0].tainted_amount, "20");
  assert.equal(txTrace.tx_effect.flows[0].risk_basis_points, 4000);
  assert.equal(txTrace.tx_effect.flows[0].transferred_lots.length, 2);

  const graphUpstream = assertJson(
    await requestJson(`http://127.0.0.1:${indexerPort}/trace/graph?kind=address&target=ynx1dave&direction=upstream&max_depth=4&denom=anyxt`),
    200
  );
  assert.equal(graphUpstream.kind, "address");
  assert.equal(graphUpstream.target, "ynx1dave");
  assert.equal(graphUpstream.stats.edge_count >= 4, true);
  assert.equal(graphUpstream.nodes.addresses.some((item) => item.address === "ynx1risky"), true);
  assert.equal(graphUpstream.edges.some((item) => item.tx_hash === "0xTRACE05"), true);
  assert.equal(graphUpstream.edges.some((item) => item.traversal_direction === "upstream"), true);
  assert.equal(Array.isArray(graphUpstream.paths), true);
  assert.equal(graphUpstream.paths.some((item) => item.direction === "upstream"), true);
  assert.equal(graphUpstream.paths.some((item) => (item.tx_hashes || []).includes("0xTRACE01")), true);

  const graphDownstream = assertJson(
    await requestJson(`http://127.0.0.1:${indexerPort}/trace/graph?kind=address&target=ynx1alice&direction=downstream&max_depth=4&denom=anyxt`),
    200
  );
  assert.equal(graphDownstream.stats.edge_count >= 3, true);
  assert.equal(graphDownstream.nodes.addresses.some((item) => item.address === "ynx1dave"), true);
  assert.equal(graphDownstream.edges.some((item) => item.traversal_direction === "downstream"), true);
  assert.equal(graphDownstream.paths.some((item) => item.direction === "downstream"), true);
  assert.equal(graphDownstream.paths.some((item) => (item.addresses || []).includes("ynx1dave")), true);

  const lotId = dave.balances[0].lots[0].lot_id;
  const lotTrace = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/trace/lots/${lotId}`), 200);
  assert.equal(lotTrace.lot.owner, "ynx1dave");
  assert.equal(Array.isArray(lotTrace.lot.parent_lot_ids), true);

  const searchAddress = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/search?q=ynx1dave`), 200);
  assert.equal(searchAddress.kind, "trace_address");
  assert.equal(searchAddress.graph.stats.edge_count >= 1, true);
  assert.equal(searchAddress.graph.nodes.addresses.some((item) => item.address === "ynx1risky"), true);
  assert.equal(Array.isArray(searchAddress.graph.paths), true);

  const searchLot = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/search?q=${lotId}`), 200);
  assert.equal(searchLot.kind, "trace_lot");
  assert.equal(searchLot.graph.stats.lot_count >= 1, true);

  const searchTx = assertJson(await requestJson(`http://127.0.0.1:${indexerPort}/search?q=0xTRACE05`), 200);
  assert.equal(searchTx.kind, "trace_tx");
  assert.equal(searchTx.graph.stats.tx_count >= 1, true);
});
