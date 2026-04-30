import { createHash } from "node:crypto";
import { computeAddress, concat, getAddress, getBytes, hexlify, recoverAddress, SigningKey } from "ethers";

export const ARES_VERSION = "ynx-ares-v1";
const ARES_DIGEST_DOMAIN = "YNX-ARES-v1";
const ARES_ENVELOPE_HASH_DOMAIN = "YNX-ARES-envelope-hash-v1";

export type AresMode = "strict" | "observe";
export type AresClassicalScheme = "eth_secp256k1";
export type AresPqScheme = "ml-dsa-65" | "slh-dsa" | (string & {});

export type AresEnvelopeV1 = {
  version: typeof ARES_VERSION;
  chain_id: string;
  app_id: string;
  account: string;
  policy_id: string;
  session_id: string;
  capability_set: string[];
  nonce: string;
  issued_at: string;
  expires_at: string;
  previous_envelope_hash: string;
  payload_hash: string;
  classical_scheme: AresClassicalScheme;
  classical_pubkey_ref: string;
  pq_scheme: AresPqScheme;
  pq_pubkey_ref: string;
  classical_signature: string;
  pq_signature: string;
};

export type AresUnsignedEnvelopeV1 = Omit<AresEnvelopeV1, "classical_signature" | "pq_signature">;

export type CreateAresEnvelopeV1Input = {
  chainId: string;
  appId: string;
  account: string;
  policyId: string;
  sessionId: string;
  capabilitySet: string[];
  nonce: string;
  issuedAt: string | Date;
  expiresAt: string | Date;
  previousEnvelopeHash?: string;
  payload: unknown;
  classicalPrivateKey: string;
  pqPubkeyRef: string;
  pqScheme?: AresPqScheme;
  pqSigner?: (digest: string, unsignedEnvelope: AresUnsignedEnvelopeV1) => string | Promise<string>;
};

export type AresPolicyV1 = {
  chainId?: string;
  appId?: string;
  account?: string;
  policyId?: string;
  sessionId?: string;
  requiredCapabilities?: string[];
  expectedPreviousEnvelopeHash?: string;
};

export type VerifyAresEnvelopeV1Options = {
  mode?: AresMode;
  now?: Date;
  maxFutureSkewSec?: number;
  policy?: AresPolicyV1;
  usedNonce?: (nonceKey: string, envelope: AresEnvelopeV1) => boolean;
  pqVerifier?: (input: {
    digest: string;
    envelope: AresEnvelopeV1;
    signature: string;
    pubkeyRef: string;
    scheme: AresPqScheme;
  }) => boolean | Promise<boolean>;
};

export type VerifyAresEnvelopeV1Result = {
  ok: boolean;
  mode: AresMode;
  digest: string;
  envelopeHash: string;
  recoveredClassicalSigner?: string;
  pqVerified?: boolean;
  nonceKey?: string;
  reason?: string;
};

function normalizeIso(value: string | Date): string {
  const date = value instanceof Date ? value : new Date(value);
  const time = date.getTime();
  if (!Number.isFinite(time)) throw new Error(`Invalid timestamp: ${String(value)}`);
  return date.toISOString();
}

function normalizeHex32(value: string | undefined, fallback: string): string {
  const input = value && value.trim() ? value : fallback;
  const bytes = getBytes(input);
  if (bytes.length !== 32) throw new Error(`Invalid bytes32: ${input}`);
  return hexlify(bytes);
}

function sortedObject(value: unknown): unknown {
  if (Array.isArray(value)) return value.map((item) => sortedObject(item));
  if (!value || typeof value !== "object") return value;
  const out: Record<string, unknown> = {};
  for (const key of Object.keys(value as Record<string, unknown>).sort()) {
    const item = (value as Record<string, unknown>)[key];
    if (item !== undefined) out[key] = sortedObject(item);
  }
  return out;
}

export function canonicalJson(value: unknown): string {
  return JSON.stringify(sortedObject(value)) ?? "null";
}

function sha3Hex(value: string): string {
  return `0x${createHash("sha3-256").update(value).digest("hex")}`;
}

export function computeAresPayloadHash(payload: unknown): string {
  if (typeof payload === "string") return sha3Hex(payload);
  if (payload instanceof Uint8Array) return `0x${createHash("sha3-256").update(payload).digest("hex")}`;
  return sha3Hex(canonicalJson(payload));
}

function digestMaterial(envelope: AresUnsignedEnvelopeV1): string {
  return canonicalJson({
    domain: ARES_DIGEST_DOMAIN,
    version: envelope.version,
    chain_id: envelope.chain_id,
    app_id: envelope.app_id,
    account: envelope.account,
    policy_id: envelope.policy_id,
    session_id: envelope.session_id,
    capability_set: envelope.capability_set,
    nonce: envelope.nonce,
    issued_at: envelope.issued_at,
    expires_at: envelope.expires_at,
    previous_envelope_hash: envelope.previous_envelope_hash,
    payload_hash: envelope.payload_hash,
    classical_scheme: envelope.classical_scheme,
    classical_pubkey_ref: envelope.classical_pubkey_ref,
    pq_scheme: envelope.pq_scheme,
    pq_pubkey_ref: envelope.pq_pubkey_ref,
  });
}

export function computeAresDigestV1(envelope: AresUnsignedEnvelopeV1 | AresEnvelopeV1): string {
  return sha3Hex(digestMaterial(withoutSignatures(envelope)));
}

export function computeAresEnvelopeHashV1(envelope: AresEnvelopeV1): string {
  return sha3Hex(
    canonicalJson({
      domain: ARES_ENVELOPE_HASH_DOMAIN,
      unsigned: withoutSignatures(envelope),
      classical_signature: envelope.classical_signature,
      pq_signature: envelope.pq_signature,
    }),
  );
}

function withoutSignatures(envelope: AresUnsignedEnvelopeV1 | AresEnvelopeV1): AresUnsignedEnvelopeV1 {
  return {
    version: envelope.version,
    chain_id: envelope.chain_id,
    app_id: envelope.app_id,
    account: envelope.account,
    policy_id: envelope.policy_id,
    session_id: envelope.session_id,
    capability_set: [...envelope.capability_set],
    nonce: envelope.nonce,
    issued_at: envelope.issued_at,
    expires_at: envelope.expires_at,
    previous_envelope_hash: envelope.previous_envelope_hash,
    payload_hash: envelope.payload_hash,
    classical_scheme: envelope.classical_scheme,
    classical_pubkey_ref: envelope.classical_pubkey_ref,
    pq_scheme: envelope.pq_scheme,
    pq_pubkey_ref: envelope.pq_pubkey_ref,
  };
}

function normalizeSignatureForRecovery(signature: string): string {
  const bytes = getBytes(signature);
  if (bytes.length !== 65) throw new Error(`Invalid classical signature length: ${bytes.length}`);
  const mutable = new Uint8Array(bytes);
  const v = mutable[64] ?? 0;
  if (v === 0 || v === 1) mutable[64] = v + 27;
  if (mutable[64] !== 27 && mutable[64] !== 28) throw new Error(`Invalid classical signature v: ${mutable[64]}`);
  return hexlify(mutable);
}

function signDigestGoStyle(digest: string, privateKey: string): string {
  const key = new SigningKey(privateKey);
  const sig = key.sign(digest);
  return hexlify(concat([sig.r, sig.s, Uint8Array.from([sig.yParity])]));
}

export async function createAresEnvelopeV1(input: CreateAresEnvelopeV1Input): Promise<AresEnvelopeV1> {
  const key = new SigningKey(input.classicalPrivateKey);
  const classicalAddress = computeAddress(key.publicKey);
  if (getAddress(input.account) !== classicalAddress) throw new Error("account_private_key_mismatch");
  const issuedAt = normalizeIso(input.issuedAt);
  const expiresAt = normalizeIso(input.expiresAt);
  if (new Date(expiresAt).getTime() <= new Date(issuedAt).getTime()) throw new Error("invalid_time_window");
  const unsignedEnvelope: AresUnsignedEnvelopeV1 = {
    version: ARES_VERSION,
    chain_id: input.chainId,
    app_id: input.appId,
    account: getAddress(input.account),
    policy_id: input.policyId,
    session_id: input.sessionId,
    capability_set: [...new Set(input.capabilitySet)].sort(),
    nonce: input.nonce,
    issued_at: issuedAt,
    expires_at: expiresAt,
    previous_envelope_hash: normalizeHex32(input.previousEnvelopeHash, "0x" + "00".repeat(32)),
    payload_hash: computeAresPayloadHash(input.payload),
    classical_scheme: "eth_secp256k1",
    classical_pubkey_ref: classicalAddress,
    pq_scheme: input.pqScheme || "ml-dsa-65",
    pq_pubkey_ref: input.pqPubkeyRef,
  };
  const digest = computeAresDigestV1(unsignedEnvelope);
  const classicalSignature = signDigestGoStyle(digest, input.classicalPrivateKey);
  const pqSignature = input.pqSigner ? await input.pqSigner(digest, unsignedEnvelope) : "";
  return {
    ...unsignedEnvelope,
    classical_signature: classicalSignature,
    pq_signature: pqSignature,
  };
}

export async function verifyAresEnvelopeV1(
  envelope: AresEnvelopeV1,
  payload: unknown,
  options: VerifyAresEnvelopeV1Options = {},
): Promise<VerifyAresEnvelopeV1Result> {
  const mode = options.mode || "strict";
  let digest = "0x";
  let envelopeHash = "0x";
  try {
    if (envelope.version !== ARES_VERSION) throw new Error("unsupported_version");
    if (envelope.classical_scheme !== "eth_secp256k1") throw new Error("unsupported_classical_scheme");
    if (options.policy?.chainId && envelope.chain_id !== options.policy.chainId) throw new Error("chain_id_mismatch");
    if (options.policy?.appId && envelope.app_id !== options.policy.appId) throw new Error("app_id_mismatch");
    if (options.policy?.account && getAddress(envelope.account) !== getAddress(options.policy.account)) {
      throw new Error("account_mismatch");
    }
    if (options.policy?.policyId && envelope.policy_id !== options.policy.policyId) throw new Error("policy_id_mismatch");
    if (options.policy?.sessionId && envelope.session_id !== options.policy.sessionId) throw new Error("session_id_mismatch");
    if (options.policy?.expectedPreviousEnvelopeHash) {
      const expected = normalizeHex32(options.policy.expectedPreviousEnvelopeHash, "0x" + "00".repeat(32));
      if (envelope.previous_envelope_hash.toLowerCase() !== expected.toLowerCase()) {
        throw new Error("previous_envelope_hash_mismatch");
      }
    }
    const requiredCapabilities = options.policy?.requiredCapabilities || [];
    for (const capability of requiredCapabilities) {
      if (!envelope.capability_set.includes(capability)) throw new Error("capability_missing");
    }
    if (computeAresPayloadHash(payload).toLowerCase() !== envelope.payload_hash.toLowerCase()) {
      throw new Error("payload_hash_mismatch");
    }
    const now = options.now || new Date();
    const issuedAt = new Date(envelope.issued_at).getTime();
    const expiresAt = new Date(envelope.expires_at).getTime();
    if (!Number.isFinite(issuedAt) || !Number.isFinite(expiresAt)) throw new Error("invalid_timestamp");
    if (expiresAt <= issuedAt) throw new Error("invalid_time_window");
    if (expiresAt <= now.getTime()) throw new Error("envelope_expired");
    const maxFutureSkewMs = Math.max(0, options.maxFutureSkewSec ?? 300) * 1000;
    if (issuedAt - now.getTime() > maxFutureSkewMs) throw new Error("envelope_not_yet_valid");
    digest = computeAresDigestV1(envelope);
    envelopeHash = computeAresEnvelopeHashV1(envelope);
    const recovered = getAddress(recoverAddress(digest, normalizeSignatureForRecovery(envelope.classical_signature)));
    if (recovered !== getAddress(envelope.classical_pubkey_ref) || recovered !== getAddress(envelope.account)) {
      throw new Error("classical_signature_invalid");
    }
    const nonceKey = `${envelope.chain_id}:${envelope.app_id}:${envelope.account}:${envelope.policy_id}:${envelope.session_id}:${envelope.nonce}`;
    if (options.usedNonce?.(nonceKey, envelope)) throw new Error("nonce_replay");
    let pqVerified = false;
    if (envelope.pq_signature && options.pqVerifier) {
      pqVerified = await options.pqVerifier({
        digest,
        envelope,
        signature: envelope.pq_signature,
        pubkeyRef: envelope.pq_pubkey_ref,
        scheme: envelope.pq_scheme,
      });
    }
    if (mode === "strict" && !pqVerified) throw new Error("pq_signature_invalid");
    return { ok: true, mode, digest, envelopeHash, recoveredClassicalSigner: recovered, pqVerified, nonceKey };
  } catch (error) {
    return {
      ok: false,
      mode,
      digest,
      envelopeHash,
      reason: error instanceof Error ? error.message : "verify_failed",
    };
  }
}
