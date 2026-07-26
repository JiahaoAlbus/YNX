import test from "node:test";
import assert from "node:assert/strict";
import {
  readFileSync,
  rmSync,
} from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  deployProduction,
  preflightProductionDeployment,
} from "./security-production-deploy.mjs";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const sourceCommit = "a".repeat(40);
const quantDigest = "b".repeat(64);
const backupDigest = "d".repeat(64);
const context = "ynx-production";
const clusterUid = "11111111-2222-3333-4444-555555555555";
const version = "1.0.0";

function manifest() {
  return `apiVersion: v1
kind: Namespace
metadata:
  name: ynx-services
  labels:
    environment: production
    security.ynx/manifest-class: production-release
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quant-worker
  namespace: ynx-services
  labels:
    security.ynx/source-commit: ${sourceCommit}
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: worker
        image: registry.ynxweb4.com/security/quant-worker@sha256:${quantDigest}
`;
}

function probePolicy() {
  return {
    schemaVersion: 1,
    environment: "production",
    tlsHosts: [
      "rpc.ynxweb4.com",
      "evm.ynxweb4.com",
      "rest.ynxweb4.com",
      "faucet.ynxweb4.com",
      "indexer.ynxweb4.com",
      "explorer.ynxweb4.com",
      "ai.ynxweb4.com",
      "web4.ynxweb4.com",
    ],
    services: [
      { name: "faucet", host: "faucet.ynxweb4.com", healthPath: "/health", versionPath: "/version" },
      { name: "indexer", host: "indexer.ynxweb4.com", healthPath: "/health", versionPath: "/version" },
      { name: "ai-gateway", host: "ai.ynxweb4.com", healthPath: "/health", versionPath: "/version" },
      { name: "web4-hub", host: "web4.ynxweb4.com", healthPath: "/health", versionPath: "/version" },
    ],
    connectTimeoutSeconds: 5,
    totalTimeoutSeconds: 15,
    maxResponseBytes: 65536,
  };
}

function releaseBundle() {
  return {
    receipt: {
      schemaVersion: 1,
      action: "production-release-preflight",
      sourceCommit,
      runtimeSourceCommit: sourceCommit,
      version,
      productionManifestSha256: "e".repeat(64),
      publicProbePolicySha256: "f".repeat(64),
      productionSigned: true,
      deployedPublic: false,
      mutationPerformed: false,
    },
    manifest: manifest(),
    attestation: {
      images: [
        {
          role: "backup-operator",
          reference: `registry.ynxweb4.com/security/backup-operator@sha256:${backupDigest}`,
        },
        {
          role: "quant-worker",
          reference: `registry.ynxweb4.com/security/quant-worker@sha256:${quantDigest}`,
        },
      ],
    },
    publicProbePolicy: probePolicy(),
  };
}

function deploymentList() {
  return {
    items: [{
      metadata: {
        name: "quant-worker",
        generation: 4,
        labels: { "security.ynx/source-commit": sourceCommit },
      },
      spec: { replicas: 3 },
      status: { observedGeneration: 4, availableReplicas: 3 },
    }],
  };
}

function pods() {
  return {
    items: [1, 2, 3].map((index) => ({
      metadata: { name: `quant-worker-${index}`, labels: { app: "quant-worker" } },
      status: {
        conditions: [{ type: "Ready", status: "True" }],
        containerStatuses: [{
          ready: true,
          restartCount: 0,
          imageID: `docker-pullable://registry.ynxweb4.com/security/quant-worker@sha256:${quantDigest}`,
        }],
      },
    })),
  };
}

function ingress() {
  return {
    metadata: {
      annotations: {
        "cert-manager.io/cluster-issuer": "letsencrypt-production",
        "nginx.ingress.kubernetes.io/ssl-redirect": "true",
        "nginx.ingress.kubernetes.io/enable-modsecurity": "true",
      },
    },
    spec: {
      ingressClassName: "nginx",
      tls: [{ hosts: probePolicy().tlsHosts, secretName: "ynx-tls-cert" }],
    },
  };
}

function fixture({
  existingProduction = false,
  publicIdentityFails = false,
} = {}) {
  const calls = [];
  const execFile = (command, args, options = {}) => {
    calls.push({ command, args, input: options.input });
    if (command === "kubectl") {
      if (args[0] === "config") return `${context}\n`;
      if (args.includes("kube-system")) return JSON.stringify({ metadata: { uid: clusterUid } });
      if (args.includes("version")) return JSON.stringify({ serverVersion: { gitVersion: "v1.33.1" } });
      if (
        args.includes("get")
        && args.includes("deployment")
        && args.includes("quant-worker")
        && args.includes("--ignore-not-found=true")
      ) {
        return existingProduction ? JSON.stringify(deploymentList().items[0]) : "";
      }
      if (args.includes("--dry-run=server")) return "production dry-run passed";
      if (args.includes("apply")) return "production resources applied";
      if (args.includes("diff")) return "";
      if (args.includes("rollout")) return "production rollout complete";
      if (args.includes("namespace") && args.includes("ynx-services")) {
        return JSON.stringify({ metadata: { labels: { environment: "production" } } });
      }
      if (args.includes("deployment")) return JSON.stringify(deploymentList());
      if (args.includes("pods")) return JSON.stringify(pods());
      if (args.includes("networkpolicy")) {
        return JSON.stringify({ items: [{ metadata: { name: "default-deny-all" } }] });
      }
      if (args.includes("peerauthentication")) {
        return JSON.stringify({ items: [{ spec: { mtls: { mode: "STRICT" } } }] });
      }
      if (args.includes("cronjob")) {
        return JSON.stringify({
          items: [{
            metadata: { labels: { "security.ynx/source-commit": sourceCommit } },
            spec: { suspend: false },
          }],
        });
      }
      if (args.includes("secretproviderclass")) {
        return JSON.stringify({ items: [{ metadata: { name: "ynx-production-secrets" } }] });
      }
      if (args.includes("ingress")) return JSON.stringify(ingress());
      if (args.includes("resourcequota")) {
        return JSON.stringify({ spec: { hard: { pods: "50", "services.loadbalancers": "3" } } });
      }
      if (args.includes("hpa")) return JSON.stringify({ spec: { minReplicas: 3, maxReplicas: 10 } });
      if (args.includes("configmap")) {
        return JSON.stringify({
          data: {
            "enable-modsecurity": "true",
            "enable-owasp-modsecurity-crs": "true",
          },
        });
      }
      if (args.includes("secret") && args.some((value) => value.startsWith("jsonpath="))) {
        return "kubernetes.io/tls";
      }
      throw new Error(`unexpected kubectl command: ${args.join(" ")}`);
    }
    if (command === "curl") {
      if (args.includes("--write-out")) return "200|0|203.0.113.10";
      const url = args.at(-1);
      if (url.endsWith("/health")) {
        return JSON.stringify({
          status: "ok",
          environment: "production",
          source: new URL(url).hostname.split(".")[0] === "ai" ? "ai-gateway"
            : new URL(url).hostname.split(".")[0] === "web4" ? "web4-hub"
              : new URL(url).hostname.split(".")[0],
          sourceCommit: publicIdentityFails ? "wrong" : sourceCommit,
          version,
          asOf: "2026-07-26T17:00:00.000Z",
        });
      }
      if (url.endsWith("/version")) {
        return JSON.stringify({
          environment: "production",
          source: new URL(url).hostname.split(".")[0] === "ai" ? "ai-gateway"
            : new URL(url).hostname.split(".")[0] === "web4" ? "web4-hub"
              : new URL(url).hostname.split(".")[0],
          sourceCommit,
          version,
          asOf: "2026-07-26T17:00:00.000Z",
        });
      }
    }
    throw new Error(`unexpected command: ${command} ${args.join(" ")}`);
  };
  return { calls, execFile };
}

function evidencePath(name) {
  return `evidence/security-platform/.production-deploy-${process.pid}-${name}.json`;
}

test("production preflight binds signed release, cluster identity, and server dry-run", () => {
  const cluster = fixture();
  const verified = [];
  const result = preflightProductionDeployment({
    context,
    expectedClusterUid: clusterUid,
    execFile: cluster.execFile,
    verifyRelease: (options) => {
      verified.push(options);
      return releaseBundle();
    },
    now: new Date("2026-07-26T17:00:00.000Z"),
  });
  assert.equal(result.receipt.action, "production-deployment-preflight");
  assert.equal(result.receipt.productionSigned, true);
  assert.equal(result.receipt.serverDryRunPassed, true);
  assert.equal(result.receipt.mutationPerformed, false);
  assert.equal(result.receipt.deployedPublic, false);
  assert.equal(verified.length, 1);
  const dryRun = cluster.calls.find((call) => call.args.includes("--dry-run=server"));
  assert.ok(dryRun);
  assert.match(dryRun.input, /kind: Deployment/);
});

test("initial deployment runtime rejects an existing production release before dry-run", () => {
  const cluster = fixture({ existingProduction: true });
  assert.throws(
    () => preflightProductionDeployment({
      context,
      expectedClusterUid: clusterUid,
      execFile: cluster.execFile,
      verifyRelease: () => releaseBundle(),
      now: new Date("2026-07-26T17:00:00.000Z"),
    }),
    /blue-green update runtime/,
  );
  assert.equal(cluster.calls.some((call) => call.args.includes("--dry-run=server")), false);
});

test("production deploy sets public truth only after live controls and HTTPS probes", () => {
  const cluster = fixture();
  const path = evidencePath("success");
  try {
    const result = deployProduction({
      context,
      expectedClusterUid: clusterUid,
      operatorId: "production-operator",
      changeId: "change-20260726-production",
      acknowledge: "apply-production-release",
      evidencePath: path,
      rolloutTimeoutSeconds: 600,
      execFile: cluster.execFile,
      verifyRelease: () => releaseBundle(),
      now: (() => {
        const values = [
          new Date("2026-07-26T17:00:00.000Z"),
          new Date("2026-07-26T17:05:00.000Z"),
          new Date("2026-07-26T17:06:00.000Z"),
        ];
        return () => values.shift();
      })(),
    });
    assert.equal(result.state, "deployed-public-verified");
    assert.equal(result.productionSigned, true);
    assert.equal(result.deployedPublic, true);
    assert.equal(result.mutationPerformed, true);
    assert.equal(result.readiness.pass, true);
    assert.equal(result.publicProbes.tls.length, 8);
    assert.equal(result.publicProbes.services.length, 4);
    assert.deepEqual(JSON.parse(readFileSync(resolve(root, path), "utf8")), result);
    const mutationCalls = cluster.calls.filter((call) => (
      call.args.includes("apply") && !call.args.includes("--dry-run=server")
    ));
    assert.equal(mutationCalls.length, 1);
    assert.equal(cluster.calls.some((call) => call.args.includes("--force-conflicts")), false);
    assert.equal(cluster.calls.some((call) => call.args.includes("delete")), false);
  } finally {
    rmSync(resolve(root, path), { force: true });
  }
});

test("public identity failure records applied but not publicly verified truth", () => {
  const cluster = fixture({ publicIdentityFails: true });
  const path = evidencePath("probe-failure");
  try {
    assert.throws(
      () => deployProduction({
        context,
        expectedClusterUid: clusterUid,
        operatorId: "production-operator",
        changeId: "change-20260726-production-failure",
        acknowledge: "apply-production-release",
        evidencePath: path,
        execFile: cluster.execFile,
        verifyRelease: () => releaseBundle(),
        now: (() => {
          const values = [
            new Date("2026-07-26T17:00:00.000Z"),
            new Date("2026-07-26T17:00:30.000Z"),
            new Date("2026-07-26T17:01:00.000Z"),
          ];
          return () => values.shift();
        })(),
      }),
      /public response identity failed/,
    );
    const result = JSON.parse(readFileSync(resolve(root, path), "utf8"));
    assert.equal(result.state, "apply-completed-verification-failed");
    assert.equal(result.productionSigned, true);
    assert.equal(result.mutationPerformed, true);
    assert.equal(result.deployedPublic, false);
  } finally {
    rmSync(resolve(root, path), { force: true });
  }
});

test("production mutation requires exact acknowledgement and a bounded evidence path", () => {
  const cluster = fixture();
  assert.throws(
    () => deployProduction({
      context,
      expectedClusterUid: clusterUid,
      operatorId: "production-operator",
      changeId: "change-20260726-production",
      acknowledge: "apply-staging",
      evidencePath: evidencePath("ack"),
      execFile: cluster.execFile,
      verifyRelease: () => releaseBundle(),
    }),
    /acknowledge=apply-production-release/,
  );
  assert.equal(cluster.calls.length, 0);
  assert.throws(
    () => deployProduction({
      context,
      expectedClusterUid: clusterUid,
      operatorId: "production-operator",
      changeId: "change-20260726-production",
      acknowledge: "apply-production-release",
      evidencePath: "../outside.json",
      execFile: cluster.execFile,
      verifyRelease: () => releaseBundle(),
    }),
    /must stay inside/,
  );
  assert.equal(cluster.calls.length, 0);
});
