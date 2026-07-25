#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const workflow = readFileSync(resolve(root, ".github/workflows/security-platform-deploy.yml"), "utf8");
const forbidden = [
  ["static cluster credential reference", /KUBECONFIG_[A-Z_]+/],
  ["direct Kubernetes mutation", /kubectl\s+(?:apply|delete|patch|replace|rollout\s+undo)\b/i],
  ["cloud cluster credential mutation", /(?:aws\s+eks\s+update-kubeconfig|gcloud\s+container\s+clusters\s+get-credentials)\b/i],
  ["production secret context", /\$\{\{\s*secrets\.[^}]+\}\}/i],
  ["OIDC write permission without deployment contract", /id-token:\s*write\b/i],
];

const failures = forbidden
  .filter(([, pattern]) => pattern.test(workflow))
  .map(([label]) => label);

if (failures.length > 0) {
  for (const failure of failures) process.stderr.write(`FAIL ${failure}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write("PASS workflow is validation-only and contains no deployment credential path\n");
}
