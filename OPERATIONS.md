# Security Platform Operations

## Promotion

Build in an unprivileged isolated worker, generate SBOM and provenance, scan dependencies/container/artifact, reproduce the build, and register its digest. A separate authorized deploy identity verifies policy and signature before canary or blue-green promotion. Rollback targets an already verified immutable digest.

## Secret rotation

Inventory metadata identifies owner, manager reference, expiry, runbook, and last drill evidence. Create a new version in the manager, narrow access, deploy consumers, verify dual-read only when supported, revoke the old version, and attach audit evidence. Never print values. Emergency rotation also invalidates sessions or artifacts derived from the credential.

## Break-glass

Require an incident ID, two independent approvers, exact scope, reason, expiry under one hour, and an isolated operator identity. Alert immediately. Record commands and results without secrets. Revoke at expiry or earlier, rotate touched credentials, and review within one business day.

## Backup and restore drill

Quiesce or use an atomic snapshot mechanism; export database, object, chain/config, and release metadata; encrypt before leaving the workload boundary; create hashes and object counts; copy to immutable/offline and cross-region storage. Restore into an isolated environment, verify hashes and application invariants, run smoke tests, record achieved RPO/RTO, and destroy drill credentials. Signer recovery is a separate multi-party ceremony.

## Incident sequence

Declare severity and incident commander; preserve evidence; contain with the least destructive action; communicate confirmed facts and uncertainty; eradicate; recover through verified artifacts and backups; monitor; notify affected users when required; publish a redacted postmortem with actions, owners, and dates.

Required exercises are credential compromise, compromised service, artifact tamper, DDoS, region failure, database loss, object loss, CI supply-chain failure, backup restore, rollback, accidental production noindex, quant-worker escape attempt, and public security evidence generation.
