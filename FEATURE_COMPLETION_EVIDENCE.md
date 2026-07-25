# Feature Completion Evidence

| Capability | Current state | Direct evidence | Missing proof |
| --- | --- | --- | --- |
| release truth model | implemented and tested locally | `release/platform-status.json`; commits `58fe6796593a7cedaee01d88e1b534f0e70c4d6a` and `0cb9b5891cdcf74ce3e4c727470dcb0b60a8933c` | central merge and remote CI acceptance |
| artifact registry contract | tested locally | `release/artifact-registry.json`; cryptographically verified test-signed source artifact | current-commit artifact build, independent CI verification, and approved production signer |
| sensitive-material metadata contract | implemented locally; inventory not configured | `security-platform/secret-inventory.json`; `security-platform/secret-inventory.schema.json`; validator tests | production manager, named owners, environment bindings, rotation and recovery evidence |
| Service Identity policy | tested locally | `security-platform/service-identity-policy.json`; `scripts/security-service-identity.test.mjs`; 33-test security suite | central workload identity provider and product-owner acceptance |
| local mTLS handshake and rejection | tested locally | `evidence/security-platform/LOCAL_MTLS_DRILL_0cb9b58.json`; source commit `0cb9b5891cdcf74ce3e4c727470dcb0b60a8933c` | production CA, external revocation, real service deployment and certificate rotation |
| tracked sensitive-material gate | tested locally | `scripts/security-platform.mjs`; `evidence/security-platform/LOCAL_VERIFICATION_2026-07-22.md` | remote CI run on the latest pushed commit |
| CI validation gates | implemented locally | `.github/workflows/security-platform-deploy.yml`; `scripts/security-ci-policy.mjs` | successful remote workflow run and protected-branch enforcement evidence |
| branch ownership | implemented locally | `.github/CODEOWNERS` | protected branch settings and required-review evidence from GitHub |
| Kubernetes deployment candidates | rendered and policy-tested locally | `scripts/security-integration.mjs`; `infra/k8s/base`; staging and production-candidate overlays | cluster admission, runtime health, storage, identity, deployment approval and rollback evidence |
| encrypted backup and restore | local component drill passed | `evidence/security-platform/LOCAL_RESTORE_DRILL_58fe679.json`; source commit `58fe6796593a7cedaee01d88e1b534f0e70c4d6a` | atomic full-service, immutable/offline, point-in-time and cross-region drills |
| central integration | not accepted | `release/integration/security-platform-contract.json`; `docs/integration/DEPENDENCY_ACCEPTANCE.md` | owner handoffs, Product 29 freeze and shared Testnet evidence |
| public deployment | contradicted/not proven | `evidence/security-platform/PUBLIC_GATE_2026-07-22.md`; `release/platform-status.json` | deployed services, public health/version/security/status endpoints and URL evidence |
| production signing | not proven | `release/platform-status.json` | approved signer, production signature, certificate chain, timestamp and independent verification |

No row may be promoted based only on prose or file existence. Evidence must name the exact source commit and execution environment. Local ephemeral-CA, test-signing, render-only, Sandbox, Testnet and unsigned results must not be represented as production deployment or production signing.
