# YNX ARES Hybrid Cryptographic Protocol

Status: Active design baseline
Last updated: 2026-04-30
Canonical language: English

## 1. Name

`YNX ARES` means `YNX Aegis Recursive Envelope Suite`.

ARES is a YNX-specific protocol profile for high-assurance Web4 actions. It is not a new signature algorithm, hash function, KEM, cipher, or RNG. The safe innovation is the composition: hybrid classical + post-quantum credentials, strict domain separation, recursive action envelopes, short-lived sessions, and fail-closed policy verification.

## 2. Design Goal

ARES is designed to make privileged YNX actions resilient against:

- classical key theft and remote compromise;
- future quantum attacks against classical public-key signatures and key exchange;
- replay attacks across chains, apps, policies, or sessions;
- unauthorized AI-agent delegation;
- silent policy mutation and privilege expansion;
- long-lived key exposure.

ARES intentionally keeps the base chain compatible with current EVM/Cosmos tooling while adding stronger verification at the Web4 protocol and governance layers.

## 3. Primitive Set

Default profile:

- Hashing: `SHA3-256` or `BLAKE3` with explicit domain separation.
- Classical account signatures: `secp256k1` for EVM-compatible accounts.
- Classical consensus / service signatures: Ed25519 where required by existing stack compatibility.
- Post-quantum signatures: `ML-DSA-65`.
- Long-lived emergency anchors: `SLH-DSA` for high-value root recovery, where signature size is acceptable.
- Key establishment: hybrid classical ECDH/X25519 plus `ML-KEM-768`.
- Symmetric encryption: `AES-256-GCM` or `XChaCha20-Poly1305` from audited libraries.
- Key derivation: `HKDF-SHA3-256` with chain/app/policy/session labels.

No custom primitive is allowed in ARES v1.

## 4. ARES Envelope

Every protected action is wrapped in an envelope:

```text
ARES_Envelope {
  version
  chain_id
  app_id
  account
  policy_id
  session_id
  capability_set
  nonce
  issued_at
  expires_at
  previous_envelope_hash
  payload_hash
  classical_pubkey_ref
  pq_pubkey_ref
  classical_signature
  pq_signature
}
```

The signing message is:

```text
digest = H(
  "YNX-ARES-v1" ||
  chain_id ||
  app_id ||
  account ||
  policy_id ||
  session_id ||
  capability_set ||
  nonce ||
  issued_at ||
  expires_at ||
  previous_envelope_hash ||
  payload_hash ||
  classical_pubkey_ref ||
  pq_pubkey_ref
)
```

The envelope hash is:

```text
envelope_hash = H("YNX-ARES-envelope-hash-v1" || canonical_envelope_without_signatures || classical_signature || pq_signature)
```

## 5. Verification Rule

For high-value actions, verification is strict:

```text
verify_ares(envelope, payload, policy):
  require envelope.version is supported
  require envelope.chain_id matches local chain
  require envelope.app_id matches local app
  require now <= envelope.expires_at
  require nonce has not been used for account + policy + session
  require H(payload) == envelope.payload_hash
  require policy authorizes envelope.capability_set
  require previous_envelope_hash matches policy/session chain when required
  require VerifyClassical(envelope.classical_pubkey_ref, digest, classical_signature)
  require VerifyPQ(envelope.pq_pubkey_ref, digest, pq_signature)
  accept only if all checks pass
```

For backwards-compatible rollout, YNX can run in observe mode:

- classical signature remains mandatory;
- PQ signature is recorded and monitored;
- high-value mainnet gates stay disabled until PQ verification libraries, wallets, and audit coverage are ready.

## 6. Recursive Security

ARES is recursive because every privileged action can bind to the previous envelope hash. This creates a tamper-evident chain of intent:

- root owner creates policy envelope;
- policy creates session envelope;
- session creates agent-action envelope;
- each child envelope references the parent or previous authorized envelope;
- revocation cuts off all dependent sessions.

This does not replace blockchain consensus. It protects off-chain and application-layer authority before it reaches the chain.

## 7. Quantum Security Position

ARES addresses the two practical quantum concerns:

- Shor-class risk against classical public-key cryptography is mitigated by adding `ML-DSA` signatures and `ML-KEM` key establishment.
- Grover-class risk against symmetric keys is addressed by requiring 256-bit symmetric security for high-assurance profiles.

ARES does not claim immunity against implementation bugs, compromised endpoints, malicious insiders, side channels, or broken libraries. Those are controlled through audits, key isolation, least privilege, logging, and incident response.

## 8. Activation Plan

1. Document the profile and threat model.
2. Add SDK-level envelope generation and verification.
3. Add on-chain or precompile-backed credential registry.
4. Enable observe mode on public testnet.
5. Audit ARES libraries and the registry.
6. Require dual signatures for governance, treasury, upgrade, bridge, and root policy actions.
7. Expand enforcement to high-value Web4 agent actions.

Current implementation anchor:

- `packages/sdk/src/ares.ts` provides canonical payload hashing, ARES digest construction, envelope hashing, EVM-compatible classical signing/recovery, strict mode, observe mode, nonce replay hooks, policy checks, and pluggable post-quantum verification callbacks.
- `packages/sdk/test/ares.test.ts` verifies strict hybrid mode, observe mode, payload-mutation rejection, nonce-replay rejection, and canonical JSON hashing.
- Real `ML-DSA` / `SLH-DSA` providers must be supplied through audited libraries before strict mainnet enforcement.

## 9. Non-Goals

ARES v1 does not:

- replace CometBFT consensus signatures on the live testnet;
- create a proprietary cryptographic primitive;
- custody user assets;
- turn YNX into an exchange, bank, stablecoin issuer, or KYC provider;
- guarantee token price or investment return.
