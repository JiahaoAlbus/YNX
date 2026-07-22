#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { generateKeyPairSync, randomBytes } from "node:crypto";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { performance } from "node:perf_hooks";
import { fileURLToPath } from "node:url";
import { signManifest, verifyManifestSignature } from "./security-artifact.mjs";
import { createBackup, restoreBackup } from "./security-backup.mjs";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));

function percentile(sorted, value) {
  return sorted[Math.min(sorted.length - 1, Math.max(0, Math.ceil((value / 100) * sorted.length) - 1))];
}

function summarize(samples, units) {
  const sorted = [...samples].sort((a, b) => a - b);
  const total = samples.reduce((sum, value) => sum + value, 0);
  return {
    samples: samples.length,
    units,
    p50: Number(percentile(sorted, 50).toFixed(3)),
    p95: Number(percentile(sorted, 95).toFixed(3)),
    p99: Number(percentile(sorted, 99).toFixed(3)),
    mean: Number((total / samples.length).toFixed(3)),
    throughputPerSecond: Number((1000 / (total / samples.length)).toFixed(3)),
    errors: 0,
  };
}

function measure(iterations, operation) {
  const samples = [];
  for (let index = 0; index < iterations; index += 1) {
    const started = performance.now();
    operation(index);
    samples.push(performance.now() - started);
  }
  return samples;
}

export function benchmark({ output }) {
  const sourceCommit = execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
  const workspace = mkdtempSync(join(tmpdir(), "ynx-security-benchmark-"));
  const manifestPath = join(workspace, "manifest.json");
  const privateKeyPath = join(workspace, "private.pem");
  const publicKeyPath = join(workspace, "public.pem");
  const signaturePath = join(workspace, "signature.json");
  const { privateKey, publicKey } = generateKeyPairSync("ed25519");
  writeFileSync(manifestPath, `${JSON.stringify({ sourceCommit, sha256: "a".repeat(64) })}\n`);
  writeFileSync(privateKeyPath, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
  writeFileSync(publicKeyPath, publicKey.export({ type: "spki", format: "pem" }));
  signManifest({ manifestPath, privateKeyPath, signaturePath });

  const source = join(workspace, "backup-source");
  mkdirSync(source);
  writeFileSync(join(source, "payload.bin"), randomBytes(1024 * 1024));
  const keyFile = join(workspace, "backup.key");
  writeFileSync(keyFile, randomBytes(32), { mode: 0o600 });

  const policySamples = measure(30, () => execFileSync(process.execPath, ["scripts/security-platform.mjs", "verify"], { cwd: root, stdio: "ignore" }));
  const signatureSamples = measure(200, () => verifyManifestSignature({ manifestPath, signaturePath, publicKeyPath }));
  const backupCreateSamples = measure(10, (index) => createBackup({
    source, output: join(workspace, `backup-${index}.enc`), manifestPath: join(workspace, `backup-${index}.json`), keyFile, sourceCommit,
  }));
  const backupRestoreSamples = measure(10, (index) => restoreBackup({
    backup: join(workspace, `backup-${index}.enc`), manifestPath: join(workspace, `backup-${index}.json`),
    destination: join(workspace, `restore-${index}`), keyFile,
  }));

  const result = {
    schemaVersion: 1,
    sourceCommit,
    measuredAt: new Date().toISOString(),
    environment: { platform: process.platform, architecture: process.arch, node: process.version },
    coverage: "local single-process small-sample benchmark; not public capacity evidence",
    payloadBytes: readFileSync(join(source, "payload.bin")).length,
    measurements: {
      policyGate: summarize(policySamples, "milliseconds per full gate"),
      signatureVerify: summarize(signatureSamples, "milliseconds per Ed25519 verification"),
      encryptedBackupCreate: summarize(backupCreateSamples, "milliseconds per 1 MiB backup"),
      encryptedBackupRestore: summarize(backupRestoreSamples, "milliseconds per 1 MiB restore"),
    },
  };
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`);
  return result;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const output = process.argv[2] ? resolve(process.argv[2]) : resolve(root, "evidence/security-platform/LOCAL_CAPACITY_2026-07-22.json");
  process.stdout.write(`${JSON.stringify(benchmark({ output }), null, 2)}\n`);
}
