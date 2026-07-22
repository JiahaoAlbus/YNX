import test from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { cycloneDxFromLock, provenanceFor, signManifest, verifyManifestSignature } from "./security-artifact.mjs";

test("CycloneDX output is deterministic and sorted", () => {
  const commit = "a".repeat(40);
  const sbom = cycloneDxFromLock({ packages: {
    "node_modules/z": { name: "z", version: "1.0.0" },
    "node_modules/a": { name: "a", version: "2.0.0" },
  } }, commit);
  assert.equal(sbom.bomFormat, "CycloneDX");
  assert.deepEqual(sbom.components.map((item) => item.name), ["a", "z"]);
  assert.equal(sbom.metadata.properties[0].value, commit);
});

test("provenance refuses to imply signing or public release", () => {
  const provenance = provenanceFor({
    sourceCommit: "b".repeat(40), artifactName: "bundle.tar", digest: "c".repeat(64), bytes: 10,
    sbomName: "bundle.cdx.json", sbomDigest: "d".repeat(64),
  });
  assert.equal(provenance.predicate.ynxRelease.signingClass, "unsigned-local");
  assert.equal(provenance.predicate.ynxRelease.publicReleaseEligible, false);
});

test("Ed25519 manifest signature verifies and tampering fails", () => {
  const root = mkdtempSync(join(tmpdir(), "ynx-artifact-sign-"));
  const manifestPath = join(root, "manifest.json");
  const privateKeyPath = join(root, "private.pem");
  const publicKeyPath = join(root, "public.pem");
  const signaturePath = join(root, "manifest.sig.json");
  const { privateKey, publicKey } = generateKeyPairSync("ed25519");
  writeFileSync(manifestPath, "{\"sha256\":\"trusted\"}\n");
  writeFileSync(privateKeyPath, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600 });
  writeFileSync(publicKeyPath, publicKey.export({ type: "spki", format: "pem" }));
  const signature = signManifest({ manifestPath, privateKeyPath, signaturePath });
  assert.equal(signature.signingClass, "test-signed");
  assert.equal(verifyManifestSignature({ manifestPath, signaturePath, publicKeyPath }).verified, true);
  writeFileSync(manifestPath, "{\"sha256\":\"tampered\"}\n");
  assert.throws(() => verifyManifestSignature({ manifestPath, signaturePath, publicKeyPath }), /digest mismatch/);
});

test("production signing fails without explicit approval", () => {
  assert.throws(() => signManifest({ manifestPath: "missing", privateKeyPath: "missing", signaturePath: "missing", signingClass: "production-signed" }), /explicit operator approval/);
});
