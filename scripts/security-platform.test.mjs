import test from "node:test";
import assert from "node:assert/strict";
import { verifyArtifactRegistry, verifyProductRelease, verifySecretInventory, verifyTruthRecord } from "./security-platform.mjs";

const policy = {
  requiredTruthStates: ["implementedLocal", "deployedPublic"],
  artifactKinds: ["container"],
  signingClasses: ["test-signed"],
  secretClasses: ["deploy"],
};

test("a true release state fails closed without evidence", () => {
  const errors = verifyTruthRecord(policy, {
    sourceCommit: "a".repeat(40),
    states: { implementedLocal: true, deployedPublic: false },
    evidence: {},
  });
  assert.deepEqual(errors, ["truth state implementedLocal=true requires evidence"]);
});

test("false release states remain honest without evidence", () => {
  const errors = verifyTruthRecord(policy, {
    sourceCommit: "a".repeat(40),
    states: { implementedLocal: false, deployedPublic: false },
    evidence: {},
  });
  assert.deepEqual(errors, []);
});

test("artifact records require release and verification fields", () => {
  const errors = verifyArtifactRegistry(policy, { artifacts: [{ id: "gateway", kind: "container" }] });
  assert.ok(errors.some((error) => error.includes("invalid sourceCommit")));
  assert.ok(errors.some((error) => error.includes("missing sbom")));
  assert.ok(errors.some((error) => error.includes("invalid signingClass")));
});

test("signed artifact records require detached signature inputs", () => {
  const errors = verifyArtifactRegistry(policy, { artifacts: [{
    id: "signed-gateway", kind: "container", sourceCommit: "a".repeat(40), sha256: "b".repeat(64), bytes: 1,
    signingClass: "test-signed", buildRun: "run", sbom: "sbom", minimumOs: "linux", installEvidence: "evidence",
    revocation: "runbook", expiry: "2026-08-01T00:00:00Z",
  }] });
  assert.ok(errors.some((error) => error.includes("signed artifact missing manifest")));
  assert.ok(errors.some((error) => error.includes("signed artifact missing signature")));
  assert.ok(errors.some((error) => error.includes("signed artifact missing publicKey")));
});

test("secret inventory rejects value-bearing fields", () => {
  const errors = verifySecretInventory(policy, {
    secrets: [{
      id: "deploy-key",
      class: "deploy",
      owner: "release engineering",
      managerReference: "secret-manager://deploy/key",
      expiresAt: "2026-08-01T00:00:00Z",
      rotationRunbook: "OPERATIONS.md#rotation",
      lastRotationEvidence: "evidence/rotation.json",
      secretValue: "must-not-appear",
    }],
  });
  assert.ok(errors.some((error) => error.includes("forbidden value-bearing field")));
});

test("release records cannot select revoked artifacts", () => {
  const errors = verifyProductRelease({
    sourceCommit: "a".repeat(40), artifacts: ["old"], productionSigned: false, deployedPublic: false,
  }, { artifacts: [{ id: "old", sourceCommit: "a".repeat(40), revokedAt: "2026-07-22T00:00:00Z", publicReleaseEligible: false }] });
  assert.deepEqual(errors, ["release references revoked artifact old"]);
});

test("production release claims require production signatures and release time", () => {
  const errors = verifyProductRelease({
    sourceCommit: "a".repeat(40), artifacts: ["candidate"], productionSigned: true, deployedPublic: true, releasedAt: null,
  }, { artifacts: [{ id: "candidate", sourceCommit: "a".repeat(40), signingClass: "test-signed", publicReleaseEligible: false }] });
  assert.ok(errors.includes("productionSigned=true requires only production-signed artifacts"));
  assert.ok(errors.includes("deployedPublic=true requires releasedAt"));
});
