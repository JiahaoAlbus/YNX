#!/usr/bin/env node
/**
 * Operator-invoked secret rotation controls.
 *
 * Secret values are never read into JavaScript, printed, written to evidence,
 * or placed directly in process arguments. AWS CLI receives a file:// reference
 * to a caller-owned 0600 file. Rotation and old-version revocation are separate
 * steps so the grace period and dependent-service reload can be audited.
 */

import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const inventoryPath = resolve(root, "security-platform/secret-inventory.json");

function parseArgs(values) {
  const args = {};
  for (let index = 0; index < values.length; index += 2) {
    const key = values[index];
    const value = values[index + 1];
    if (!key?.startsWith("--") || value === undefined) {
      throw new Error("arguments must be --name value pairs");
    }
    args[key.slice(2)] = value;
  }
  return args;
}

function loadInventory() {
  return JSON.parse(readFileSync(inventoryPath, "utf8"));
}

function findSecret(inventory, secretId) {
  const secret = (inventory.secrets ?? []).find((entry) => entry.id === secretId);
  if (!secret) throw new Error(`secret ${secretId} is not configured in the inventory`);
  return secret;
}

function awsSecretId(managerReference) {
  const prefix = "aws-secretsmanager://";
  if (!managerReference?.startsWith(prefix)) {
    throw new Error("only aws-secretsmanager:// manager references are executable by this adapter");
  }
  const value = managerReference.slice(prefix.length);
  if (!value || /\s/.test(value)) throw new Error("invalid AWS Secrets Manager reference");
  return value;
}

function runJson(execFile, command, args) {
  const output = execFile(command, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  return JSON.parse(output);
}

function validateValueFile(path) {
  const absolutePath = resolve(path);
  const stat = statSync(absolutePath);
  if (!stat.isFile()) throw new Error("new secret value path must be a regular file");
  if (stat.size < 16 || stat.size > 65_536) throw new Error("new secret value file size is outside the accepted boundary");
  if ((stat.mode & 0o077) !== 0) throw new Error("new secret value file must not be accessible by group or other users");
  return absolutePath;
}

function parseDate(value) {
  const time = Date.parse(value);
  return Number.isFinite(time) ? time : null;
}

export function checkRotationStatus({ inventory = loadInventory(), now = new Date() } = {}) {
  const nowMs = now.getTime();
  return (inventory.secrets ?? []).map((secret) => {
    const rotationDays = Number(secret.rotationPeriodDays ?? 0);
    const lastRotatedMs = parseDate(secret.lastRotatedAt ?? secret.lastRotated);
    const nextRotationMs = parseDate(secret.nextRotationAt ?? secret.nextRotation);
    let status = "metadata-invalid";
    let ageDays = null;

    if (rotationDays > 0 && lastRotatedMs !== null) {
      ageDays = Math.floor((nowMs - lastRotatedMs) / 86_400_000);
      const deadline = nextRotationMs ?? lastRotatedMs + rotationDays * 86_400_000;
      const warningAt = deadline - Math.max(1, Math.ceil(rotationDays * 0.2)) * 86_400_000;
      status = nowMs > deadline ? "overdue" : nowMs >= warningAt ? "warning" : "ok";
    } else if (secret.revocationStatus === "revoked") {
      status = "revoked";
    } else if (secret.auditStatus === "not-configured") {
      status = "not-configured";
    }

    return {
      id: secret.id,
      secretType: secret.secretType ?? secret.class,
      owner: secret.owner,
      environment: secret.environment,
      rotationPeriodDays: rotationDays || null,
      lastRotatedAt: secret.lastRotatedAt ?? secret.lastRotated ?? null,
      nextRotationAt: secret.nextRotationAt ?? secret.nextRotation ?? null,
      ageDays,
      status,
    };
  });
}

export function buildRotationPlan({ secret, graceSeconds = 300, emergency = false }) {
  if (!secret?.id || !secret?.owner || !secret?.managerReference) {
    throw new Error("rotation plan requires secret id, owner, and managerReference");
  }
  if (!Number.isInteger(graceSeconds) || graceSeconds < 0 || graceSeconds > 86_400) {
    throw new Error("graceSeconds must be an integer between 0 and 86400");
  }
  return {
    schemaVersion: 1,
    secretId: secret.id,
    secretType: secret.secretType ?? secret.class,
    owner: secret.owner,
    product: secret.product ?? null,
    environment: secret.environment ?? null,
    managerReference: secret.managerReference,
    emergency,
    graceSeconds,
    steps: [
      "confirm named operator and incident linkage when emergency",
      "validate caller-owned secret file permissions without reading its value",
      "capture current manager version metadata",
      "create a new manager version through a file reference",
      "reload dependent services and verify bounded downtime",
      "observe the dual-key grace period",
      "finalize old-version stage revocation in a separate approved action",
      "attach evidence and update inventory metadata",
    ],
    automaticActionsExcluded: [
      "break-glass approval",
      "dependent-service reload",
      "production isolation",
      "incident declaration",
      "old-version revocation before grace expiry",
    ],
  };
}

export function beginAwsRotation({
  secretId,
  newValuePath,
  operatorId,
  graceSeconds = 300,
  emergency = false,
  incidentId,
  reason,
  evidencePath,
  inventory = loadInventory(),
  now = () => new Date(),
  execFile = execFileSync,
}) {
  if (!operatorId?.trim()) throw new Error("named operatorId is required");
  if (emergency && (!incidentId?.trim() || !reason?.trim())) {
    throw new Error("emergency rotation requires incidentId and reason");
  }

  const secret = findSecret(inventory, secretId);
  const plan = buildRotationPlan({ secret, graceSeconds, emergency });
  const valueFile = validateValueFile(newValuePath);
  const managerId = awsSecretId(secret.managerReference);
  const startedAt = now();

  const before = runJson(execFile, "aws", [
    "secretsmanager",
    "describe-secret",
    "--secret-id",
    managerId,
    "--output",
    "json",
  ]);
  const oldCurrentVersionId = Object.entries(before.VersionIdsToStages ?? {})
    .find(([, stages]) => Array.isArray(stages) && stages.includes("AWSCURRENT"))?.[0];
  if (!oldCurrentVersionId) throw new Error("manager did not expose an AWSCURRENT version");

  const updated = runJson(execFile, "aws", [
    "secretsmanager",
    "update-secret",
    "--secret-id",
    managerId,
    "--secret-string",
    `file://${valueFile}`,
    "--output",
    "json",
  ]);
  if (!updated.VersionId || updated.VersionId === oldCurrentVersionId) {
    throw new Error("manager did not return a distinct new version");
  }

  const completedAt = now();
  const transition = {
    schemaVersion: 1,
    action: "secret-rotation-transition",
    secretId: secret.id,
    secretType: secret.secretType ?? secret.class,
    owner: secret.owner,
    product: secret.product ?? null,
    environment: secret.environment ?? null,
    managerType: "aws-secrets-manager",
    managerReference: secret.managerReference,
    operatorId,
    emergency,
    incidentId: emergency ? incidentId : null,
    reason: emergency ? reason : null,
    startedAt: startedAt.toISOString(),
    completedAt: completedAt.toISOString(),
    oldVersionId: oldCurrentVersionId,
    newVersionId: updated.VersionId,
    graceSeconds,
    graceUntil: new Date(completedAt.getTime() + graceSeconds * 1000).toISOString(),
    state: "pending-dependent-service-verification-and-finalization",
    secretValueRecorded: false,
    dependentServiceReloadVerified: false,
    boundedDowntimeVerified: false,
    oldVersionRevoked: false,
    plan,
  };

  if (evidencePath) {
    const output = resolve(root, evidencePath);
    mkdirSync(dirname(output), { recursive: true });
    writeFileSync(output, `${JSON.stringify(transition, null, 2)}\n`, { mode: 0o600 });
  }
  return transition;
}

export function finalizeAwsRotation({
  transitionPath,
  operatorId,
  dependentServiceReloadEvidence,
  boundedDowntimeEvidence,
  evidencePath,
  now = () => new Date(),
  execFile = execFileSync,
}) {
  if (!operatorId?.trim()) throw new Error("named operatorId is required");
  if (!dependentServiceReloadEvidence?.trim() || !boundedDowntimeEvidence?.trim()) {
    throw new Error("dependent-service reload and bounded-downtime evidence are required");
  }

  const transition = JSON.parse(readFileSync(resolve(transitionPath), "utf8"));
  if (transition.state !== "pending-dependent-service-verification-and-finalization") {
    throw new Error("transition is not pending finalization");
  }
  const currentTime = now();
  if (currentTime.getTime() < Date.parse(transition.graceUntil)) {
    throw new Error("rotation grace period has not expired");
  }

  const managerId = awsSecretId(transition.managerReference);
  runJson(execFile, "aws", [
    "secretsmanager",
    "update-secret-version-stage",
    "--secret-id",
    managerId,
    "--version-stage",
    "AWSPREVIOUS",
    "--remove-from-version-id",
    transition.oldVersionId,
    "--output",
    "json",
  ]);

  const result = {
    ...transition,
    finalizedAt: currentTime.toISOString(),
    finalizedBy: operatorId,
    state: "finalized",
    dependentServiceReloadVerified: true,
    dependentServiceReloadEvidence,
    boundedDowntimeVerified: true,
    boundedDowntimeEvidence,
    oldVersionRevoked: true,
    secretValueRecorded: false,
  };

  if (evidencePath) {
    const output = resolve(root, evidencePath);
    mkdirSync(dirname(output), { recursive: true });
    writeFileSync(output, `${JSON.stringify(result, null, 2)}\n`, { mode: 0o600 });
  }
  return result;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const command = process.argv[2];
    const args = parseArgs(process.argv.slice(3));
    if (command === "status") {
      const results = checkRotationStatus();
      process.stdout.write(`${JSON.stringify({ configuredSecrets: results.length, results }, null, 2)}\n`);
      if (results.some((entry) => entry.status === "overdue" || entry.status === "metadata-invalid")) process.exitCode = 1;
    } else if (command === "plan") {
      const inventory = loadInventory();
      const secret = findSecret(inventory, args["secret-id"]);
      const plan = buildRotationPlan({
        secret,
        graceSeconds: Number(args["grace-seconds"] ?? 300),
        emergency: args.emergency === "true",
      });
      process.stdout.write(`${JSON.stringify(plan, null, 2)}\n`);
    } else if (command === "rotate") {
      if (args.acknowledge !== "operator-action") throw new Error("rotate requires --acknowledge operator-action");
      const result = beginAwsRotation({
        secretId: args["secret-id"],
        newValuePath: args["new-value-file"],
        operatorId: args["operator-id"],
        graceSeconds: Number(args["grace-seconds"] ?? 300),
        emergency: args.emergency === "true",
        incidentId: args["incident-id"],
        reason: args.reason,
        evidencePath: args.evidence,
      });
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else if (command === "finalize") {
      if (args.acknowledge !== "revoke-old-version") throw new Error("finalize requires --acknowledge revoke-old-version");
      const result = finalizeAwsRotation({
        transitionPath: args.transition,
        operatorId: args["operator-id"],
        dependentServiceReloadEvidence: args["reload-evidence"],
        boundedDowntimeEvidence: args["downtime-evidence"],
        evidencePath: args.evidence,
      });
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else {
      throw new Error("usage: security-rotation.mjs status|plan|rotate|finalize with explicit --name value arguments");
    }
  } catch (error) {
    process.stderr.write(`FAIL ${error.message}\n`);
    process.exitCode = 1;
  }
}
