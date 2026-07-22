# Evidence Index

- Policy: `security-platform/platform-policy.json`
- Release truth: `release/platform-status.json`
- Artifact registry: `release/artifact-registry.json`
- Secret inventory metadata: `security-platform/secret-inventory.json`
- Policy engine: `scripts/security-platform.mjs`
- Policy regression tests: `scripts/security-platform.test.mjs`
- CI enforcement: `.github/workflows/ci.yml`
- Security boundaries: `THREAT_MODEL.md`
- Operations and drills: `OPERATIONS.md`
- Monitoring contract: `OBSERVABILITY.md`
- Migration contract: `MIGRATION_COMPATIBILITY.md`
- Capacity and SLO contract: `SLO_CAPACITY_PLAN.md`
- Cost model: `UNIT_ECONOMICS.md`
- Current feature truth: `FEATURE_COMPLETION_EVIDENCE.md`
- Public testnet audit: `evidence/security-platform/PUBLIC_GATE_2026-07-22.md`
- Local verification: `evidence/security-platform/LOCAL_VERIFICATION_2026-07-22.md`
- Artifact and restore drill: `evidence/security-platform/ARTIFACT_AND_RESTORE_DRILL_2026-07-22.md`
- Dependency remediation: `evidence/security-platform/DEPENDENCY_REMEDIATION_2026-07-22.md`

Generated test logs must be stored under `evidence/security-platform/<source-commit>/` with UTC time, command, environment, exit status, and tool versions. Public evidence must not expose local paths, internal hosts, credentials, or private operational details.
