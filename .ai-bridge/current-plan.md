# YNX 30 Current Plan

Status: ACTIVE
Phase: PROTECT
Recovery source commit: `8577f8a6086946297faddf1ffc7e04ca8359af05`
Updated: 2026-07-27T14:58:39Z

## Current objective

Close the highest-risk release blockers without overstating external state:

1. Commit and push the verified cross-platform lifecycle-script audit fix.
2. Require both GitHub security workflows to pass at the new exact SHA.
3. Rebuild the clean-source artifact, SBOM, provenance, manifest, hash and test-signing evidence for the accepted source commit.
4. Rebind `release/platform-status.json`, `release/product-release.json`, `release/artifact-registry.json`, `public-product-metadata.json`, integration evidence and completion evidence to the actual release source.
5. Verify installation and cold start in a clean local environment.
6. Advance in order through FREEZE, INTEGRATE, TESTNET and PUBLIC only when direct evidence permits.

## Immediate next action

Commit and push the reviewed fix, verify Local SHA equals Remote SHA, and inspect both workflows at that exact commit. Do not request operator secrets or mutate a cluster.
