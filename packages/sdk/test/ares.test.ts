import { createHash } from "node:crypto";
import { describe, expect, it } from "vitest";
import { computeAddress, SigningKey } from "ethers";
import {
  computeAresPayloadHash,
  createAresEnvelopeV1,
  verifyAresEnvelopeV1,
} from "../src/ares.js";

const privKey = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
const account = computeAddress(new SigningKey(privKey).publicKey);
const pqSecret = "test-pq-secret";

function testPqSignature(digest: string, secret: string): string {
  return `0x${createHash("sha3-256").update(JSON.stringify({ digest, secret })).digest("hex")}`;
}

describe("ares envelopes (v1)", () => {
  it("creates and verifies strict hybrid envelopes", async () => {
    const payload = { action: "agent.create", params: { name: "ares-agent", model: "ynx" } };
    const envelope = await createAresEnvelopeV1({
      chainId: "ynx_9102-1",
      appId: "web4-hub",
      account,
      policyId: "policy_1",
      sessionId: "session_1",
      capabilitySet: ["agent.create"],
      nonce: "nonce_1",
      issuedAt: "2026-05-01T00:00:00.000Z",
      expiresAt: "2026-05-01T00:10:00.000Z",
      payload,
      classicalPrivateKey: privKey,
      pqPubkeyRef: "ml-dsa-test-pubkey",
      pqSigner: (digest) => testPqSignature(digest, pqSecret),
    });

    const result = await verifyAresEnvelopeV1(envelope, payload, {
      mode: "strict",
      now: new Date("2026-05-01T00:01:00.000Z"),
      policy: {
        chainId: "ynx_9102-1",
        appId: "web4-hub",
        account,
        policyId: "policy_1",
        sessionId: "session_1",
        requiredCapabilities: ["agent.create"],
      },
      pqVerifier: ({ digest, signature }) => testPqSignature(digest, pqSecret) === signature,
    });

    expect(result.ok).toBe(true);
    expect(result.pqVerified).toBe(true);
    expect(result.recoveredClassicalSigner).toBe(account);
  });

  it("accepts classical-only observe mode but rejects strict mode without PQ verification", async () => {
    const payload = { action: "intent.create", budget: "10" };
    const envelope = await createAresEnvelopeV1({
      chainId: "ynx_9102-1",
      appId: "web4-hub",
      account,
      policyId: "policy_2",
      sessionId: "session_2",
      capabilitySet: ["intent.create"],
      nonce: "nonce_2",
      issuedAt: "2026-05-01T00:00:00.000Z",
      expiresAt: "2026-05-01T00:10:00.000Z",
      payload,
      classicalPrivateKey: privKey,
      pqPubkeyRef: "ml-dsa-test-pubkey",
    });

    const observe = await verifyAresEnvelopeV1(envelope, payload, {
      mode: "observe",
      now: new Date("2026-05-01T00:01:00.000Z"),
    });
    expect(observe.ok).toBe(true);
    expect(observe.pqVerified).toBe(false);

    const strict = await verifyAresEnvelopeV1(envelope, payload, {
      mode: "strict",
      now: new Date("2026-05-01T00:01:00.000Z"),
    });
    expect(strict.ok).toBe(false);
    expect(strict.reason).toBe("pq_signature_invalid");
  });

  it("detects payload mutation and nonce replay", async () => {
    const payload = { action: "agent.modify", patch: { model: "a" } };
    const envelope = await createAresEnvelopeV1({
      chainId: "ynx_9102-1",
      appId: "web4-hub",
      account,
      policyId: "policy_3",
      sessionId: "session_3",
      capabilitySet: ["agent.modify"],
      nonce: "nonce_3",
      issuedAt: "2026-05-01T00:00:00.000Z",
      expiresAt: "2026-05-01T00:10:00.000Z",
      payload,
      classicalPrivateKey: privKey,
      pqPubkeyRef: "ml-dsa-test-pubkey",
      pqSigner: (digest) => testPqSignature(digest, pqSecret),
    });

    const mutated = await verifyAresEnvelopeV1(envelope, { action: "agent.modify", patch: { model: "b" } }, {
      mode: "observe",
      now: new Date("2026-05-01T00:01:00.000Z"),
    });
    expect(mutated.ok).toBe(false);
    expect(mutated.reason).toBe("payload_hash_mismatch");

    const replayed = await verifyAresEnvelopeV1(envelope, payload, {
      mode: "observe",
      now: new Date("2026-05-01T00:01:00.000Z"),
      usedNonce: () => true,
    });
    expect(replayed.ok).toBe(false);
    expect(replayed.reason).toBe("nonce_replay");
  });

  it("canonicalizes JSON payload hashes by key order", () => {
    expect(computeAresPayloadHash({ z: 1, a: { b: 2, c: 3 } })).toBe(
      computeAresPayloadHash({ a: { c: 3, b: 2 }, z: 1 }),
    );
  });
});
