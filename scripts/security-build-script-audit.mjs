#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const lock = JSON.parse(readFileSync(resolve(root, "package-lock.json"), "utf8"));
const allowlist = JSON.parse(readFileSync(resolve(root, "security-platform/build-script-allowlist.json"), "utf8"));
const lifecycle = new Set(["preinstall", "install", "postinstall", "prepare", "prepublish", "prepublishOnly"]);
const errors = [];

for (const [path, entry] of Object.entries(lock.packages ?? {})) {
  if (!entry?.hasInstallScript) continue;
  const allowed = allowlist.allowed?.[path];
  if (!allowed) errors.push(`${path || "<root>"}: install script is not allowlisted`);
}

for (const [path, scripts] of Object.entries(allowlist.allowed ?? {})) {
  const packagePath = path ? resolve(root, path, "package.json") : resolve(root, "package.json");
  const pkg = JSON.parse(readFileSync(packagePath, "utf8"));
  for (const [name, expected] of Object.entries(scripts)) {
    if (name === "implicitNodeGyp") {
      if (expected !== true || pkg.gypfile !== true) errors.push(`${path || "<root>"}: implicit node-gyp approval does not match package metadata`);
      continue;
    }
    if (name === "lockFlagOnlyReviewed") {
      const installHooks = ["preinstall", "install", "postinstall", "prepare"].filter((hook) => pkg.scripts?.[hook]);
      if (expected !== true || installHooks.length > 0) errors.push(`${path || "<root>"}: lock-only approval conflicts with lifecycle hooks`);
      continue;
    }
    if (!lifecycle.has(name)) errors.push(`${path || "<root>"}: unsupported lifecycle key ${name}`);
    if (pkg.scripts?.[name] !== expected) errors.push(`${path || "<root>"}: ${name} differs from reviewed command`);
  }
}

if (errors.length > 0) {
  for (const error of errors) process.stderr.write(`FAIL ${error}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write("PASS package lifecycle script allowlist\n");
}
