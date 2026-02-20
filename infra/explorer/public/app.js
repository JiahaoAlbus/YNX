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

function renderTable(container, rows, columns) {
  if (!rows.length) {
    container.innerHTML = "<p class=\"muted\">No data</p>";
    return;
  }
  const header = `<tr>${columns.map((c) => `<th>${c.label}</th>`).join("")}</tr>`;
  const body = rows
    .map((row) => {
      const tds = columns.map((c) => `<td>${row[c.key] ?? ""}</td>`).join("");
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
  statusPanel.innerHTML = status.map((line) => `<div>${line}</div>`).join("");
  networkMeta.textContent = `Chain ${health.chain_id || "unknown"} • RPC ${health.rpc || ""}`;
}

async function loadOverview() {
  const overview = await fetchJson("/ynx/overview");
  const gov = overview.governance || {};
  const positioning = overview.positioning || {};
  const feeSplit = `${gov.fee_burn_bps || 0}/${gov.fee_treasury_bps || 0}/${gov.fee_founder_bps || 0}`;
  const extra = [
    `Positioning: ${positioning.statement || "n/a"}`,
    `Founder: ${gov.founder_address || "n/a"}`,
    `Treasury: ${gov.treasury_address || "n/a"}`,
    `Team: ${gov.team_beneficiary_address || "n/a"}`,
    `Community: ${gov.community_recipient_address || "n/a"}`,
    `Fee split bps (burn/treasury/founder): ${feeSplit}`,
    `No base fee: ${String(gov.no_base_fee)}`,
  ];
  statusPanel.innerHTML += extra.map((line) => `<div>${line}</div>`).join("");
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
  validatorsSummary.innerHTML = [
    `Height: ${data.latest_height || 0}`,
    `Validators: ${data.total || 0}`,
    `Signed(last block): ${data.signed_count || 0}`,
  ]
    .map((line) => `<div>${line}</div>`)
    .join("");
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
    if (/^[0-9]+$/.test(query)) {
      const block = await fetchJson(`/blocks/${query}`);
      const b = block.block;
      searchResult.innerHTML = `<div><strong>Block ${b.height}</strong></div>
        <div>Hash: ${b.hash}</div>
        <div>Time: ${formatTime(b.time)}</div>
        <div>Txs: ${b.num_txs}</div>`;
    } else {
      const tx = await fetchJson(`/txs/${query}`);
      const t = tx.tx;
      searchResult.innerHTML = `<div><strong>Tx ${t.hash}</strong></div>
        <div>Height: ${t.height}</div>
        <div>Index: ${t.index}</div>
        <div>Code: ${t.code}</div>
        <div>Gas: ${t.gas_used}/${t.gas_wanted}</div>`;
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
