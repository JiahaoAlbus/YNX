let indexerBase = "";

const networkMeta = document.getElementById("networkMeta");
const refreshBtn = document.getElementById("refreshBtn");
const searchBtn = document.getElementById("searchBtn");
const searchInput = document.getElementById("searchInput");
const searchResult = document.getElementById("searchResult");
const blocksTable = document.getElementById("blocksTable");
const txsTable = document.getElementById("txsTable");
const statusPanel = document.getElementById("statusPanel");
const validatorsSummary = document.getElementById("validatorsSummary");
const validatorsTable = document.getElementById("validatorsTable");
const searchHint = document.getElementById("searchHint");

async function fetchJson(path) {
  const res = await fetch(`${indexerBase}${path}`);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(text || `Request failed: ${res.status}`);
  }
  return res.json();
}

function formatTime(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function renderLines(container, lines) {
  container.innerHTML = lines.map((line) => `<div>${escapeHtml(line)}</div>`).join("");
}

function renderTraceGraph(graph) {
  if (!graph || !graph.stats) return "";
  const stats = graph.stats || {};
  const edges = (graph.edges || [])
    .slice(0, 12)
    .map((edge) => {
      const direction = edge.traversal_direction === "upstream" ? "upstream" : edge.traversal_direction === "downstream" ? "downstream" : "linked";
      return `<div class="trace-edge">
        <div><strong>${escapeHtml(edge.from || "unknown")} → ${escapeHtml(edge.to || "unknown")}</strong></div>
        <div class="muted">${escapeHtml(edge.tx_hash)} · ${escapeHtml(edge.amount)} ${escapeHtml(edge.denom)} · tainted ${escapeHtml(edge.tainted_amount)} · ${direction} · depth ${escapeHtml(edge.depth)}</div>
        <div class="muted">lot ${escapeHtml(edge.source_lot_id)} → ${escapeHtml(edge.child_lot_id)}</div>
      </div>`;
    })
    .join("");
  const roots = (graph.nodes?.lots || [])
    .map((lot) => lot.root_origin_lot_id)
    .filter(Boolean)
    .filter((value, index, arr) => arr.indexOf(value) === index)
    .slice(0, 6)
    .join(", ");
  const paths = (graph.paths || [])
    .slice(0, 6)
    .map((path) => {
      const addresses = (path.addresses || []).slice(0, 6).join(" → ");
      const txs = (path.tx_hashes || []).slice(0, 4).join(", ");
      return `<div class="trace-path">
        <div><strong>${escapeHtml(path.direction)} path</strong> · depth ${escapeHtml(path.depth)}</div>
        <div class="muted">${escapeHtml(addresses || "no address chain")}</div>
        <div class="muted">txs: ${escapeHtml(txs || "none")}</div>
      </div>`;
    })
    .join("");
  return `<div class="trace-graph">
    <div class="trace-graph-header"><strong>Flow graph</strong></div>
    <div class="trace-graph-stats">
      <span class="pill">addresses ${escapeHtml(stats.address_count)}</span>
      <span class="pill">lots ${escapeHtml(stats.lot_count)}</span>
      <span class="pill">txs ${escapeHtml(stats.tx_count)}</span>
      <span class="pill">edges ${escapeHtml(stats.edge_count)}</span>
      <span class="pill">depth ${escapeHtml(stats.max_depth_reached)}</span>
    </div>
    ${roots ? `<div class="muted">Root origins: ${escapeHtml(roots)}</div>` : ""}
    ${paths ? `<div class="trace-paths">${paths}</div>` : ""}
    <div class="trace-graph-edges">${edges || '<div class="muted">No linked edges found.</div>'}</div>
  </div>`;
}

function renderTable(container, rows, columns) {
  if (!rows.length) {
    container.innerHTML = "<p class=\"muted\">No data</p>";
    return;
  }
  const header = `<tr>${columns.map((c) => `<th>${escapeHtml(c.label)}</th>`).join("")}</tr>`;
  const body = rows
    .map((row) => {
      const tds = columns.map((c) => `<td>${escapeHtml(row[c.key])}</td>`).join("");
      return `<tr>${tds}</tr>`;
    })
    .join("");
  container.innerHTML = `<table><thead>${header}</thead><tbody>${body}</tbody></table>`;
}

async function loadStatus() {
  const health = await fetchJson("/health");
  const stats = await fetchJson("/stats");
  const status = [
    `Chain: ${health.chain_id || "unknown"}`,
    `RPC: ${health.rpc || ""}`,
    `Last indexed: ${health.last_indexed}`,
    `Latest seen: ${health.latest_seen}`,
    `Blocks indexed: ${stats.blocks_indexed}`,
    `Txs indexed: ${stats.txs_indexed}`,
  ];
  renderLines(statusPanel, status);
  networkMeta.textContent = `Chain ${health.chain_id || "unknown"} • RPC ${health.rpc || ""}`;
}

async function loadOverview() {
  const overview = await fetchJson("/ynx/overview");
  const gov = overview.governance || {};
  const positioning = overview.positioning || {};
  const valueProp = overview.value_proposition || {};
  const aiSettlement = overview.ai_settlement || {};
  const web4 = overview.web4 || {};
  const feeSplit = `${gov.fee_burn_bps || 0}/${gov.fee_treasury_bps || 0}/${gov.fee_founder_bps || 0}`;
  const extra = [
    `Track: ${overview.track || "n/a"}`,
    `Positioning: ${positioning.statement || "n/a"}`,
    `Founder: ${gov.founder_address || "n/a"}`,
    `Treasury: ${gov.treasury_address || "n/a"}`,
    `Team: ${gov.team_beneficiary_address || "n/a"}`,
    `Community: ${gov.community_recipient_address || "n/a"}`,
    `Fee split bps (burn/treasury/founder): ${feeSplit}`,
    `No base fee: ${String(gov.no_base_fee)}`,
    `AI settlement: ${String(aiSettlement.enabled)}`,
    `Web4 hub: ${String(web4.enabled)}`,
    `AA track: ${String(valueProp.account_abstraction_track)}`,
    `Parallel execution track: ${String(valueProp.parallel_execution_track)}`,
  ];
  statusPanel.innerHTML += extra.map((line) => `<div>${escapeHtml(line)}</div>`).join("");
}

async function loadBlocks() {
  const data = await fetchJson("/blocks?limit=15");
  const rows = data.items.map((b) => ({
    height: b.height,
    hash: b.hash,
    time: formatTime(b.time),
    proposer: b.proposer,
    txs: b.num_txs,
  }));
  renderTable(blocksTable, rows, [
    { key: "height", label: "Height" },
    { key: "hash", label: "Hash" },
    { key: "time", label: "Time" },
    { key: "proposer", label: "Proposer" },
    { key: "txs", label: "Txs" },
  ]);
}

async function loadTxs() {
  const data = await fetchJson("/txs?limit=15");
  const rows = data.items.map((t) => ({
    hash: t.hash,
    height: t.height,
    index: t.index,
    code: t.code,
    gas: `${t.gas_used}/${t.gas_wanted}`,
  }));
  renderTable(txsTable, rows, [
    { key: "hash", label: "Hash" },
    { key: "height", label: "Height" },
    { key: "index", label: "Index" },
    { key: "code", label: "Code" },
    { key: "gas", label: "Gas" },
  ]);
}

async function loadValidators() {
  const data = await fetchJson("/validators");
  const rows = (data.validators || []).map((item) => ({
    address: item.address,
    voting_power: item.voting_power,
    proposer_priority: item.proposer_priority,
    signed_last_block: item.signed_last_block ? "yes" : "no",
  }));
  renderLines(validatorsSummary, [
    `Height: ${data.latest_height || 0}`,
    `Validators: ${data.total || 0}`,
    `Signed(last block): ${data.signed_count || 0}`,
  ]);
  renderTable(validatorsTable, rows, [
    { key: "address", label: "Consensus Address" },
    { key: "voting_power", label: "Voting Power" },
    { key: "proposer_priority", label: "Proposer Priority" },
    { key: "signed_last_block", label: "Signed Last Block" },
  ]);
}

async function refreshAll() {
  try {
    await loadStatus();
    await loadOverview();
    await loadBlocks();
    await loadTxs();
    await loadValidators();
    searchResult.textContent = "";
  } catch (err) {
    searchResult.textContent = `Error: ${err.message}`;
  }
}

async function runSearch() {
  const query = searchInput.value.trim();
  if (!query) return;
  searchResult.textContent = "Searching...";
  try {
    const result = await fetchJson(`/search?q=${encodeURIComponent(query)}`);
    if (result.kind === "block") {
      const b = result.block;
      searchResult.innerHTML = `<div><strong>Block ${escapeHtml(b.height)}</strong></div>
        <div>Hash: ${escapeHtml(b.hash)}</div>
        <div>Time: ${escapeHtml(formatTime(b.time))}</div>
        <div>Proposer: ${escapeHtml(b.proposer)}</div>
        <div>Txs: ${escapeHtml(b.num_txs)}</div>`;
      return;
    }
    if (result.kind === "validator") {
      const v = result.validator;
      searchResult.innerHTML = `<div><strong>Validator ${escapeHtml(v.address)}</strong></div>
        <div>Latest height: ${escapeHtml(result.latest_height)}</div>
        <div>Voting power: ${escapeHtml(v.voting_power)}</div>
        <div>Proposer priority: ${escapeHtml(v.proposer_priority)}</div>
        <div>Signed last block: ${escapeHtml(v.signed_last_block ? "yes" : "no")}</div>
        <div>Validator set size: ${escapeHtml(result.total)}</div>`;
      return;
    }
    if (result.kind === "tx") {
      const t = result.tx;
      searchResult.innerHTML = `<div><strong>Tx ${escapeHtml(t.hash)}</strong></div>
        <div>Height: ${escapeHtml(t.height)}</div>
        <div>Index: ${escapeHtml(t.index)}</div>
        <div>Code: ${escapeHtml(t.code)}</div>
        <div>Gas: ${escapeHtml(t.gas_used)}/${escapeHtml(t.gas_wanted)}</div>`;
      return;
    }
    if (result.kind === "trace_address") {
      const trace = result.trace;
      const balances = (trace.balances || [])
        .map((item) => {
          const lots = (item.lots || [])
            .map((lot) => `${lot.lot_id}: ${lot.amount} (${(lot.risk_basis_points / 100).toFixed(2)}% tainted)`)
            .join("<br/>");
          return `<div><strong>${escapeHtml(item.denom)}</strong> total ${escapeHtml(item.total_amount)} · tainted ${escapeHtml(item.tainted_amount)} · risk ${(item.risk_basis_points / 100).toFixed(2)}%<div class="muted">${lots}</div></div>`;
        })
        .join("");
      searchResult.innerHTML = `<div><strong>Trace address ${escapeHtml(trace.address)}</strong></div>${balances}${renderTraceGraph(result.graph)}`;
      return;
    }
    if (result.kind === "trace_lot") {
      const lot = result.trace.lot;
      const holders = (lot.holders || [])
        .map((holder) => `${holder.address}: ${holder.amount} (${(holder.risk_basis_points / 100).toFixed(2)}% tainted)`)
        .join("<br/>");
      const parents = Array.isArray(lot.parent_lot_ids) && lot.parent_lot_ids.length ? lot.parent_lot_ids.join(", ") : "origin";
      searchResult.innerHTML = `<div><strong>Lot ${escapeHtml(lot.lot_id)}</strong></div>
        <div>Denom: ${escapeHtml(lot.denom)}</div>
        <div>Root origin: ${escapeHtml(lot.root_origin_lot_id)}</div>
        <div>Parents: ${escapeHtml(parents)}</div>
        <div>Current amount: ${escapeHtml(lot.current_amount)}</div>
        <div>Tainted amount: ${escapeHtml(lot.tainted_amount)}</div>
        <div>Risk: ${(lot.risk_basis_points / 100).toFixed(2)}%</div>
        <div class="muted">${holders}</div>
        ${renderTraceGraph(result.graph)}`;
      return;
    }
    if (result.kind === "trace_tx") {
      const tx = result.trace.tx_effect;
      const flows = (tx.flows || [])
        .map((flow) => {
          const lots = (flow.transferred_lots || [])
            .map((lot) => `${lot.source_lot_id} → ${lot.child_lot_id}: ${lot.amount}`)
            .join("<br/>");
          return `<div><strong>${escapeHtml(flow.from)} → ${escapeHtml(flow.to)}</strong> ${escapeHtml(flow.amount)} ${escapeHtml(flow.denom)} · tainted ${escapeHtml(flow.tainted_amount)} · risk ${(flow.risk_basis_points / 100).toFixed(2)}%<div class="muted">${lots}</div></div>`;
        })
        .join("");
      searchResult.innerHTML = `<div><strong>Trace tx ${escapeHtml(tx.hash)}</strong></div>${flows}${renderTraceGraph(result.graph)}`;
    }
  } catch (err) {
    searchResult.textContent = `Not found: ${err.message}`;
  }
}

async function init() {
  try {
    const config = await fetch("/config").then((r) => r.json());
    indexerBase = config.indexer || "";
  } catch {
    indexerBase = "";
  }
  if (searchHint) {
    searchHint.textContent = "Search block height, tx hash, validator address, chain address, or lot_xxxxxxxx. Trace results now include linked flow graph paths.";
  }
  await refreshAll();
}

refreshBtn.addEventListener("click", () => {
  refreshAll();
});

searchBtn.addEventListener("click", () => {
  runSearch();
});

searchInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    runSearch();
  }
});

init();
setInterval(refreshAll, 5000);
