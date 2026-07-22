#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { createHash, createPrivateKey, createPublicKey, sign, verify } from "node:crypto";
import { mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(fileURLToPath(new URL("..", import.meta.url)));
const bundlePaths = [
  ".github/CODEOWNERS",
  ".github/dependabot.yml",
  ".github/workflows/ci.yml",
  ".github/workflows/security.yml",
  "EVIDENCE_INDEX.md",
  "FEATURE_COMPLETION_EVIDENCE.md",
  "MIGRATION_COMPATIBILITY.md",
  "OBSERVABILITY.md",
  "OPERATIONS.md",
  "SLO_CAPACITY_PLAN.md",
  "THREAT_MODEL.md",
  "UNIT_ECONOMICS.md",
  "package-lock.json",
  "package.json",
  "release",
  "security-platform",
  "scripts/security-artifact.mjs",
  "scripts/security-artifact.test.mjs",
  "scripts/security-backup.mjs",
  "scripts/security-backup.test.mjs",
  "scripts/security-build-script-audit.mjs",
  "scripts/security-platform.mjs",
  "scripts/security-platform.test.mjs",
];

function sha256(data) {
  return createHash("sha256").update(data).digest("hex");
}

export function cycloneDxFromLock(lock, sourceCommit) {
  const components = [];
  for (const [path, value] of Object.entries(lock.packages ?? {})) {
    if (!path || !value?.version) continue;
    const inferredName = path.match(/(?:^|\/)node_modules\/((?:@[^/]+\/)?[^/]+)$/)?.[1] ?? "";
    const name = value.name || inferredName;
    if (!name) continue;
    components.push({
      type: "library",
      name,
      version: value.version,
      purl: `pkg:npm/${encodeURIComponent(name)}@${value.version}`,
      properties: [{ name: "ynx:lockPath", value: path }],
    });
  }
  components.sort((a, b) => a.purl.localeCompare(b.purl));
  return {
    bomFormat: "CycloneDX",
    specVersion: "1.6",
    serialNumber: `urn:uuid:${sourceCommit.slice(0, 8)}-${sourceCommit.slice(8, 12)}-4${sourceCommit.slice(13, 16)}-a${sourceCommit.slice(17, 20)}-${sourceCommit.slice(20, 32)}`,
    version: 1,
    metadata: {
      component: { type: "application", name: "ynx-security-platform", version: sourceCommit },
      properties: [{ name: "ynx:sourceCommit", value: sourceCommit }],
    },
    components,
  };
}

export function provenanceFor({ sourceCommit, artifactName, digest, bytes, sbomName, sbomDigest }) {
  return {
    _type: "https://in-toto.io/Statement/v1",
    subject: [{ name: artifactName, digest: { sha256: digest } }],
    predicateType: "https://slsa.dev/provenance/v1",
    predicate: {
      buildDefinition: {
        buildType: "https://ynxweb4.com/security-platform/reproducible-git-archive/v1",
        externalParameters: { sourceCommit, paths: bundlePaths },
        internalParameters: {},
        resolvedDependencies: [{ uri: "git+https://github.com/JiahaoAlbus/YNX.git", digest: { gitCommit: sourceCommit } }],
      },
      runDetails: {
        builder: { id: "https://github.com/JiahaoAlbus/YNX/.github/workflows/ci.yml" },
        metadata: { invocationId: `local:${sourceCommit}`, startedOn: null, finishedOn: null },
        byproducts: [{ name: sbomName, digest: { sha256: sbomDigest } }],
      },
      ynxRelease: { bytes, signingClass: "unsigned-local", publicReleaseEligible: false },
    },
  };
}

export function signManifest({ manifestPath, privateKeyPath, signaturePath, signingClass = "test-signed", productionApproved = false }) {
  if (!new Set(["test-signed", "production-signed"]).has(signingClass)) throw new Error("signing class must be test-signed or production-signed");
  if (signingClass === "production-signed" && !productionApproved) throw new Error("production signing requires explicit operator approval");
  const manifest = readFileSync(manifestPath);
  const privateKey = createPrivateKey(readFileSync(privateKeyPath));
  if (privateKey.asymmetricKeyType !== "ed25519") throw new Error("artifact signing key must be Ed25519");
  const publicKey = createPublicKey(privateKey);
  const publicDer = publicKey.export({ type: "spki", format: "der" });
  const record = {
    schemaVersion: 1,
    algorithm: "Ed25519",
    signingClass,
    manifestSha256: sha256(manifest),
    publicKeyFingerprint: `sha256:${sha256(publicDer)}`,
    signature: sign(null, manifest, privateKey).toString("base64"),
  };
  writeFileSync(signaturePath, `${JSON.stringify(record, null, 2)}\n`);
  return record;
}

export function verifyManifestSignature({ manifestPath, signaturePath, publicKeyPath }) {
  const manifest = readFileSync(manifestPath);
  const record = JSON.parse(readFileSync(signaturePath, "utf8"));
  const publicKey = createPublicKey(readFileSync(publicKeyPath));
  const publicDer = publicKey.export({ type: "spki", format: "der" });
  if (record.algorithm !== "Ed25519") throw new Error("unsupported artifact signature algorithm");
  if (record.manifestSha256 !== sha256(manifest)) throw new Error("signed manifest digest mismatch");
  if (record.publicKeyFingerprint !== `sha256:${sha256(publicDer)}`) throw new Error("artifact signer fingerprint mismatch");
  if (!verify(null, manifest, publicKey, Buffer.from(record.signature, "base64"))) throw new Error("artifact signature verification failed");
  return { verified: true, signingClass: record.signingClass, publicKeyFingerprint: record.publicKeyFingerprint };
}

export function build(outputDir = resolve(root, "dist/security-platform")) {
  const sourceCommit = execFileSync("git", ["rev-parse", "HEAD"], { cwd: root, encoding: "utf8" }).trim();
  mkdirSync(outputDir, { recursive: true });
  const artifactName = `ynx-security-platform-${sourceCommit}.tar`;
  const artifactPath = resolve(outputDir, artifactName);
  execFileSync("git", ["archive", "--format=tar", `--output=${artifactPath}`, sourceCommit, ...bundlePaths], { cwd: root });
  const artifact = readFileSync(artifactPath);
  const lock = JSON.parse(readFileSync(resolve(root, "package-lock.json"), "utf8"));
  const sbom = cycloneDxFromLock(lock, sourceCommit);
  const sbomName = `${artifactName}.cdx.json`;
  const sbomPath = resolve(outputDir, sbomName);
  writeFileSync(sbomPath, `${JSON.stringify(sbom, null, 2)}\n`);
  const sbomDigest = sha256(readFileSync(sbomPath));
  const provenance = provenanceFor({
    sourceCommit,
    artifactName,
    digest: sha256(artifact),
    bytes: statSync(artifactPath).size,
    sbomName,
    sbomDigest,
  });
  const provenancePath = resolve(outputDir, `${artifactName}.intoto.json`);
  writeFileSync(provenancePath, `${JSON.stringify(provenance, null, 2)}\n`);
  const manifest = {
    schemaVersion: 1,
    artifact: artifactName,
    sourceCommit,
    sha256: sha256(artifact),
    bytes: statSync(artifactPath).size,
    sbom: { path: basename(sbomPath), sha256: sbomDigest },
    provenance: { path: basename(provenancePath), sha256: sha256(readFileSync(provenancePath)) },
    signingClass: "unsigned-local",
    publicReleaseEligible: false,
  };
  writeFileSync(resolve(outputDir, `${artifactName}.manifest.json`), `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const command = process.argv[2];
  if (command === "build") {
    const manifest = build(process.argv[3] ? resolve(process.argv[3]) : undefined);
    process.stdout.write(`${JSON.stringify(manifest, null, 2)}\n`);
  } else if (command === "sign") {
    const signingClass = process.argv[6] || "test-signed";
    const record = signManifest({
      manifestPath: resolve(process.argv[3]), privateKeyPath: resolve(process.argv[4]), signaturePath: resolve(process.argv[5]), signingClass,
      productionApproved: process.env.YNX_PRODUCTION_SIGNING_APPROVED === "1",
    });
    process.stdout.write(`${JSON.stringify({ ...record, signature: "redacted-from-console" }, null, 2)}\n`);
  } else if (command === "verify-signature") {
    const result = verifyManifestSignature({ manifestPath: resolve(process.argv[3]), signaturePath: resolve(process.argv[4]), publicKeyPath: resolve(process.argv[5]) });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else {
    process.stderr.write("usage: security-artifact.mjs build [dir] | sign MANIFEST PRIVATE_KEY SIGNATURE [CLASS] | verify-signature MANIFEST SIGNATURE PUBLIC_KEY\n");
    process.exitCode = 2;
  }
}
