# Artifact and Restore Drill — 2026-07-22

## Reproducible artifact

- Source commit: `e2c29248e8a10321cc42507c22e57a34d9746218`
- Artifact: `ynx-security-platform-e2c29248e8a10321cc42507c22e57a34d9746218.tar`
- Bytes: 61,440
- SHA-256, build one: `95156e936631602389b5b3e6de898d65b7e05a91c402bad1af2452fb19839a93`
- SHA-256, independent build two: `95156e936631602389b5b3e6de898d65b7e05a91c402bad1af2452fb19839a93`
- CycloneDX SBOM components: 377
- CycloneDX SBOM SHA-256, both builds: `85c94ee703c98efa2178060754f230bab6cdde2eb4dd8f8cf6f2af944d34a4b1`
- Provenance SHA-256, both builds: `9903281beb762080988f805dcc2b111ea42a1d2cc2f1e8756f73d0e12c1a1248`
- Signature: Ed25519 detached test signature, verified
- Test public-key fingerprint: `sha256:983e1156f1789cbbd9afeaffa8f102340be05c4473e07f40f41a57f7d24fe5b2`
- Signing class: `test-signed`
- Public release eligible: false

The ephemeral private key was created in a system temporary directory with owner-only permissions and was never copied into the repository. This drill does not support `productionSigned=true` or `downloadHosted=true`.

## Encrypted restore

- Source set: versioned security-platform policy and secret metadata files
- Algorithm: AES-256-GCM
- Encrypted backup SHA-256: `9e812690703e8eee9765b95ffe5b3b15344692fb4684a28fcc7c365559b7d7c1`
- Encrypted bytes: 3,018
- Files: 2
- Restore comparison: exact recursive diff passed
- Reported local duration: under one second
- Signer recovery included: false

The runtime key was held only in a system temporary directory and was not printed. This is a component-level local drill, not proof of an atomic production snapshot, immutable/offline storage, cross-region recovery, or the declared four-hour RTO and 24-hour RPO.
