const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const net = require("node:net");
const { spawn } = require("node:child_process");
const { setTimeout: delay } = require("node:timers/promises");

async function getFreePort() {
  return await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      server.close((err) => {
        if (err) return reject(err);
        resolve(address.port);
      });
    });
    server.on("error", reject);
  });
}

async function makeTempDir(prefix) {
  return await fs.mkdtemp(path.join(os.tmpdir(), prefix));
}

async function waitForJson(url, { attempts = 50, sleepMs = 100 } = {}) {
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return {
          status: response.status,
          body: await response.json(),
        };
      }
      lastError = new Error(`HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await delay(sleepMs);
  }
  throw lastError || new Error(`Unable to reach ${url}`);
}

async function requestJson(url, { method = "GET", body, headers = {} } = {}) {
  const response = await fetch(url, {
    method,
    headers: {
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
      ...headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });

  let payload = null;
  const text = await response.text();
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch (error) {
      payload = { raw: text, parse_error: error.message };
    }
  }

  return {
    status: response.status,
    ok: response.ok,
    headers: response.headers,
    body: payload,
  };
}

async function startNodeServer(scriptPath, env, readyUrl) {
  const child = spawn(process.execPath, [scriptPath], {
    env: {
      ...process.env,
      ...env,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });

  let stderr = "";
  let stdout = "";
  child.stdout.on("data", (chunk) => {
    stdout += chunk.toString();
  });
  child.stderr.on("data", (chunk) => {
    stderr += chunk.toString();
  });

  child.on("exit", (code) => {
    if (code !== 0) {
      stderr += `\nprocess_exit=${code}`;
    }
  });

  try {
    await waitForJson(readyUrl);
  } catch (error) {
    await stopProcess(child);
    error.message = `${error.message}\nstdout:\n${stdout}\nstderr:\n${stderr}`;
    throw error;
  }

  return {
    child,
    async stop() {
      await stopProcess(child);
    },
  };
}

async function stopProcess(child) {
  if (!child || child.exitCode !== null) return;
  child.kill("SIGTERM");
  const didExit = await Promise.race([
    new Promise((resolve) => child.once("exit", resolve)),
    delay(1500).then(() => false),
  ]);
  if (didExit === false && child.exitCode === null) {
    child.kill("SIGKILL");
    await new Promise((resolve) => child.once("exit", resolve));
  }
}

async function writeJson(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, JSON.stringify(value, null, 2));
}

function assertJson(response, expectedStatus) {
  assert.equal(response.status, expectedStatus, `expected HTTP ${expectedStatus}, got ${response.status}: ${JSON.stringify(response.body)}`);
  assert.ok(response.body && typeof response.body === "object", "expected JSON body");
  return response.body;
}

module.exports = {
  assertJson,
  getFreePort,
  makeTempDir,
  requestJson,
  startNodeServer,
  stopProcess,
  waitForJson,
  writeJson,
};
