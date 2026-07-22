#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));

function load(relativePath) {
  return JSON.parse(readFileSync(resolve(root, relativePath), "utf8"));
}

function trackedFiles() {
  return execFileSync("git", ["ls-files", "-z"], { cwd: root })
    .toString("utf8")
    .split("\0")
    .filter(Boolean);
}

function fail(errors, message) {
  errors.push(message);
}

export function verifyTruthRecord(policy, record) {
  const errors = [];
  for (const field of policy.requiredTruthStates) {
    if (typeof record.states?.[field] !== "boolean") {
      fail(errors, `truth state ${field} must be boolean`);
      continue;
    }
    if (record.states[field] === true) {
      const evidence = record.evidence?.[field];
      if (!Array.isArray(evidence) || evidence.length === 0) {
        fail(errors, `truth state ${field}=true requires evidence`);
      }
    }
  }
  for (const field of Object.keys(record.states ?? {})) {
    if (!policy.requiredTruthStates.includes(field)) {
      fail(errors, `unknown truth state ${field}`);
    }
  }
  if (!/^[0-9a-f]{40}$/.test(record.sourceCommit ?? "")) {
    fail(errors, "sourceCommit must be a full Git SHA");
  }
  return errors;
}

export function verifyArtifactRegistry(policy, registry, filesystemRoot = root) {
  const errors = [];
  const ids = new Set();
  for (const artifact of registry.artifacts ?? []) {
    if (!artifact.id || ids.has(artifact.id)) fail(errors, `artifact id is missing or duplicated: ${artifact.id ?? ""}`);
    ids.add(artifact.id);
    if (!policy.artifactKinds.includes(artifact.kind)) fail(errors, `artifact ${artifact.id}: invalid kind`);
    if (!/^[0-9a-f]{40}$/.test(artifact.sourceCommit ?? "")) fail(errors, `artifact ${artifact.id}: invalid sourceCommit`);
    if (!/^[0-9a-f]{64}$/.test(artifact.sha256 ?? "")) fail(errors, `artifact ${artifact.id}: invalid sha256`);
    if (!Number.isSafeInteger(artifact.bytes) || artifact.bytes < 1) fail(errors, `artifact ${artifact.id}: invalid bytes`);
    if (!policy.signingClasses.includes(artifact.signingClass)) fail(errors, `artifact ${artifact.id}: invalid signingClass`);
    for (const field of ["buildRun", "sbom", "minimumOs", "installEvidence", "revocation", "expiry"]) {
      if (typeof artifact[field] !== "string" || artifact[field].trim() === "") fail(errors, `artifact ${artifact.id}: missing ${field}`);
    }
    if (artifact.path) {
      const path = resolve(filesystemRoot, artifact.path);
      try {
        const bytes = statSync(path).size;
        const sha256 = createHash("sha256").update(readFileSync(path)).digest("hex");
        if (bytes !== artifact.bytes) fail(errors, `artifact ${artifact.id}: byte count mismatch`);
        if (sha256 !== artifact.sha256) fail(errors, `artifact ${artifact.id}: digest mismatch`);
      } catch {
        fail(errors, `artifact ${artifact.id}: local path cannot be verified`);
      }
    }
  }
  return errors;
}

export function verifySecretInventory(policy, inventory) {
  const errors = [];
  const ids = new Set();
  for (const secret of inventory.secrets ?? []) {
    if (!secret.id || ids.has(secret.id)) fail(errors, `secret id is missing or duplicated: ${secret.id ?? ""}`);
    ids.add(secret.id);
    if (!policy.secretClasses.includes(secret.class)) fail(errors, `secret ${secret.id}: invalid class`);
    for (const field of ["owner", "managerReference", "expiresAt", "rotationRunbook", "lastRotationEvidence"]) {
      if (typeof secret[field] !== "string" || secret[field].trim() === "") fail(errors, `secret ${secret.id}: missing ${field}`);
    }
    const serialized = JSON.stringify(secret);
    if (/privateKey|seedPhrase|mnemonic|secretValue|credentialValue/i.test(serialized)) {
      fail(errors, `secret ${secret.id}: inventory contains forbidden value-bearing field`);
    }
  }
  return errors;
}

export function scanTrackedFiles(policy, files = trackedFiles()) {
  const errors = [];
  const pathPatterns = policy.prohibitedTrackedFilePatterns.map((value) => new RegExp(value));
  const contentPatterns = policy.prohibitedContentPatterns.map((value) => new RegExp(value, "i"));
  const exemptPrefixes = policy.contentScanExemptPrefixes ?? [];
  const exemptFiles = new Set(policy.contentScanExemptFiles ?? []);
  for (const relativePath of files) {
    if (pathPatterns.some((pattern) => pattern.test(relativePath))) {
      fail(errors, `prohibited tracked file: ${relativePath}`);
      continue;
    }
    if (exemptFiles.has(relativePath) || exemptPrefixes.some((prefix) => relativePath.startsWith(prefix))) continue;
    const path = resolve(root, relativePath);
    let content;
    try {
      if (statSync(path).size > 2_000_000) continue;
      content = readFileSync(path, "utf8");
    } catch {
      continue;
    }
    if (contentPatterns.some((pattern) => pattern.test(content))) fail(errors, `secret-like content: ${relativePath}`);
  }
  return errors;
}

export function verify() {
  const policy = load("security-platform/platform-policy.json");
  const errors = [
    ...verifyTruthRecord(policy, load("release/platform-status.json")),
    ...verifyArtifactRegistry(policy, load("release/artifact-registry.json")),
    ...verifySecretInventory(policy, load("security-platform/secret-inventory.json")),
    ...scanTrackedFiles(policy),
  ];
  if (errors.length > 0) {
    for (const error of errors) process.stderr.write(`FAIL ${error}\n`);
    process.exitCode = 1;
    return;
  }
  process.stdout.write("PASS security platform policy, truth, artifacts, secret metadata, and tracked-file gates\n");
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (process.argv[2] !== "verify") {
    process.stderr.write("usage: node scripts/security-platform.mjs verify\n");
    process.exitCode = 2;
  } else {
    verify();
  }
}
