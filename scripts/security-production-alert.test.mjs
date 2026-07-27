import test from "node:test";
import assert from "node:assert/strict";
import {
  buildProductionChangeAlert,
  deliverProductionChangeAlert,
} from "./security-production-alert.mjs";

const now = new Date("2026-07-27T05:00:00.000Z");
const clusterUid = "11111111-2222-3333-4444-555555555555";
const operatorId = "production-operator";

function approval(overrides = {}) {
  return {
    schemaVersion: 1,
    type: "release-approval",
    action: "production-deployment",
    changeId: "change-20260727-production",
    authorizationId: "a".repeat(64),
    resourceReferenceSha256: "b".repeat(64),
    approvedAt: "2026-07-27T04:30:00.000Z",
    expiresAt: "2026-07-27T05:30:00.000Z",
    immediateAlertRequired: true,
    bound: true,
    ...overrides,
  };
}

function acceptedResponse(input, overrides = {}) {
  const envelope = JSON.parse(input);
  return {
    schemaVersion: 1,
    status: "accepted",
    alertId: envelope.event.alertId,
    eventDigestSha256: envelope.eventDigestSha256,
    providerEventId: "alert-provider-event-0001",
    acceptedAt: "2026-07-27T05:00:01.000Z",
    idempotencyEnforced: true,
    ...overrides,
  };
}

function deliver({ approvalOverrides, responseOverrides, endpoint, expectedHost, credentialHeaderFile } = {}) {
  const calls = [];
  const execFile = (command, args, options) => {
    calls.push({ command, args, options });
    return `${JSON.stringify(acceptedResponse(options.input, responseOverrides))}\n202`;
  };
  const times = [
    new Date(now),
    new Date("2026-07-27T05:00:02.000Z"),
  ];
  const result = deliverProductionChangeAlert({
    approval: approval(approvalOverrides),
    operatorId,
    expectedClusterUid: clusterUid,
    endpoint: endpoint ?? "https://alerts.security.ynxweb4.com/v1/events",
    expectedHost: expectedHost ?? "alerts.security.ynxweb4.com",
    credentialHeaderFile: credentialHeaderFile ?? "/run/secrets/ynx/production-alert-authorization-header",
    execFile,
    readFile: () => "Authorization: Bearer test-production-alert-token-1234567890\n",
    now: () => times.shift(),
  });
  return { result, calls };
}

test("alert event binds approval, operator, cluster, and authorization window", () => {
  const result = buildProductionChangeAlert({
    approval: approval(),
    operatorId,
    expectedClusterUid: clusterUid,
    createdAt: now,
  });
  assert.equal(result.event.eventType, "ynx.production.change.authorized");
  assert.equal(result.event.severity, "high");
  assert.equal(result.event.authorizationId, "a".repeat(64));
  assert.equal(result.event.operatorIdentity, operatorId);
  assert.match(result.event.clusterUidSha256, /^[0-9a-f]{64}$/);
  assert.match(result.eventDigestSha256, /^[0-9a-f]{64}$/);
  assert.equal(result.event.secretValueIncluded, false);
});

test("delivery uses pinned HTTPS and a Secret Manager header file", () => {
  const { result, calls } = deliver();
  assert.equal(result.delivered, true);
  assert.equal(result.idempotencyEnforced, true);
  assert.equal(result.secretValueIncluded, false);
  assert.match(result.providerEventIdSha256, /^[0-9a-f]{64}$/);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].command, "curl");
  assert.ok(calls[0].args.includes("=https"));
  assert.ok(calls[0].args.includes("@/run/secrets/ynx/production-alert-authorization-header"));
  assert.doesNotMatch(JSON.stringify(calls[0].args), /Bearer|token|secret-value/i);
  assert.equal(JSON.parse(calls[0].options.input).event.secretValueIncluded, false);
});

test("endpoint drift and unsafe credential sources fail before network access", () => {
  for (const options of [
    { endpoint: "http://alerts.security.ynxweb4.com/v1/events" },
    { endpoint: "https://different.ynxweb4.com/v1/events" },
    { endpoint: "https://alerts.security.ynxweb4.com/v1/events?token=value" },
    { expectedHost: "127.0.0.1", endpoint: "https://127.0.0.1/v1/events" },
    { credentialHeaderFile: "/tmp/alert-token" },
  ]) {
    assert.throws(() => deliver(options), /production alert/);
  }
});

test("credential mount must contain exactly one bounded bearer header", () => {
  for (const value of [
    "token-value",
    "Authorization: Basic dXNlcjpwYXNz\n",
    "Authorization: Bearer short\n",
    "Authorization: Bearer valid-production-alert-token-12345\nHost: other.example\n",
  ]) {
    assert.throws(
      () => deliverProductionChangeAlert({
        approval: approval(),
        operatorId,
        expectedClusterUid: clusterUid,
        endpoint: "https://alerts.security.ynxweb4.com/v1/events",
        expectedHost: "alerts.security.ynxweb4.com",
        credentialHeaderFile: "/run/secrets/ynx/production-alert-authorization-header",
        readFile: () => value,
        execFile: () => {
          throw new Error("network must not be reached");
        },
        now: () => now,
      }),
      /credential header boundary/,
    );
  }
});

test("provider failures cannot echo credential material", () => {
  const secret = "production-alert-secret-value-1234567890";
  assert.throws(
    () => deliverProductionChangeAlert({
      approval: approval(),
      operatorId,
      expectedClusterUid: clusterUid,
      endpoint: "https://alerts.security.ynxweb4.com/v1/events",
      expectedHost: "alerts.security.ynxweb4.com",
      credentialHeaderFile: "/run/secrets/ynx/production-alert-authorization-header",
      readFile: () => `Authorization: Bearer ${secret}\n`,
      execFile: () => {
        throw new Error(`provider rejected ${secret}`);
      },
      now: () => now,
    }),
    (error) => {
      assert.equal(error.message, "production change alert delivery failed");
      assert.doesNotMatch(error.message, new RegExp(secret));
      return true;
    },
  );
});

test("unbound, non-alerting, and expired approvals fail closed", () => {
  for (const approvalOverrides of [
    { bound: false },
    { immediateAlertRequired: false },
    { expiresAt: "2026-07-27T04:59:59.000Z" },
    { authorizationId: "not-a-digest" },
  ]) {
    assert.throws(() => deliver({ approvalOverrides }), /production alert|authorizationId/);
  }
});

test("provider status, event drift, idempotency, and time are verified", () => {
  for (const responseOverrides of [
    { status: "queued" },
    { alertId: "c".repeat(64) },
    { eventDigestSha256: "d".repeat(64) },
    { idempotencyEnforced: false },
    { acceptedAt: "2026-07-27T06:00:00.000Z" },
  ]) {
    assert.throws(
      () => deliver({ responseOverrides }),
      /receipt does not bind/,
    );
  }
});

test("rollback alert is critical and carries the incident binding", () => {
  const result = buildProductionChangeAlert({
    approval: approval({
      type: "break-glass-authorization",
      action: "production-manual-rollback",
      incidentId: "inc-20260727-production",
      authorizedAt: "2026-07-27T04:59:00.000Z",
      approvedAt: undefined,
    }),
    operatorId,
    expectedClusterUid: clusterUid,
    createdAt: now,
  });
  assert.equal(result.event.severity, "critical");
  assert.equal(result.event.incidentId, "inc-20260727-production");
});
