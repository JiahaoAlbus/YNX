const http = require("http");
const fs = require("fs");
const path = require("path");

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
if (process.env.EXPLORER_ENV_FILE) envCandidates.push(process.env.EXPLORER_ENV_FILE);
if (process.env.YNX_ENV_FILE) envCandidates.push(process.env.YNX_ENV_FILE);
envCandidates.push(path.resolve(__dirname, ".env"));
envCandidates.push(path.resolve(__dirname, "../../.env"));
for (const candidate of envCandidates) {
  loadEnvFile(candidate);
}

const PORT = parseInt(process.env.EXPLORER_PORT || "8082", 10);
const INDEXER_URL = process.env.EXPLORER_INDEXER || "http://127.0.0.1:8081";
const PUBLIC_DIR = path.resolve(__dirname, "public");

function contentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html";
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".js")) return "text/javascript";
  if (filePath.endsWith(".json")) return "application/json";
  return "application/octet-stream";
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");

  if (url.pathname === "/config") {
    const body = JSON.stringify({ indexer: INDEXER_URL });
    res.writeHead(200, {
      "content-type": "application/json",
      "content-length": Buffer.byteLength(body),
    });
    return res.end(body);
  }

  let filePath = url.pathname === "/" ? "/index.html" : url.pathname;
  filePath = path.normalize(filePath).replace(/^(\.\.[/\\])+/, "");
  const absPath = path.join(PUBLIC_DIR, filePath);

  if (!absPath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end("Forbidden");
  }

  if (!fs.existsSync(absPath) || fs.statSync(absPath).isDirectory()) {
    res.writeHead(404);
    return res.end("Not found");
  }

  const data = fs.readFileSync(absPath);
  res.writeHead(200, { "content-type": contentType(absPath) });
  return res.end(data);
});

server.listen(PORT, () => {
  console.log(`YNX explorer listening on :${PORT}`);
  console.log(`Indexer: ${INDEXER_URL}`);
});
