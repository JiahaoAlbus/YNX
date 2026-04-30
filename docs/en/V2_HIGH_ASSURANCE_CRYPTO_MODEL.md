# YNX v2 High-Assurance Crypto and Post-Quantum Security Model

Status: Active design baseline
Last updated: 2026-04-30
Canonical language: English

## 1. Security Claim Boundary

YNX does not claim that any system can be mathematically guaranteed to be unbreakable forever. That claim would be false and would weaken the project.

The defensible target is:

- survive realistic nation-state attacker pressure through compartmentalization, key rotation, monitoring, and operational controls;
- stay compatible with current EVM/Cosmos tooling while preparing a post-quantum migration path;
- protect high-value Web4 actions with hybrid classical + post-quantum verification before mainnet;
- use standardized, audited cryptographic primitives rather than unaudited custom primitives;
- make every privileged mutation, delegation, and recovery path explicit and reviewable.

This model extends `docs/en/V2_SECURITY_MODEL.md`.

## 2. Standards Baseline

YNX high-assurance cryptography MUST track these public standards and references:

- NIST FIPS 203: `ML-KEM`, the standardized module-lattice key-encapsulation mechanism.
- NIST FIPS 204: `ML-DSA`, the standardized module-lattice digital-signature algorithm.
- NIST FIPS 205: `SLH-DSA`, the standardized stateless hash-based digital-signature algorithm.
- Apple PQ3 design pattern: hybrid post-quantum session establishment with cryptographic agility and continuous rekeying.
- Exchange-grade operational controls: hardware-backed signing, threshold approvals, least privilege, release attestation, tamper-evident logs, incident response, and independent audits.

YNX MUST NOT invent a new hash function, block cipher, signature scheme, KEM, RNG, or consensus-signing primitive without years of public cryptanalysis. The YNX-specific innovation is the protocol composition described in `docs/en/YNX_ARES_HYBRID_CRYPTO_PROTOCOL.md`.

## 3. Compatibility Layers

### Layer 0: Current Chain Compatibility

Current public-testnet compatibility remains:

- EVM accounts: `eth_secp256k1` / Ethereum-compatible signatures;
- CometBFT validator consensus keys: Ed25519 as required by the stack;
- TLS for public service ingress;
- operator SSH keys kept outside Git.

Layer 0 stays active until a safe migration path exists. Replacing consensus keys directly on the live public testnet is not allowed because it can break validator compatibility and chain liveness.

### Layer 1: High-Assurance Operations

Before mainnet candidate status:

- release builds MUST be reproducible or independently rebuildable;
- validator and deployer keys MUST use hardware-backed storage where possible;
- operator SSH access MUST use key-only login, disabled password login, and minimal sudo surface;
- privileged actions MUST require two-person review or threshold approval;
- production secrets MUST live outside the repository and outside public CI logs;
- every public service MUST have health checks, logs, restart policy, and alert routing;
- release artifacts MUST have checksums and signed provenance.

### Layer 2: Hybrid Web4 Action Security

High-value Web4 actions SHOULD require a hybrid envelope:

- classical signature: `secp256k1` or Ed25519, depending on the caller domain;
- post-quantum signature: `ML-DSA-65` for the default high-assurance profile;
- optional conservative fallback: `SLH-DSA` for emergency root recovery and long-lived policy anchors;
- domain-separated digest: chain ID, app ID, policy ID, session ID, nonce, expiry, capability set, and payload hash;
- fail-closed verification: both required signatures must verify for high-value actions once the feature is activated.

Layer 2 can be introduced at the application/protocol layer without breaking current EVM account compatibility.

### Layer 3: Post-Quantum Account Migration

Mainnet-era post-quantum readiness requires:

- a PQ credential registry for account owners, policies, validators, deployers, and AI agents;
- hybrid verification for governance, treasury, bridge, upgrade, and root policy actions;
- staged migration where legacy accounts can add PQ credentials before PQ enforcement;
- emergency rotation paths for compromised classical keys;
- a governance-controlled enforcement schedule with public testnet rehearsal.

## 4. Threat Model

YNX explicitly considers:

- remote attackers exploiting RPC, REST, EVM, faucet, indexer, explorer, AI, or gateway services;
- cloud operator compromise, leaked SSH keys, and leaked mnemonics;
- malicious validators, stalled validators, and equivocation attempts;
- supply-chain attacks against dependencies, build systems, deployment scripts, and release artifacts;
- long-term quantum risk against classical public-key algorithms;
- social engineering against deployers, governance operators, and validator operators.

YNX does not assume:

- an attacker can break well-implemented 256-bit symmetric encryption at practical cost;
- a secure hardware root remains secure after physical seizure without defense-in-depth;
- a single control can protect user assets or governance authority.

## 5. Mainnet Cryptographic Gates

YNX MUST NOT promote the public testnet to mainnet candidate until these are complete:

1. External audit of chain logic, deployment scripts, public endpoints, and privileged contracts.
2. Independent review of the YNX ARES hybrid envelope profile.
3. Reproducible release process with signed checksums and rollback plan.
4. Validator key ceremony and documented recovery procedure.
5. Governance, treasury, upgrade, and policy actions protected by multi-signature or threshold approval.
6. No placeholder secrets, test private keys, or default passwords in production configs.
7. Public bug bounty or coordinated vulnerability disclosure channel.
8. Incident-response runbook tested with at least one tabletop exercise.

## 6. Non-Custodial Boundary

High security does not require YNX to custody assets. The project-level boundary is:

- no user asset custody;
- no exchange matching engine;
- no stablecoin issuance or reserve management;
- no KYC business as a protocol operator;
- no promise that NYXT price appreciation is the business model.

The business and compliance boundary is defined in `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`.

## 7. Implementation Priority

Priority order:

1. protect operator keys and release pipeline immediately;
2. add hybrid-signature verification for Web4 policy/session/agent envelopes;
3. add PQ credential registry and SDK support;
4. rehearse migration on public testnet;
5. enforce hybrid verification only after ecosystem tooling and audits are ready.

Current SDK anchor: `packages/sdk/src/ares.ts` implements ARES envelope construction and verification with pluggable PQ verification. It is suitable for testnet observe mode and for auditor review, but strict mainnet mode still requires audited `ML-DSA` / `SLH-DSA` provider integration.

## 8. References

- NIST FIPS 203: `https://csrc.nist.gov/pubs/fips/203/final`
- NIST FIPS 204: `https://csrc.nist.gov/pubs/fips/204/final`
- NIST FIPS 205: `https://csrc.nist.gov/pubs/fips/205/final`
- Apple PQ3: `https://security.apple.com/blog/imessage-pq3/`
