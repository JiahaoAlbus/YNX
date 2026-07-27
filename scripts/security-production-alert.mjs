#!/usr/bin/env node
/**
 * Fail-closed delivery of production change alerts.
 *
 * The credential is supplied as a curl header file from the runtime Secret
 * Manager mount. Its value is read only to validate the single-header boundary;
 * it is never placed in argv, persisted in evidence, or included in an error.
 * The receiver must return a bounded receipt that proves acceptance of the
 * exact event digest and idempotency key.
 */

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { isIP } from "node:net";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const actions = new Set([
  "production-deployment",
  "production-blue-green-update",
  "production-manual-rollback",
]);
const responseFields = [
  "acceptedAt",
  "alertId",
  "eventDigestSha256",
  "idempotencyEnforced",
  "providerEventId",
  "schemaVersion",
  "status",
];

function canonicalJson(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  return `{${Object.keys(value).sort().map((key) => (
    `${JSON.stringify(key)}:${canonicalJson(value[key])}`
  )).join(",")}}`;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function safeIdentifier(value, label) {
  if (typeof value !== "string" || !/^[A-Za-z0-9._:@/-]{3,256}$/.test(value)) {
    throw new Error(`${label} must be a safe identifier`);
  }
  return value;
}

function digest(value, label) {
  if (!/^[0-9a-f]{64}$/.test(value ?? "")) throw new Error(`${label} must be sha256`);
  return value;
}

function validDate(value, label) {
  if (!(value instanceof Date) || !Number.isFinite(value.getTime())) {
    throw new Error(`${label} is invalid`);
  }
  return value;
}

function validateEndpoint(endpoint, expectedHost) {
  if (
    typeof expectedHost !== "string"
    || expectedHost.length > 253
    || expectedHost === "localhost"
    || isIP(expectedHost) !== 0
    || !/^(?=.{4,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(expectedHost)
  ) {
    throw new Error("production alert expected host must be a public DNS name");
  }
  let url;
  try {
    url = new URL(endpoint);
  } catch {
    throw new Error("production alert endpoint is invalid");
  }
  if (
    url.protocol !== "https:"
    || url.hostname !== expectedHost
    || (url.port !== "" && url.port !== "443")
    || url.username !== ""
    || url.password !== ""
    || url.search !== ""
    || url.hash !== ""
    || url.pathname === "/"
    || url.pathname.includes("//")
  ) {
    throw new Error("production alert endpoint is not an exact pinned HTTPS target");
  }
  return url.toString();
}

function validateCredentialHeaderFile(path) {
  if (
    typeof path !== "string"
    || !/^\/run\/secrets\/ynx\/[a-z0-9][a-z0-9._-]{2,127}$/.test(path)
  ) {
    throw new Error("production alert credential must be a named Secret Manager header mount");
  }
  return path;
}

function validateCredentialHeader(readFile, path) {
  let value;
  try {
    value = readFile(path, "utf8");
  } catch {
    throw new Error("production alert credential header read failed");
  }
  if (
    typeof value !== "string"
    || value.length < 43
    || value.length > 4096
    || !/^Authorization: Bearer [A-Za-z0-9._~+/=-]{20,4050}\n?$/.test(value)
  ) {
    throw new Error("production alert credential header boundary is invalid");
  }
}

function runCurl(execFile, args, input) {
  try {
    return execFile("curl", args, {
      cwd: root,
      encoding: "utf8",
      input,
      maxBuffer: 64 * 1024,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch {
    throw new Error("production change alert delivery failed");
  }
}

export function buildProductionChangeAlert({
  approval,
  operatorId,
  expectedClusterUid,
  createdAt,
}) {
  safeIdentifier(operatorId, "operatorId");
  safeIdentifier(expectedClusterUid, "expectedClusterUid");
  const timestamp = validDate(createdAt, "production alert creation time");
  if (
    approval?.bound !== true
    || approval.schemaVersion !== 1
    || approval.immediateAlertRequired !== true
    || !actions.has(approval.action)
  ) {
    throw new Error("production alert requires a bound alert-required approval");
  }
  safeIdentifier(approval.changeId, "changeId");
  digest(approval.authorizationId, "authorizationId");
  digest(approval.resourceReferenceSha256, "resourceReferenceSha256");
  const expiresAt = Date.parse(approval.expiresAt);
  if (!Number.isFinite(expiresAt) || expiresAt <= timestamp.getTime()) {
    throw new Error("production alert approval is expired");
  }
  const alertId = sha256(`ynx-production-change-alert-v1\0${canonicalJson({
    action: approval.action,
    authorizationId: approval.authorizationId,
    changeId: approval.changeId,
    resourceReferenceSha256: approval.resourceReferenceSha256,
  })}`);
  const event = {
    schemaVersion: 1,
    eventType: "ynx.production.change.authorized",
    severity: approval.action === "production-manual-rollback" ? "critical" : "high",
    environment: "production",
    action: approval.action,
    alertId,
    changeId: approval.changeId,
    authorizationId: approval.authorizationId,
    authorizationType: approval.type,
    resourceReferenceSha256: approval.resourceReferenceSha256,
    operatorIdentity: operatorId,
    clusterUidSha256: sha256(expectedClusterUid),
    incidentId: approval.incidentId ?? null,
    createdAt: timestamp.toISOString(),
    authorizationExpiresAt: approval.expiresAt,
    secretValueIncluded: false,
  };
  return {
    event,
    eventDigestSha256: sha256(canonicalJson(event)),
  };
}

export function deliverProductionChangeAlert({
  approval,
  operatorId,
  expectedClusterUid,
  endpoint,
  expectedHost,
  credentialHeaderFile,
  execFile = execFileSync,
  readFile = readFileSync,
  now = () => new Date(),
}) {
  if (typeof execFile !== "function" || typeof readFile !== "function" || typeof now !== "function") {
    throw new Error("production alert runtime dependencies are invalid");
  }
  const target = validateEndpoint(endpoint, expectedHost);
  const credentialPath = validateCredentialHeaderFile(credentialHeaderFile);
  validateCredentialHeader(readFile, credentialPath);
  const startedAt = validDate(now(), "production alert dispatch start");
  const alert = buildProductionChangeAlert({
    approval,
    operatorId,
    expectedClusterUid,
    createdAt: startedAt,
  });
  const output = runCurl(execFile, [
    "--silent",
    "--show-error",
    "--max-time", "10",
    "--connect-timeout", "5",
    "--proto", "=https",
    "--tlsv1.2",
    "--request", "POST",
    "--header", "Content-Type: application/json",
    "--header", "Accept: application/json",
    "--header", `Idempotency-Key: ${alert.event.alertId}`,
    "--header", `X-YNX-Event-SHA256: ${alert.eventDigestSha256}`,
    "--header", `@${credentialPath}`,
    "--data-binary", "@-",
    "--write-out", "\n%{http_code}",
    target,
  ], `${JSON.stringify(alert)}\n`);
  const splitAt = output.lastIndexOf("\n");
  if (splitAt < 0 || output.slice(splitAt + 1).trim() !== "202") {
    throw new Error("production change alert was not accepted");
  }
  let receipt;
  try {
    receipt = JSON.parse(output.slice(0, splitAt));
  } catch {
    throw new Error("production change alert receipt is invalid JSON");
  }
  const completedAt = validDate(now(), "production alert dispatch completion");
  const acceptedAt = Date.parse(receipt?.acceptedAt);
  const expiresAt = Date.parse(approval.expiresAt);
  if (
    receipt == null
    || typeof receipt !== "object"
    || Array.isArray(receipt)
    || Object.keys(receipt).sort().join(",") !== responseFields.join(",")
    || receipt.schemaVersion !== 1
    || receipt.status !== "accepted"
    || receipt.alertId !== alert.event.alertId
    || receipt.eventDigestSha256 !== alert.eventDigestSha256
    || receipt.idempotencyEnforced !== true
    || typeof receipt.providerEventId !== "string"
    || !/^[A-Za-z0-9._:@/-]{3,256}$/.test(receipt.providerEventId)
    || !Number.isFinite(acceptedAt)
    || acceptedAt < startedAt.getTime() - 60_000
    || acceptedAt > completedAt.getTime() + 60_000
    || acceptedAt >= expiresAt
  ) {
    throw new Error("production change alert receipt does not bind the dispatched event");
  }
  return {
    schemaVersion: 1,
    alertId: alert.event.alertId,
    eventDigestSha256: alert.eventDigestSha256,
    providerHostSha256: sha256(expectedHost),
    providerEventIdSha256: sha256(receipt.providerEventId),
    acceptedAt: new Date(acceptedAt).toISOString(),
    idempotencyEnforced: true,
    credentialSource: "runtime Secret Manager header mount",
    secretValueIncluded: false,
    delivered: true,
  };
}
