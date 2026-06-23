const http = require("http");
const https = require("https");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const readline = require("readline");

function loadEnvFile(filePath) {
  if (!filePath || !fs.existsSync(filePath)) return;
  const content = fs.readFileSync(filePath, "utf8");
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const idx = line.indexOf("=");
    if (idx === -1) continue;
    const key = line.slice(0, idx).trim();
    let value = line.slice(idx + 1).trim();
    if ((value.startsWith("\"") && value.endsWith("\"")) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
}

const envCandidates = [];
if (process.env.INDEXER_ENV_FILE) envCandidates.push(process.env.INDEXER_ENV_FILE);
if (process.env.YNX_ENV_FILE) envCandidates.push(process.env.YNX_ENV_FILE);
envCandidates.push(path.resolve(__dirname, ".env"));
envCandidates.push(path.resolve(__dirname, "../../.env"));
for (const candidate of envCandidates) {
  loadEnvFile(candidate);
}

function envNumber(name, fallback) {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = parseInt(raw, 10);
  return Number.isFinite(value) ? value : fallback;
}

const INDEXER_RPC = process.env.INDEXER_RPC || "http://127.0.0.1:26657";
const INDEXER_PORT = envNumber("INDEXER_PORT", 8081);
const INDEXER_POLL_MS = envNumber("INDEXER_POLL_MS", 1000);
const INDEXER_CACHE_SIZE = envNumber("INDEXER_CACHE_SIZE", 500);
const INDEXER_TX_CACHE_SIZE = envNumber("INDEXER_TX_CACHE_SIZE", 2000);
const INDEXER_BACKFILL = envNumber("INDEXER_BACKFILL", 0);
const INDEXER_START_HEIGHT = envNumber("INDEXER_START_HEIGHT", 0);
const DATA_DIR = process.env.INDEXER_DATA_DIR || path.resolve(__dirname, "data");
const STATE_PATH = path.join(DATA_DIR, "state.json");
const BLOCKS_PATH = path.join(DATA_DIR, "blocks.jsonl");
const TXS_PATH = path.join(DATA_DIR, "txs.jsonl");
const LINEAGE_STATE_PATH = path.join(DATA_DIR, "lineage-state.json");
const YNX_FOUNDER_ADDRESS = process.env.YNX_FOUNDER_ADDRESS || "";
const YNX_TREASURY_ADDRESS = process.env.YNX_TREASURY_ADDRESS || "";
const YNX_TEAM_BENEFICIARY = process.env.YNX_TEAM_BENEFICIARY || "";
const YNX_COMMUNITY_RECIPIENT = process.env.YNX_COMMUNITY_RECIPIENT || "";
const YNX_FEE_BURN_BPS = envNumber("YNX_FEE_BURN_BPS", 4000);
const YNX_FEE_TREASURY_BPS = envNumber("YNX_FEE_TREASURY_BPS", 1000);
const YNX_FEE_FOUNDER_BPS = envNumber("YNX_FEE_FOUNDER_BPS", 1000);
const YNX_INFLATION_TREASURY_BPS = envNumber("YNX_INFLATION_TREASURY_BPS", 3000);
const YNX_NO_BASE_FEE = process.env.YNX_NO_BASE_FEE;
const YNX_OVERVIEW_TRACK = process.env.YNX_OVERVIEW_TRACK || "v2-web4";
const YNX_POSITIONING_STATEMENT =
  process.env.YNX_POSITIONING_STATEMENT ||
  "AI-native Web4 chain: Ethereum-grade developer UX with Solana-class performance targets";
const YNX_DENOM = process.env.YNX_DENOM || "anyxt";
const YNX_MIN_GAS_PRICES = process.env.YNX_MIN_GAS_PRICES || `0.000000007${YNX_DENOM}`;
const YNX_PUBLIC_RPC = process.env.YNX_PUBLIC_RPC || process.env.YNX_RPC || INDEXER_RPC;
const YNX_PUBLIC_EVM_RPC = process.env.YNX_PUBLIC_EVM_RPC || process.env.YNX_EVM_RPC || "http://127.0.0.1:38545";
const YNX_PUBLIC_EVM_WS = process.env.YNX_PUBLIC_EVM_WS || process.env.YNX_EVM_WS || "ws://127.0.0.1:38546";
const YNX_PUBLIC_REST = process.env.YNX_PUBLIC_REST || process.env.YNX_REST || "http://127.0.0.1:31317";
const YNX_PUBLIC_GRPC = process.env.YNX_PUBLIC_GRPC || process.env.YNX_GRPC || "http://127.0.0.1:39090";
const YNX_PUBLIC_FAUCET = process.env.YNX_PUBLIC_FAUCET || process.env.YNX_FAUCET || "http://127.0.0.1:38080";
const YNX_PUBLIC_INDEXER = process.env.YNX_PUBLIC_INDEXER || process.env.YNX_INDEXER || `http://127.0.0.1:${INDEXER_PORT}`;
const YNX_PUBLIC_EXPLORER = process.env.YNX_PUBLIC_EXPLORER || process.env.YNX_EXPLORER || "http://127.0.0.1:38082";
const YNX_PUBLIC_AI_GATEWAY = process.env.YNX_PUBLIC_AI_GATEWAY || process.env.YNX_AI_GATEWAY || "http://127.0.0.1:38090";
const YNX_PUBLIC_WEB4_HUB = process.env.YNX_PUBLIC_WEB4_HUB || process.env.YNX_WEB4_HUB || "http://127.0.0.1:38091";
const YNX_PUBLIC_BRIDGE_HEALTH =
  process.env.YNX_PUBLIC_BRIDGE_HEALTH || `${YNX_PUBLIC_RPC.replace(/\/$/, "")}/bridge/health`;
const YNX_PUBLIC_AI_HEALTH = process.env.YNX_PUBLIC_AI_HEALTH || `${YNX_PUBLIC_AI_GATEWAY.replace(/\/$/, "")}/health`;
const YNX_BRIDGE_OVERVIEW_TIMEOUT_MS = envNumber("YNX_BRIDGE_OVERVIEW_TIMEOUT_MS", 2000);
const YNX_BRIDGE_OVERVIEW_CACHE_MS = envNumber("YNX_BRIDGE_OVERVIEW_CACHE_MS", 30000);
const YNX_AI_OVERVIEW_TIMEOUT_MS = envNumber("YNX_AI_OVERVIEW_TIMEOUT_MS", 2000);
const YNX_AI_OVERVIEW_CACHE_MS = envNumber("YNX_AI_OVERVIEW_CACHE_MS", 30000);
const YNX_QUERY_REST = process.env.INDEXER_YNX_REST || YNX_PUBLIC_REST;
const YNX_SEEDS = process.env.YNX_SEEDS || "";
const YNX_PERSISTENT_PEERS = process.env.YNX_PERSISTENT_PEERS || "";
const YNX_BINARY_VERSION = process.env.YNX_BINARY_VERSION || "local-build";
const YNX_RELEASE_URL = process.env.YNX_RELEASE_URL || "";
const YNX_DESCRIPTOR_URL = process.env.YNX_DESCRIPTOR_URL || "";
const INDEXER_TRACE_DENOMS = (process.env.INDEXER_TRACE_DENOMS || `${YNX_DENOM},YUSD.test`)
  .split(",")
  .map((item) => String(item || "").trim())
  .filter(Boolean);
const INDEXER_TRACE_RISKY_ADDRESSES = new Set(
  (process.env.INDEXER_TRACE_RISKY_ADDRESSES || "")
    .split(",")
    .map((item) => String(item || "").trim())
    .filter(Boolean),
);

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

let state = { last_height: 0, blocks_indexed: 0, txs_indexed: 0 };
if (fs.existsSync(STATE_PATH)) {
  try {
    state = JSON.parse(fs.readFileSync(STATE_PATH, "utf8"));
  } catch {
    state = { last_height: 0, blocks_indexed: 0, txs_indexed: 0 };
  }
}

function saveState() {
  fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2));
}

function log(message) {
  const stamp = new Date().toISOString();
  console.log(`[${stamp}] ${message}`);
}

function rpcRequest(pathname) {
  const url = new URL(pathname, INDEXER_RPC);
  const lib = url.protocol === "https:" ? https : http;
  return new Promise((resolve, reject) => {
    const req = lib.request(url, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk.toString();
      });
      res.on("end", () => {
        try {
          const json = JSON.parse(data);
          resolve(json);
        } catch (err) {
          reject(new Error(`RPC JSON parse failed: ${err.message}`));
        }
      });
    });
    req.on("error", reject);
    req.end();
  });
}

function httpJsonRequest(target, timeoutMs = 8000) {
  const url = new URL(target);
  const lib = url.protocol === "https:" ? https : http;
  return new Promise((resolve, reject) => {
    const req = lib.request(url, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk.toString();
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(data || "{}"));
        } catch (err) {
          reject(new Error(`HTTP JSON parse failed: ${err.message}`));
        }
      });
    });
    req.setTimeout(timeoutMs, () => req.destroy(new Error("http_timeout")));
    req.on("error", reject);
    req.end();
  });
}

async function fetchDecodedTxsByHeight(height) {
  const base = YNX_QUERY_REST.replace(/\/$/, "");
  try {
    const response = await httpJsonRequest(`${base}/cosmos/tx/v1beta1/txs/block/${height}`, 8000);
    return Array.isArray(response?.txs) ? response.txs : [];
  } catch {
    return [];
  }
}

function appendJsonLine(filePath, payload) {
  fs.appendFileSync(filePath, `${JSON.stringify(payload)}\n`);
}

async function loadBridgeOverview() {
  const now = Date.now();
  if (
    loadBridgeOverview.cache &&
    loadBridgeOverview.cache.expiresAt > now &&
    loadBridgeOverview.cache.value
  ) {
    return loadBridgeOverview.cache.value;
  }
  try {
    const bridgeHealth = await httpJsonRequest(YNX_PUBLIC_BRIDGE_HEALTH, YNX_BRIDGE_OVERVIEW_TIMEOUT_MS);
    const routeReadiness = bridgeHealth?.route_readiness || {};
    const value = {
      ok: bridgeHealth?.ok !== false,
      health_url: YNX_PUBLIC_BRIDGE_HEALTH,
      stats: bridgeHealth?.stats || null,
      onchain: bridgeHealth?.onchain
        ? {
            enabled: bridgeHealth.onchain.enabled !== false,
            ready: bridgeHealth.onchain.ready !== false,
            missing_requirements: bridgeHealth.onchain.missing_requirements || [],
            configuration_status: bridgeHealth.onchain.configuration_status || null,
            gateway_signer_set: bridgeHealth.onchain.gateway_signer_set || null,
          }
        : null,
      route_readiness: {
        ok: routeReadiness?.ok !== false,
        summary: routeReadiness?.summary || null,
        blockers: routeReadiness?.blockers || null,
        requirements: routeReadiness?.requirements || null,
        items: Array.isArray(routeReadiness?.items)
          ? routeReadiness.items.map((item) => ({
              routeId: item.routeId || "",
              displayName: item.displayName || item.routeId || "",
              phase: item.phase || "",
              automatic_loop_ready: item.automatic_loop_ready === true,
              blockers: item.blockers || [],
              required_configuration: item.required_configuration || [],
              recommended_action: item.recommended_action || "",
              signer_diagnostics: item.signer_diagnostics || null,
              source_live: item?.source?.live_check === true,
              evidence: {
                minted_deposits: Number(item?.evidence?.minted_deposits || 0),
                released_withdrawals: Number(item?.evidence?.released_withdrawals || 0),
              },
            }))
          : [],
        actions: Array.isArray(routeReadiness?.actions)
          ? routeReadiness.actions.map((item) => ({
              blocker_class: item.blocker_class,
              required_configuration: item.required_configuration || [],
              recommended_action: item.recommended_action || "",
              routes: item.routes || [],
              priority: item.priority || "medium",
            }))
          : Array.isArray(routeReadiness?.items)
          ? routeReadiness.items
              .filter((item) => item && item.blocker_class && item.blocker_class !== "ready")
              .map((item) => ({
                routeId: item.routeId,
                blocker_class: item.blocker_class,
                required_configuration: item.required_configuration || [],
                recommended_action: item.recommended_action || "",
              }))
          : [],
      },
    };
    loadBridgeOverview.cache = {
      value,
      expiresAt: now + YNX_BRIDGE_OVERVIEW_CACHE_MS,
    };
    return value;
  } catch (err) {
    if (loadBridgeOverview.cache?.value) {
      return {
        ...loadBridgeOverview.cache.value,
        ok: false,
        stale: true,
        error: "bridge_health_stale_cache",
        detail: err.message,
        cached_at: new Date(loadBridgeOverview.cache.expiresAt - YNX_BRIDGE_OVERVIEW_CACHE_MS).toISOString(),
      };
    }
    return {
      ok: false,
      health_url: YNX_PUBLIC_BRIDGE_HEALTH,
      error: "bridge_health_unavailable",
      detail: err.message,
      route_readiness: {
        ok: false,
        summary: null,
      },
    };
  }
}

async function loadAiOverview() {
  const now = Date.now();
  if (
    loadAiOverview.cache &&
    loadAiOverview.cache.expiresAt > now &&
    loadAiOverview.cache.value
  ) {
    return loadAiOverview.cache.value;
  }
  try {
    const aiHealth = await httpJsonRequest(YNX_PUBLIC_AI_HEALTH, YNX_AI_OVERVIEW_TIMEOUT_MS);
    const aiMissing = aiHealth?.onchain?.missing_requirements || [];
    const value = {
      ok: aiHealth?.ok !== false,
      health_url: YNX_PUBLIC_AI_HEALTH,
      onchain: aiHealth?.onchain
        ? {
            enabled: aiHealth.onchain.enabled !== false,
            ready: aiHealth.onchain.ready !== false,
            missing_requirements: aiMissing,
            settlement_contract: aiHealth.onchain.settlement_contract || "",
            configuration_status: aiHealth.onchain.configuration_status || null,
            recommended_action:
              aiMissing.length > 0
                ? "Load the missing AI onchain gateway configuration so policy-bounded settlement can submit onchain."
                : "",
          }
        : null,
      intelligence: aiHealth?.intelligence
        ? {
            enabled: aiHealth.intelligence.enabled !== false,
            llm_configured: aiHealth.intelligence.llm_configured !== false,
            llm_provider: aiHealth.intelligence.llm_provider || "",
            model: aiHealth.intelligence.model || "",
          }
        : null,
    };
    loadAiOverview.cache = {
      value,
      expiresAt: now + YNX_AI_OVERVIEW_CACHE_MS,
    };
    return value;
  } catch (err) {
    if (loadAiOverview.cache?.value) {
      return {
        ...loadAiOverview.cache.value,
        ok: false,
        stale: true,
        error: "ai_health_stale_cache",
        detail: err.message,
        cached_at: new Date(loadAiOverview.cache.expiresAt - YNX_AI_OVERVIEW_CACHE_MS).toISOString(),
      };
    }
    return {
      ok: false,
      health_url: YNX_PUBLIC_AI_HEALTH,
      error: "ai_health_unavailable",
      detail: err.message,
      onchain: null,
      intelligence: null,
    };
  }
}

function buildPublicOperations(validatorSnapshot, validatorDetails, bridge, publicPeers = 0) {
  const summary = bridge?.route_readiness?.summary || {};
  const items = bridge?.route_readiness?.items || [];
  const routeTotal = Number(summary.routes || 0);
  const bondedCount = Number(validatorSnapshot?.total || 0);
  const signedCount = Number(validatorSnapshot?.signed_count || 0);
  const minValidators = 4;
  const minPublicPeers = 2;
  const depositTested = Number(summary.deposit_tested || 0);
  const releaseObserved = Number(summary.release_evidence_observed || 0);
  const automaticReady = Number(summary.automatic_loop_ready || 0);
  const depositWatchersLive = items.filter((item) => {
    if (item?.source_live === true) return true;
    return ["deposit_ready", "deposit_tested", "full_loop_ready", "full_loop_tested"].includes(item?.phase || "");
  }).length;
  const blockers = items
    .filter((item) => Array.isArray(item?.blockers) && item.blockers.length > 0)
    .map((item) => ({
      routeId: item.routeId || "",
      displayName: item.displayName || item.routeId || "",
      depositStatus:
        item.phase === "deposit_tested" || item.phase === "full_loop_tested"
          ? "deposit tested"
          : item.phase === "deposit_ready" || item.source_live
            ? "watcher live"
            : "waiting for deposit proof",
      releaseStatus: item.automatic_loop_ready
        ? "automatic ready"
        : Number(item?.evidence?.released_withdrawals || 0) > 0
          ? "release proof observed"
          : "waiting for release automation",
      blockers: item.blockers || [],
      required_configuration: item.required_configuration || [],
      recommended_action: item.recommended_action || "",
      signer_diagnostics: item.signer_diagnostics || null,
    }));
  return {
    updated_at: new Date().toISOString(),
    chain_id: chainId,
    title: "The shortest live proof board",
    validator: {
      updated_at: new Date().toISOString(),
      chain_id: chainId,
      bonded_count: bondedCount,
      signed_count: signedCount,
      unjailed_count: bondedCount,
      indexer_total: bondedCount,
      min_validators: minValidators,
      public_peers: publicPeers,
      min_public_peers: minPublicPeers,
      validator_gate_pass: bondedCount >= minValidators,
      peer_gate_pass: publicPeers >= minPublicPeers,
      overall_gate_pass: bondedCount >= minValidators && publicPeers >= minPublicPeers,
      validators: validatorDetails?.validators || [],
      errors: validatorDetails?.errors || [],
    },
    routes: {
      total: routeTotal,
      deposit_tested: depositTested,
      release_observed: releaseObserved,
      deposit_watchers_live: depositWatchersLive,
      automatic_loop_ready: automaticReady,
      blockers,
    },
    cards: [
      {
        key: "bonded_validators",
        label: "Bonded validators",
        value: `${bondedCount}/${minValidators}`,
        detail: `${bondedCount} bonded visible, ${signedCount}/${Math.max(bondedCount, 1)} signed on the latest indexed block`,
      },
      {
        key: "routes_with_deposit_proof",
        label: "Routes with deposit proof",
        value: routeTotal > 0 ? `${depositTested}/${routeTotal}` : "—/—",
        detail:
          routeTotal > 0
            ? `${depositTested}/${routeTotal} routes already show deposit-tested evidence on the public bridge`
            : "Checking public bridge route evidence",
      },
      {
        key: "routes_with_release_proof",
        label: "Routes with any release proof",
        value: routeTotal > 0 ? `${releaseObserved}/${routeTotal}` : "—/—",
        detail:
          routeTotal > 0
            ? `${automaticReady}/${routeTotal} routes are fully automatic today; ${depositWatchersLive}/${routeTotal} already have live deposit watchers. This proof bucket can include manual operator-marked release evidence.`
            : "Checking automatic release and watcher coverage",
      },
    ],
    errors: validatorDetails?.errors || [],
  };
}

function buildExecutionBacklog(bridge, aiRuntime) {
  const items = [];
  for (const action of bridge?.route_readiness?.actions || []) {
    items.push({
      area: "bridge",
      priority: action.priority || "medium",
      blocker_class: action.blocker_class || "configuration_gap",
      required_configuration: action.required_configuration || [],
      routes: action.routes || [],
      action: action.recommended_action || "",
    });
  }
  const aiMissing = aiRuntime?.onchain?.missing_requirements || [];
  if (aiMissing.length > 0) {
    items.push({
      area: "ai_runtime",
      priority: aiMissing.includes("onchain_private_key_required") ? "high" : "medium",
      blocker_class: "service_config_missing",
      required_configuration: aiMissing,
      routes: [],
      action: "Enable AI onchain settlement by loading the missing AI onchain configuration on the gateway service.",
    });
  }
  const order = { high: 0, medium: 1, low: 2 };
  items.sort((a, b) => (order[a.priority] ?? 9) - (order[b.priority] ?? 9));
  return items;
}

function buildConfigurationChecklist(status, labels) {
  const entries = [];
  for (const [key, label] of Object.entries(labels || {})) {
    if (!(key in (status || {}))) continue;
    entries.push({
      key,
      label,
      configured: Boolean(status[key]),
    });
  }
  return entries;
}

function summarizeConfigurationChecklist(items) {
  const checklist = Array.isArray(items) ? items : [];
  return {
    configured: checklist.filter((item) => item.configured).length,
    total: checklist.length,
    items: checklist,
  };
}

function buildHeadlineMetrics(bridge, aiRuntime, lastIndexed, latestSeen) {
  const summary = bridge?.route_readiness?.summary || {};
  const bridgeConfig = summarizeConfigurationChecklist(
    buildConfigurationChecklist(bridge?.onchain?.configuration_status, {
      rpc_configured: "YNX bridge RPC",
      relayer_configured: "YNX relayer key",
      remote_signer_configured: "Remote signer address",
      attester_configured: "Attester key",
      source_relayer_configured: "Source EVM signer",
      btc_testnet_release_signer_configured: "BTC testnet release signer",
      tron_shasta_release_signer_configured: "TRON Shasta release signer",
    }),
  );
  const aiConfig = summarizeConfigurationChecklist(
    buildConfigurationChecklist(aiRuntime?.onchain?.configuration_status, {
      enabled_flag_present: "AI onchain enabled flag",
      rpc_configured: "AI onchain RPC",
      signer_configured: "AI onchain signer",
      settlement_contract_configured: "AI settlement contract",
    }),
  );
  return {
    routes_total: Number(summary.routes || 0),
    routes_full_loop_tested: Number(summary.full_loop_tested || 0),
    routes_automatic_ready: Number(summary.automatic_loop_ready || 0),
    routes_deposit_tested: Number(summary.deposit_tested || 0),
    routes_mapped_only: Number(summary.mapped_route_only || 0),
    bridge_blocked_routes: Number(bridge?.route_readiness?.blockers?.total_routes_with_blockers || 0),
    bridge_configured_checks: bridgeConfig.configured,
    bridge_total_checks: bridgeConfig.total,
    ai_onchain_ready: Boolean(aiRuntime?.onchain?.ready),
    ai_onchain_missing_requirements: aiRuntime?.onchain?.missing_requirements || [],
    ai_configured_checks: aiConfig.configured,
    ai_total_checks: aiConfig.total,
    last_indexed: Number(lastIndexed || 0),
    latest_seen: Number(latestSeen || 0),
  };
}

function buildReadinessScorecard(bridge, aiRuntime) {
  const summary = bridge?.route_readiness?.summary || {};
  const routes = Number(summary.routes || 0);
  const depositTested = Number(summary.deposit_tested || 0);
  const automaticReady = Number(summary.automatic_loop_ready || 0);
  return {
    bridge: {
      deposit_tested: { completed: depositTested, total: routes },
      automatic_ready: { completed: automaticReady, total: routes },
      configuration: summarizeConfigurationChecklist(
        buildConfigurationChecklist(bridge?.onchain?.configuration_status, {
          rpc_configured: "YNX bridge RPC",
          relayer_configured: "YNX relayer key",
          remote_signer_configured: "Remote signer address",
          attester_configured: "Attester key",
          source_relayer_configured: "Source EVM signer",
          btc_testnet_release_signer_configured: "BTC testnet release signer",
          tron_shasta_release_signer_configured: "TRON Shasta release signer",
        }),
      ),
    },
    ai_runtime: {
      onchain_ready: Boolean(aiRuntime?.onchain?.ready),
      missing_requirements: aiRuntime?.onchain?.missing_requirements || [],
      configuration: summarizeConfigurationChecklist(
        buildConfigurationChecklist(aiRuntime?.onchain?.configuration_status, {
          enabled_flag_present: "AI onchain enabled flag",
          rpc_configured: "AI onchain RPC",
          signer_configured: "AI onchain signer",
          settlement_contract_configured: "AI settlement contract",
        }),
      ),
    },
  };
}

function buildNextStepSummary(executionBacklog) {
  const next = Array.isArray(executionBacklog) ? executionBacklog[0] : null;
  if (!next) {
    return {
      priority: "none",
      area: "",
      action: "",
      routes: [],
    };
  }
  return {
    priority: next.priority || "medium",
    area: next.area || "",
    blocker_class: next.blocker_class || "",
    action: next.action || "",
    routes: next.routes || [],
    required_configuration: next.required_configuration || [],
  };
}

function txHashFromBase64(base64) {
  const bytes = Buffer.from(base64, "base64");
  const hash = crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
  return `0x${hash}`;
}

const blocksCache = [];
const txsCache = [];
let latestSeenHeight = 0;
let indexing = false;
let chainId = "";
let lineageState = {
  version: 1,
  next_lot_seq: 1,
  lots: {},
  holdings: {},
  tx_effects: {},
  address_book: {},
  updated_at: "",
};
let systemContractsMeta = {};
let governanceMeta = {
  founder_address: YNX_FOUNDER_ADDRESS,
  treasury_address: YNX_TREASURY_ADDRESS,
  team_beneficiary_address: YNX_TEAM_BENEFICIARY,
  community_recipient_address: YNX_COMMUNITY_RECIPIENT,
  fee_burn_bps: YNX_FEE_BURN_BPS,
  fee_treasury_bps: YNX_FEE_TREASURY_BPS,
  fee_founder_bps: YNX_FEE_FOUNDER_BPS,
  inflation_treasury_bps: YNX_INFLATION_TREASURY_BPS,
  no_base_fee: YNX_NO_BASE_FEE === undefined ? null : YNX_NO_BASE_FEE === "1" || YNX_NO_BASE_FEE === "true",
  base_fee: "",
};

loadPersistedLineage();
loadRecentJsonlIntoCache(BLOCKS_PATH, blocksCache, INDEXER_CACHE_SIZE);
loadRecentJsonlIntoCache(TXS_PATH, txsCache, INDEXER_TX_CACHE_SIZE);

function safeJsonParse(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function loadPersistedLineage() {
  if (!fs.existsSync(LINEAGE_STATE_PATH)) return;
  const parsed = safeJsonParse(fs.readFileSync(LINEAGE_STATE_PATH, "utf8"), null);
  if (!parsed || typeof parsed !== "object") return;
  lineageState = {
    version: parsed.version || 1,
    next_lot_seq: Number(parsed.next_lot_seq || 1),
    lots: parsed.lots || {},
    holdings: parsed.holdings || {},
    tx_effects: parsed.tx_effects || {},
    address_book: parsed.address_book || {},
    updated_at: parsed.updated_at || "",
  };
}

function persistLineage() {
  lineageState.updated_at = new Date().toISOString();
  fs.writeFileSync(LINEAGE_STATE_PATH, JSON.stringify(lineageState, null, 2));
}

function loadRecentJsonlIntoCache(filePath, cache, limit) {
  if (!fs.existsSync(filePath)) return;
  const lines = fs
    .readFileSync(filePath, "utf8")
    .split(/\r?\n/)
    .filter(Boolean)
    .slice(-limit);
  for (const line of lines) {
    const parsed = safeJsonParse(line, null);
    if (parsed) cache.push(parsed);
  }
}

function normalizeAddress(value) {
  return String(value || "").trim();
}

function normalizeDenom(value) {
  return String(value || "").trim();
}

function amountToBigInt(value) {
  try {
    const raw = String(value ?? "0").trim();
    if (!raw) return 0n;
    return BigInt(raw);
  } catch {
    return 0n;
  }
}

function bigIntToString(value) {
  return amountToBigInt(value).toString();
}

function riskScoreFromParts(total, tainted) {
  const totalValue = amountToBigInt(total);
  if (totalValue <= 0n) return 0;
  const taintedValue = amountToBigInt(tainted);
  return Number((taintedValue * 10000n) / totalValue);
}

function ensureAddressBookEntry(address) {
  const normalized = normalizeAddress(address);
  if (!normalized) return;
  if (!lineageState.address_book[normalized]) {
    lineageState.address_book[normalized] = { first_seen_at: new Date().toISOString() };
  }
}

function ensureHoldingBucket(address, denom) {
  const normalizedAddress = normalizeAddress(address);
  const normalizedDenom = normalizeDenom(denom);
  if (!lineageState.holdings[normalizedAddress]) lineageState.holdings[normalizedAddress] = {};
  if (!Array.isArray(lineageState.holdings[normalizedAddress][normalizedDenom])) {
    lineageState.holdings[normalizedAddress][normalizedDenom] = [];
  }
  ensureAddressBookEntry(normalizedAddress);
  return lineageState.holdings[normalizedAddress][normalizedDenom];
}

function getHoldingEntries(address, denom) {
  return ensureHoldingBucket(address, denom);
}

function totalHoldingAmount(entries) {
  return entries.reduce((sum, entry) => sum + amountToBigInt(entry.amount), 0n);
}

function createLot({
  denom,
  amount,
  owner,
  created_by_tx,
  height,
  source_type,
  source_ref,
  origin_ref,
  root_origin_lot_id,
  parent_lot_ids,
  risk_basis_points,
  tainted_amount,
}) {
  const lotId = `lot_${String(lineageState.next_lot_seq++).padStart(8, "0")}`;
  const normalizedOwner = normalizeAddress(owner);
  const normalizedDenom = normalizeDenom(denom);
  const amountString = bigIntToString(amount);
  const taintedString = bigIntToString(tainted_amount ?? amountToBigInt(amount) * BigInt(Number(risk_basis_points || 0)) / 10000n);
  lineageState.lots[lotId] = {
    lot_id: lotId,
    denom: normalizedDenom,
    amount: amountString,
    current_amount: amountString,
    owner: normalizedOwner,
    created_by_tx: created_by_tx || "",
    height: Number(height || 0),
    source_type: source_type || "unknown",
    source_ref: source_ref || "",
    origin_ref: origin_ref || source_ref || "",
    root_origin_lot_id: root_origin_lot_id || lotId,
    parent_lot_ids: Array.isArray(parent_lot_ids) ? parent_lot_ids.filter(Boolean) : [],
    risk_basis_points: Number(risk_basis_points || 0),
    tainted_amount: taintedString,
    created_at: new Date().toISOString(),
  };
  const bucket = ensureHoldingBucket(normalizedOwner, normalizedDenom);
  bucket.push({
    lot_id: lotId,
    amount: amountString,
    tainted_amount: taintedString,
    risk_basis_points: Number(risk_basis_points || 0),
    root_origin_lot_id: root_origin_lot_id || lotId,
  });
  return lineageState.lots[lotId];
}

function bootstrapSourceLiquidity(address, denom, amount, context = {}) {
  const required = amountToBigInt(amount);
  if (required <= 0n) return;
  const risky = INDEXER_TRACE_RISKY_ADDRESSES.has(normalizeAddress(address));
  createLot({
    denom,
    amount: required,
    owner: address,
    created_by_tx: context.created_by_tx || "",
    height: context.height || 0,
    source_type: context.source_type || "opening_balance_inferred",
    source_ref: context.source_ref || `${normalizeAddress(address)}:${normalizeDenom(denom)}`,
    origin_ref: context.origin_ref || `${normalizeAddress(address)}:${normalizeDenom(denom)}`,
    risk_basis_points: Number(context.risk_basis_points ?? (risky ? 10000 : 0)),
    tainted_amount: context.tainted_amount || (risky ? bigIntToString(required) : "0"),
  });
}

function allocateConsumption(entries, amount) {
  const target = amountToBigInt(amount);
  const total = totalHoldingAmount(entries);
  if (target <= 0n || total <= 0n) return [];
  let remaining = target;
  const plan = [];
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const available = amountToBigInt(entry.amount);
    if (available <= 0n) continue;
    let take = 0n;
    if (index === entries.length - 1) {
      take = remaining < available ? remaining : available;
    } else {
      take = (target * available) / total;
      if (take > available) take = available;
      if (take > remaining) take = remaining;
    }
    if (take > 0n) {
      plan.push({ entry, amount: take });
      remaining -= take;
    }
  }
  for (const entry of entries) {
    if (remaining <= 0n) break;
    const already = plan.find((item) => item.entry === entry);
    const used = already ? already.amount : 0n;
    const available = amountToBigInt(entry.amount) - used;
    if (available <= 0n) continue;
    const extra = remaining < available ? remaining : available;
    if (extra <= 0n) continue;
    if (already) {
      already.amount += extra;
    } else {
      plan.push({ entry, amount: extra });
    }
    remaining -= extra;
  }
  return plan.filter((item) => item.amount > 0n);
}

function transferWithLineage({ from, to, denom, amount, txHash, height, message_index }) {
  const normalizedFrom = normalizeAddress(from);
  const normalizedTo = normalizeAddress(to);
  const normalizedDenom = normalizeDenom(denom);
  const target = amountToBigInt(amount);
  if (!normalizedFrom || !normalizedTo || !normalizedDenom || target <= 0n) return null;
  const senderEntries = getHoldingEntries(normalizedFrom, normalizedDenom);
  const senderTotal = totalHoldingAmount(senderEntries);
  if (senderTotal < target) {
    bootstrapSourceLiquidity(normalizedFrom, normalizedDenom, target - senderTotal, {
      created_by_tx: txHash,
      height,
      source_ref: `${normalizedFrom}:${normalizedDenom}`,
    });
  }
  const refreshedEntries = getHoldingEntries(normalizedFrom, normalizedDenom);
  const plan = allocateConsumption(refreshedEntries, target);
  const transferredLots = [];
  for (const item of plan) {
    const sourceEntry = item.entry;
    const sourceLot = lineageState.lots[sourceEntry.lot_id];
    if (!sourceLot) continue;
    const moved = item.amount;
    const sourceAmount = amountToBigInt(sourceEntry.amount);
    const sourceTainted = amountToBigInt(sourceEntry.tainted_amount);
    const movedTainted = sourceAmount > 0n ? (sourceTainted * moved) / sourceAmount : 0n;
    sourceEntry.amount = bigIntToString(sourceAmount - moved);
    sourceEntry.tainted_amount = bigIntToString(sourceTainted - movedTainted);
    sourceEntry.risk_basis_points = riskScoreFromParts(sourceEntry.amount, sourceEntry.tainted_amount);
    sourceLot.current_amount = sourceEntry.amount;
    sourceLot.tainted_amount = sourceEntry.tainted_amount;
    sourceLot.risk_basis_points = sourceEntry.risk_basis_points;

    const childLot = createLot({
      denom: normalizedDenom,
      amount: moved,
      owner: normalizedTo,
      created_by_tx: txHash,
      height,
      source_type: "transfer_fragment",
      source_ref: `${txHash}:${message_index}`,
      origin_ref: sourceLot.origin_ref || sourceLot.source_ref || sourceLot.lot_id,
      root_origin_lot_id: sourceLot.root_origin_lot_id || sourceLot.lot_id,
      parent_lot_ids: [sourceLot.lot_id],
      risk_basis_points: riskScoreFromParts(moved, movedTainted),
      tainted_amount: movedTainted,
    });
    transferredLots.push({
      source_lot_id: sourceLot.lot_id,
      child_lot_id: childLot.lot_id,
      amount: bigIntToString(moved),
      tainted_amount: bigIntToString(movedTainted),
      risk_basis_points: childLot.risk_basis_points,
      root_origin_lot_id: childLot.root_origin_lot_id,
    });
  }
  lineageState.holdings[normalizedFrom][normalizedDenom] = refreshedEntries.filter((entry) => amountToBigInt(entry.amount) > 0n);
  return {
    from: normalizedFrom,
    to: normalizedTo,
    denom: normalizedDenom,
    amount: bigIntToString(target),
    tainted_amount: bigIntToString(transferredLots.reduce((sum, item) => sum + amountToBigInt(item.tainted_amount), 0n)),
    risk_basis_points: riskScoreFromParts(
      target,
      transferredLots.reduce((sum, item) => sum + amountToBigInt(item.tainted_amount), 0n),
    ),
    transferred_lots: transferredLots,
  };
}

function extractSendFlowsFromMessages(messages) {
  const flows = [];
  for (let index = 0; index < (Array.isArray(messages) ? messages.length : 0); index += 1) {
    const message = messages[index] || {};
    if (message["@type"] !== "/cosmos.bank.v1beta1.MsgSend") continue;
    const amounts = Array.isArray(message.amount) ? message.amount : [];
    for (const coin of amounts) {
      const denom = normalizeDenom(coin?.denom);
      if (!INDEXER_TRACE_DENOMS.includes(denom)) continue;
      const amount = amountToBigInt(coin?.amount);
      if (amount <= 0n) continue;
      flows.push({
        message_index: index,
        type: "bank_send",
        from: normalizeAddress(message.from_address),
        to: normalizeAddress(message.to_address),
        denom,
        amount: bigIntToString(amount),
      });
    }
  }
  return flows;
}

function rebuildLineageFromTxCache() {
  lineageState = {
    version: 1,
    next_lot_seq: 1,
    lots: {},
    holdings: {},
    tx_effects: {},
    address_book: {},
    updated_at: "",
  };
  const records = [];
  if (fs.existsSync(TXS_PATH)) {
    const lines = fs.readFileSync(TXS_PATH, "utf8").split(/\r?\n/).filter(Boolean);
    for (const line of lines) {
      const parsed = safeJsonParse(line, null);
      if (parsed) records.push(parsed);
    }
  }
  records.sort((a, b) => (Number(a.height || 0) - Number(b.height || 0)) || (Number(a.index || 0) - Number(b.index || 0)));
  for (const record of records) {
    const flows = Array.isArray(record.send_flows) ? record.send_flows : extractSendFlowsFromMessages(record.messages);
    if (!flows.length) continue;
    const effects = [];
    for (const flow of flows) {
      const effect = transferWithLineage({
        from: flow.from,
        to: flow.to,
        denom: flow.denom,
        amount: flow.amount,
        txHash: record.hash,
        height: record.height,
        message_index: flow.message_index,
      });
      if (effect) effects.push(effect);
    }
    if (effects.length > 0) {
      lineageState.tx_effects[record.hash] = {
        hash: record.hash,
        height: Number(record.height || 0),
        index: Number(record.index || 0),
        flows: effects,
      };
    }
  }
  persistLineage();
}

function summarizeAddressTrace(address, denomFilter = "") {
  const normalizedAddress = normalizeAddress(address);
  const addressHoldings = lineageState.holdings[normalizedAddress] || {};
  const denoms = denomFilter ? [normalizeDenom(denomFilter)] : Object.keys(addressHoldings);
  const balances = [];
  for (const denom of denoms) {
    const entries = (addressHoldings[denom] || []).filter((entry) => amountToBigInt(entry.amount) > 0n);
    if (!entries.length) continue;
    const total = entries.reduce((sum, entry) => sum + amountToBigInt(entry.amount), 0n);
    const tainted = entries.reduce((sum, entry) => sum + amountToBigInt(entry.tainted_amount), 0n);
    balances.push({
      denom,
      total_amount: bigIntToString(total),
      tainted_amount: bigIntToString(tainted),
      risk_basis_points: riskScoreFromParts(total, tainted),
      lots: entries.map((entry) => {
        const lot = lineageState.lots[entry.lot_id] || {};
        return {
          lot_id: entry.lot_id,
          amount: entry.amount,
          tainted_amount: entry.tainted_amount,
          risk_basis_points: entry.risk_basis_points,
          root_origin_lot_id: entry.root_origin_lot_id,
          origin_ref: lot.origin_ref || "",
          source_type: lot.source_type || "",
          parent_lot_ids: lot.parent_lot_ids || [],
        };
      }),
    });
  }
  return {
    ok: balances.length > 0,
    address: normalizedAddress,
    balances,
    updated_at: lineageState.updated_at || null,
  };
}

function summarizeLotTrace(lotId) {
  const lot = lineageState.lots[lotId];
  if (!lot) return null;
  const holders = [];
  for (const [address, byDenom] of Object.entries(lineageState.holdings || {})) {
    const entries = byDenom?.[lot.denom] || [];
    const match = entries.find((entry) => entry.lot_id === lotId);
    if (match && amountToBigInt(match.amount) > 0n) {
      holders.push({
        address,
        amount: match.amount,
        tainted_amount: match.tainted_amount,
        risk_basis_points: match.risk_basis_points,
      });
    }
  }
  const children = Object.values(lineageState.lots)
    .filter((item) => Array.isArray(item.parent_lot_ids) && item.parent_lot_ids.includes(lotId))
    .map((item) => ({
      lot_id: item.lot_id,
      owner: item.owner,
      amount: item.amount,
      current_amount: item.current_amount,
      created_by_tx: item.created_by_tx,
      risk_basis_points: item.risk_basis_points,
    }));
  return {
    ok: true,
    lot: {
      ...lot,
      holders,
      children,
    },
    updated_at: lineageState.updated_at || null,
  };
}

function findTxEffectByHash(hash) {
  const target = String(hash || "").trim().toUpperCase();
  if (!target) return null;
  for (const [storedHash, effect] of Object.entries(lineageState.tx_effects || {})) {
    if (String(storedHash || "").trim().toUpperCase() === target) return effect;
  }
  return null;
}

async function initChainId() {
  try {
    const status = await rpcRequest("/status");
    chainId = status?.result?.node_info?.network || "";
  } catch {
    chainId = "";
  }
}

async function initGovernanceMeta() {
  try {
    const [paramsRes, systemContractsRes] = await Promise.all([
      httpJsonRequest(`${YNX_QUERY_REST.replace(/\/$/, "")}/ynx/ynx/v1/params`),
      httpJsonRequest(`${YNX_QUERY_REST.replace(/\/$/, "")}/ynx/ynx/v1/system_contracts`),
    ]);

    const params = paramsRes?.params || {};
    const system = systemContractsRes?.system || {};
    const contracts = systemContractsRes?.system_contracts || {};
    governanceMeta = {
      founder_address: params.founder_address || governanceMeta.founder_address,
      treasury_address: params.treasury_address || governanceMeta.treasury_address,
      team_beneficiary_address: system.team_beneficiary_address || governanceMeta.team_beneficiary_address,
      community_recipient_address: system.community_recipient_address || governanceMeta.community_recipient_address,
      fee_burn_bps: Number(params.fee_burn_bps ?? governanceMeta.fee_burn_bps),
      fee_treasury_bps: Number(params.fee_treasury_bps ?? governanceMeta.fee_treasury_bps),
      fee_founder_bps: Number(params.fee_founder_bps ?? governanceMeta.fee_founder_bps),
      inflation_treasury_bps: Number(params.inflation_treasury_bps ?? governanceMeta.inflation_treasury_bps),
      no_base_fee: governanceMeta.no_base_fee,
      base_fee: governanceMeta.base_fee,
    };
    systemContractsMeta = contracts;
    return;
  } catch {
    // fall back to genesis-derived metadata below
  }

  try {
    const genesis = await rpcRequest("/genesis");
    const appState = genesis?.result?.genesis?.app_state || {};
    const ynx = appState?.ynx || {};
    const params = ynx?.params || {};
    const system = ynx?.system || {};
    const feemarket = appState?.feemarket?.params || {};

    governanceMeta = {
      founder_address: params.founder_address || governanceMeta.founder_address,
      treasury_address: params.treasury_address || governanceMeta.treasury_address,
      team_beneficiary_address: system.team_beneficiary_address || governanceMeta.team_beneficiary_address,
      community_recipient_address: system.community_recipient_address || governanceMeta.community_recipient_address,
      fee_burn_bps: Number(params.fee_burn_bps ?? governanceMeta.fee_burn_bps),
      fee_treasury_bps: Number(params.fee_treasury_bps ?? governanceMeta.fee_treasury_bps),
      fee_founder_bps: Number(params.fee_founder_bps ?? governanceMeta.fee_founder_bps),
      inflation_treasury_bps: Number(params.inflation_treasury_bps ?? governanceMeta.inflation_treasury_bps),
      no_base_fee: feemarket.no_base_fee ?? governanceMeta.no_base_fee,
      base_fee: feemarket.base_fee || governanceMeta.base_fee,
    };
    systemContractsMeta = ynx?.system_contracts || systemContractsMeta;
  } catch {
    return;
  }
}

async function indexHeight(height) {
  const blockData = await rpcRequest(`/block?height=${height}`);
  const resultData = await rpcRequest(`/block_results?height=${height}`);
  const decodedTxs = await fetchDecodedTxsByHeight(height);

  const block = blockData?.result?.block;
  if (!block) {
    throw new Error(`Missing block for height ${height}`);
  }

  const header = block.header || {};
  const blockId = blockData?.result?.block_id || {};
  const txs = block.data?.txs || [];
  const txResults = resultData?.result?.txs_results || [];

  const record = {
    height: parseInt(header.height || height, 10),
    hash: blockId.hash || "",
    time: header.time || "",
    proposer: header.proposer_address || "",
    num_txs: txs.length,
    app_hash: header.app_hash || "",
  };

  appendJsonLine(BLOCKS_PATH, record);
  blocksCache.push(record);
  if (blocksCache.length > INDEXER_CACHE_SIZE) {
    blocksCache.shift();
  }

  const txRecords = [];
  for (let i = 0; i < txs.length; i += 1) {
    const base64 = txs[i];
    const hash = txHashFromBase64(base64);
    const result = txResults[i] || {};
    const decoded = decodedTxs[i] || {};
    const messages = Array.isArray(decoded?.body?.messages) ? decoded.body.messages : [];
    const sendFlows = extractSendFlowsFromMessages(messages);
    const txRecord = {
      hash,
      height: record.height,
      index: i,
      code: result.code || 0,
      gas_wanted: result.gas_wanted || 0,
      gas_used: result.gas_used || 0,
      messages,
      send_flows: sendFlows,
    };
    txRecords.push(txRecord);
    appendJsonLine(TXS_PATH, txRecord);
  }

  for (const txRecord of txRecords) {
    txsCache.push(txRecord);
    if (txsCache.length > INDEXER_TX_CACHE_SIZE) {
      txsCache.shift();
    }
    if (Array.isArray(txRecord.send_flows) && txRecord.send_flows.length > 0) {
      const effects = [];
      for (const flow of txRecord.send_flows) {
        const effect = transferWithLineage({
          from: flow.from,
          to: flow.to,
          denom: flow.denom,
          amount: flow.amount,
          txHash: txRecord.hash,
          height: txRecord.height,
          message_index: flow.message_index,
        });
        if (effect) effects.push(effect);
      }
      if (effects.length > 0) {
        lineageState.tx_effects[txRecord.hash] = {
          hash: txRecord.hash,
          height: txRecord.height,
          index: txRecord.index,
          flows: effects,
        };
      }
    }
  }

  state.last_height = record.height;
  state.blocks_indexed += 1;
  state.txs_indexed += txRecords.length;
  saveState();
  persistLineage();
}

async function poll() {
  if (indexing) return;
  indexing = true;

  try {
    const status = await rpcRequest("/status");
    if (!chainId) {
      chainId = status?.result?.node_info?.network || chainId;
    }
    const latest = parseInt(status?.result?.sync_info?.latest_block_height || "0", 10);
    if (latest > latestSeenHeight) {
      latestSeenHeight = latest;
    }

    if (!governanceMeta.founder_address && latest > 0) {
      await initGovernanceMeta();
    }

    if (!state.last_height || state.last_height === 0) {
      if (INDEXER_START_HEIGHT > 0) {
        state.last_height = INDEXER_START_HEIGHT - 1;
      } else if (INDEXER_BACKFILL > 0) {
        state.last_height = Math.max(0, latest - INDEXER_BACKFILL);
      } else {
        state.last_height = latest;
      }
      saveState();
    }

    for (let h = state.last_height + 1; h <= latest; h += 1) {
      await indexHeight(h);
    }
  } catch (err) {
    log(`Indexing error: ${err.message}`);
  } finally {
    indexing = false;
  }
}

function json(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    "content-type": "application/json",
    "content-length": Buffer.byteLength(body),
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,OPTIONS",
  });
  res.end(body);
}

async function findBlockByHeight(height) {
  const cached = blocksCache.find((b) => b.height === height);
  if (cached) return cached;
  if (!fs.existsSync(BLOCKS_PATH)) return null;

  return new Promise((resolve) => {
    const stream = fs.createReadStream(BLOCKS_PATH, "utf8");
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    let found = null;
    rl.on("line", (line) => {
      if (!line) return;
      try {
        const entry = JSON.parse(line);
        if (entry.height === height) {
          found = entry;
          rl.close();
        }
      } catch {
        return;
      }
    });
    rl.on("close", () => {
      stream.close();
      resolve(found);
    });
  });
}

async function findTxByHash(hash) {
  const upper = hash.toUpperCase();
  const cached = txsCache.find((t) => t.hash.toUpperCase() === upper);
  if (cached) return cached;
  if (!fs.existsSync(TXS_PATH)) return null;

  return new Promise((resolve) => {
    const stream = fs.createReadStream(TXS_PATH, "utf8");
    const rl = readline.createInterface({ input: stream, crlfDelay: Infinity });
    let found = null;
    rl.on("line", (line) => {
      if (!line) return;
      try {
        const entry = JSON.parse(line);
        if ((entry.hash || "").toUpperCase() === upper) {
          found = entry;
          rl.close();
        }
      } catch {
        return;
      }
    });
    rl.on("close", () => {
      stream.close();
      resolve(found);
    });
  });
}

function listBlocks(limit, beforeHeight) {
  let items = blocksCache.slice();
  if (beforeHeight) {
    items = items.filter((b) => b.height < beforeHeight);
  }
  const slice = items.slice(-limit);
  return slice.reverse();
}

function listTxs(limit, height) {
  let items = txsCache.slice();
  if (height) {
    items = items.filter((t) => t.height === height);
  }
  const slice = items.slice(-limit);
  return slice.reverse();
}

function normalizeText(value) {
  return String(value || "").trim();
}

async function findValidatorByAddress(address) {
  const target = normalizeText(address).toUpperCase();
  if (!target) return null;
  const snapshot = await fetchValidatorsSnapshot();
  const validator = (snapshot.validators || []).find((item) => String(item.address || "").toUpperCase() === target);
  if (!validator) return null;
  return {
    latest_height: snapshot.latest_height,
    total: snapshot.total,
    signed_count: snapshot.signed_count,
    validator,
  };
}

async function searchIndex(query) {
  const raw = normalizeText(query);
  if (!raw) return { ok: false, error: "empty_query" };

  if (/^[0-9]+$/.test(raw)) {
    const block = await findBlockByHeight(parseInt(raw, 10));
    if (block) return { ok: true, kind: "block", block };
  }

  const validator = await findValidatorByAddress(raw);
  if (validator) return { ok: true, kind: "validator", ...validator };

  const addressTrace = summarizeAddressTrace(raw);
  if (addressTrace.ok) return { ok: true, kind: "trace_address", trace: addressTrace };

  const lotTrace = summarizeLotTrace(raw);
  if (lotTrace) return { ok: true, kind: "trace_lot", trace: lotTrace };

  const txEffect = findTxEffectByHash(raw);
  if (txEffect) {
    return { ok: true, kind: "trace_tx", trace: { ok: true, tx_effect: txEffect } };
  }

  const tx = await findTxByHash(raw);
  if (tx) return { ok: true, kind: "tx", tx };

  return { ok: false, error: "not_found", query: raw };
}

function metrics() {
  const lines = [];
  lines.push("# HELP ynx_indexer_last_height Last indexed block height");
  lines.push("# TYPE ynx_indexer_last_height gauge");
  lines.push(`ynx_indexer_last_height ${state.last_height || 0}`);
  lines.push("# HELP ynx_indexer_latest_seen Latest height observed from RPC");
  lines.push("# TYPE ynx_indexer_latest_seen gauge");
  lines.push(`ynx_indexer_latest_seen ${latestSeenHeight || 0}`);
  lines.push("# HELP ynx_indexer_blocks_indexed Total blocks indexed");
  lines.push("# TYPE ynx_indexer_blocks_indexed counter");
  lines.push(`ynx_indexer_blocks_indexed ${state.blocks_indexed || 0}`);
  lines.push("# HELP ynx_indexer_txs_indexed Total transactions indexed");
  lines.push("# TYPE ynx_indexer_txs_indexed counter");
  lines.push(`ynx_indexer_txs_indexed ${state.txs_indexed || 0}`);
  return lines.join("\n") + "\n";
}

async function fetchValidatorsSnapshot() {
  const status = await rpcRequest("/status");
  const latestHeight = parseInt(status?.result?.sync_info?.latest_block_height || "0", 10);
  if (!latestHeight) {
    return {
      latest_height: 0,
      total: 0,
      signed_count: 0,
      validators: [],
    };
  }

  const validators = [];
  let page = 1;
  let total = 0;

  while (true) {
    const pageData = await rpcRequest(`/validators?height=${latestHeight}&page=${page}&per_page=100`);
    const result = pageData?.result || {};
    const items = result.validators || [];
    total = parseInt(result.total || "0", 10) || items.length;
    validators.push(...items);
    if (!items.length || validators.length >= total) break;
    page += 1;
  }

  const blockData = await rpcRequest(`/block?height=${latestHeight}`);
  const signatures = blockData?.result?.block?.last_commit?.signatures || [];
  const signedSet = new Set(
    signatures
      .filter((s) => s && Number(s.block_id_flag) === 2 && s.validator_address)
      .map((s) => s.validator_address)
  );

  const rows = validators.map((validator) => ({
    address: validator.address || "",
    voting_power: parseInt(validator.voting_power || "0", 10),
    proposer_priority: parseInt(validator.proposer_priority || "0", 10),
    signed_last_block: signedSet.has(validator.address || ""),
  }));

  rows.sort((a, b) => b.voting_power - a.voting_power);

  return {
    latest_height: latestHeight,
    total: rows.length,
    signed_count: rows.filter((row) => row.signed_last_block).length,
    validators: rows,
  };
}

async function fetchPublicPeerCount() {
  try {
    const netInfo = await rpcRequest("/net_info");
    const raw = netInfo?.result?.n_peers ?? netInfo?.n_peers ?? 0;
    const count = Number(raw);
    return Number.isFinite(count) ? count : 0;
  } catch {
    return 0;
  }
}

async function fetchBondedValidatorDetails() {
  try {
    const payload = await httpJsonRequest(
      `${YNX_QUERY_REST.replace(/\/$/, "")}/cosmos/staking/v1beta1/validators?status=BOND_STATUS_BONDED&pagination.limit=100`,
      4000,
    );
    const validators = Array.isArray(payload?.validators) ? payload.validators : [];
    return {
      validators: validators.map((item) => ({
        moniker: String(item?.description?.moniker || "unknown"),
        operator: String(item?.operator_address || ""),
        status: String(item?.status || ""),
        jailed: Boolean(item?.jailed),
      })),
      errors: [],
    };
  } catch (err) {
    return {
      validators: [],
      errors: [`bonded_validators_failed:${err instanceof Error ? err.message : String(err)}`],
    };
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,OPTIONS",
      "access-control-allow-headers": "content-type",
    });
    return res.end();
  }

  const isReadMethod = req.method === "GET" || req.method === "HEAD";

  if (!isReadMethod) {
    return json(res, 405, { ok: false, error: "method_not_allowed" });
  }

  const url = new URL(req.url, "http://localhost");

  if (url.pathname === "/health") {
    return json(res, 200, {
      ok: true,
      chain_id: chainId,
      rpc: INDEXER_RPC,
      last_indexed: state.last_height || 0,
      latest_seen: latestSeenHeight || 0,
    });
  }

  if (url.pathname === "/stats") {
    return json(res, 200, {
      ok: true,
      chain_id: chainId,
      rpc: INDEXER_RPC,
      last_indexed: state.last_height || 0,
      latest_seen: latestSeenHeight || 0,
      blocks_indexed: state.blocks_indexed || 0,
      txs_indexed: state.txs_indexed || 0,
      cache_blocks: blocksCache.length,
      cache_txs: txsCache.length,
    });
  }

  if (url.pathname === "/metrics") {
    const body = metrics();
    res.writeHead(200, {
      "content-type": "text/plain",
      "content-length": Buffer.byteLength(body),
      "access-control-allow-origin": "*",
    });
    return res.end(body);
  }

  if (url.pathname === "/ynx/overview") {
    const bridge = await loadBridgeOverview();
    const ai_runtime = await loadAiOverview();
    const validator_snapshot = await fetchValidatorsSnapshot();
    const validator_details = await fetchBondedValidatorDetails();
    const public_peer_count = await fetchPublicPeerCount();
    const execution_backlog = buildExecutionBacklog(bridge, ai_runtime);
    const headline_metrics = buildHeadlineMetrics(bridge, ai_runtime, state.last_height || 0, latestSeenHeight || 0);
    const next_step = buildNextStepSummary(execution_backlog);
    const readiness_scorecard = buildReadinessScorecard(bridge, ai_runtime);
    const public_operations = buildPublicOperations(validator_snapshot, validator_details, bridge, public_peer_count);
    return json(res, 200, {
      ok: true,
      chain_id: chainId,
      rpc: INDEXER_RPC,
      track: YNX_OVERVIEW_TRACK,
      latest_seen: latestSeenHeight || 0,
      last_indexed: state.last_height || 0,
      governance: governanceMeta,
      system_contracts: systemContractsMeta,
      endpoints: {
        rpc: YNX_PUBLIC_RPC,
        bridge_health: YNX_PUBLIC_BRIDGE_HEALTH,
        evm_rpc: YNX_PUBLIC_EVM_RPC,
        evm_ws: YNX_PUBLIC_EVM_WS,
        rest: YNX_PUBLIC_REST,
        grpc: YNX_PUBLIC_GRPC,
        faucet: YNX_PUBLIC_FAUCET,
        indexer: YNX_PUBLIC_INDEXER,
        explorer: YNX_PUBLIC_EXPLORER,
        ai_gateway: YNX_PUBLIC_AI_GATEWAY,
        web4_hub: YNX_PUBLIC_WEB4_HUB,
      },
      value_proposition: {
        evm_compatible: true,
        onchain_governance: true,
        open_validator_program: true,
        public_testnet_live: true,
        ai_native_settlement: true,
        web4_orientation: true,
        account_abstraction_track: true,
        parallel_execution_track: true,
        owner_policy_session_sovereignty: true,
        machine_payment_x402_ready: true,
        controlled_self_replication: true,
      },
      positioning: {
        statement: YNX_POSITIONING_STATEMENT,
        target_users: [
          "ai dapp teams",
          "agent developers",
          "web4 builders",
          "validator operators",
          "onchain organizations and protocols",
        ],
        why_choose_ynx: [
          "EVM compatibility without sacrificing low-latency goals",
          "AI job settlement and challenge workflow with vault budget controls",
          "machine-readable governance, economics, and positioning metadata",
          "operator-first onboarding with fast profile switching for scale",
          "Web4 sovereignty model: owner > policy > session key",
        ],
        design_principles: [
          "performance with transparent decentralization path",
          "developer productivity before complexity",
          "ai verification and settlement as protocol-level primitive",
        ],
      },
      ai_settlement: {
        enabled: true,
        api_prefix: "/ai",
        states: ["created", "committed", "challenged", "finalized", "slashed"],
        machine_payment: {
          x402_shape: true,
          vault_budget_control: true,
        },
      },
      web4: {
        enabled: true,
        api_prefix: "/web4",
        primitives: [
          "wallet-bootstrap",
          "policy",
          "session",
          "identity",
          "agent",
          "intent",
          "claim",
          "challenge",
          "finalize",
          "replicate",
          "audit",
        ],
      },
      bridge,
      ai_runtime,
      public_operations,
      validator_snapshot,
      execution_backlog,
      headline_metrics,
      next_step,
      readiness_scorecard,
    });
  }

  if (url.pathname === "/ynx/public-operations") {
    const bridge = await loadBridgeOverview();
    const validator_snapshot = await fetchValidatorsSnapshot();
    const validator_details = await fetchBondedValidatorDetails();
    const public_peer_count = await fetchPublicPeerCount();
    return json(res, 200, {
      ok: true,
      ...buildPublicOperations(validator_snapshot, validator_details, bridge, public_peer_count),
    });
  }

  if (url.pathname === "/ynx/network-descriptor") {
    return json(res, 200, {
      ok: true,
      generated_at: new Date().toISOString(),
      track: YNX_OVERVIEW_TRACK,
      chain_id: chainId,
      denom: YNX_DENOM,
      minimum_gas_prices: YNX_MIN_GAS_PRICES,
      binary: {
        name: "ynxd",
        version: YNX_BINARY_VERSION,
      },
      release_url: YNX_RELEASE_URL,
      descriptor_url: YNX_DESCRIPTOR_URL,
      endpoints: {
        rpc: YNX_PUBLIC_RPC,
        evm_rpc: YNX_PUBLIC_EVM_RPC,
        evm_ws: YNX_PUBLIC_EVM_WS,
        rest: YNX_PUBLIC_REST,
        grpc: YNX_PUBLIC_GRPC,
        faucet: YNX_PUBLIC_FAUCET,
        indexer: YNX_PUBLIC_INDEXER,
        explorer: YNX_PUBLIC_EXPLORER,
        ai_gateway: YNX_PUBLIC_AI_GATEWAY,
        web4_hub: YNX_PUBLIC_WEB4_HUB,
      },
      network: {
        seeds: YNX_SEEDS,
        persistent_peers: YNX_PERSISTENT_PEERS,
      },
      roles: {
        validator: { public_rpc: false, public_rest: false, public_evm: false },
        "full-node": { public_rpc: false, public_rest: false, public_evm: false },
        "public-rpc": { public_rpc: true, public_rest: true, public_evm: true },
      },
    });
  }

  if (url.pathname === "/validators") {
    try {
      const snapshot = await fetchValidatorsSnapshot();
      return json(res, 200, { ok: true, ...snapshot });
    } catch (err) {
      return json(res, 500, { ok: false, error: "validators_fetch_failed", detail: err.message });
    }
  }

  if (url.pathname.startsWith("/validators/")) {
    const address = decodeURIComponent(url.pathname.split("/")[2] || "");
    if (!address) {
      return json(res, 400, { ok: false, error: "invalid_validator_address" });
    }
    try {
      const result = await findValidatorByAddress(address);
      if (!result) {
        return json(res, 404, { ok: false, error: "not_found" });
      }
      return json(res, 200, { ok: true, ...result });
    } catch (err) {
      return json(res, 500, { ok: false, error: "validator_fetch_failed", detail: err.message });
    }
  }

  if (url.pathname === "/blocks") {
    const limit = envNumber("INDEXER_API_LIMIT", 20);
    const requestedParam = url.searchParams.get("limit");
    const parsedLimit = requestedParam ? parseInt(requestedParam, 10) : limit;
    const requested = Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : limit;
    const before = url.searchParams.get("before");
    const beforeHeight = before ? parseInt(before, 10) : 0;
    const items = listBlocks(Math.min(requested, 200), beforeHeight || 0);
    return json(res, 200, { ok: true, items });
  }

  if (url.pathname.startsWith("/blocks/")) {
    const heightStr = url.pathname.split("/")[2];
    const height = parseInt(heightStr, 10);
    if (!height || Number.isNaN(height)) {
      return json(res, 400, { ok: false, error: "invalid_height" });
    }
    const block = await findBlockByHeight(height);
    if (!block) {
      return json(res, 404, { ok: false, error: "not_found" });
    }
    return json(res, 200, { ok: true, block });
  }

  if (url.pathname === "/txs") {
    const limit = envNumber("INDEXER_API_LIMIT", 20);
    const requestedParam = url.searchParams.get("limit");
    const parsedLimit = requestedParam ? parseInt(requestedParam, 10) : limit;
    const requested = Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : limit;
    const heightParam = url.searchParams.get("height");
    const height = heightParam ? parseInt(heightParam, 10) : 0;
    const items = listTxs(Math.min(requested, 200), height || 0);
    return json(res, 200, { ok: true, items });
  }

  if (url.pathname.startsWith("/txs/")) {
    const hash = url.pathname.split("/")[2];
    if (!hash) {
      return json(res, 400, { ok: false, error: "invalid_hash" });
    }
    const tx = await findTxByHash(hash);
    if (!tx) {
      return json(res, 404, { ok: false, error: "not_found" });
    }
    return json(res, 200, { ok: true, tx });
  }

  if (url.pathname.startsWith("/trace/addresses/")) {
    const address = decodeURIComponent(url.pathname.split("/")[3] || "");
    if (!address) {
      return json(res, 400, { ok: false, error: "invalid_address" });
    }
    const summary = summarizeAddressTrace(address, url.searchParams.get("denom") || "");
    return json(res, summary.ok ? 200 : 404, summary.ok ? summary : { ...summary, error: "not_found" });
  }

  if (url.pathname.startsWith("/trace/lots/")) {
    const lotId = decodeURIComponent(url.pathname.split("/")[3] || "");
    if (!lotId) {
      return json(res, 400, { ok: false, error: "invalid_lot_id" });
    }
    const summary = summarizeLotTrace(lotId);
    return json(res, summary ? 200 : 404, summary || { ok: false, error: "not_found" });
  }

  if (url.pathname.startsWith("/trace/txs/")) {
    const hash = decodeURIComponent(url.pathname.split("/")[3] || "");
    if (!hash) {
      return json(res, 400, { ok: false, error: "invalid_hash" });
    }
    const effect = findTxEffectByHash(hash);
    return json(res, effect ? 200 : 404, effect ? { ok: true, tx_effect: effect, updated_at: lineageState.updated_at || null } : { ok: false, error: "not_found" });
  }

  if (url.pathname === "/search") {
    const query = url.searchParams.get("q") || "";
    try {
      const result = await searchIndex(query);
      return json(res, result.ok ? 200 : result.error === "empty_query" ? 400 : 404, result);
    } catch (err) {
      return json(res, 500, { ok: false, error: "search_failed", detail: err.message });
    }
  }

  return json(res, 404, { ok: false, error: "not_found" });
});

async function start() {
  rebuildLineageFromTxCache();
  await initChainId();
  await initGovernanceMeta();
  server.listen(INDEXER_PORT, () => {
    log(`YNX indexer listening on :${INDEXER_PORT}`);
    log(`RPC: ${INDEXER_RPC}`);
  });
  setInterval(poll, INDEXER_POLL_MS);
  poll();
}

start();
