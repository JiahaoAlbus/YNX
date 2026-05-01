import { describe, expect, it } from "vitest";
import { SigningKey, computeAddress, concat, getBytes, hexlify } from "ethers";
import { computePreconfirmDigestV0, verifyPreconfirmReceiptV0 } from "../src/preconfirmations.js";

const SECP256K1_N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141n;

function goStyleSignatureBytes(digest: string, privKey: string): string {
  const key = new SigningKey(privKey);
  const sig = key.sign(digest);
  const v = sig.yParity; // 0 | 1
  return hexlify(concat([sig.r, sig.s, Uint8Array.from([v])]));
}

function toHighSSignature(signature: string): string {
  const bytes = getBytes(signature);
  const s = BigInt(hexlify(bytes.slice(32, 64)));
  const highS = (SECP256K1_N - s).toString(16).padStart(64, "0");
  bytes.set(getBytes(`0x${highS}`), 32);
  if (bytes[64] === 0) bytes[64] = 1;
  else if (bytes[64] === 1) bytes[64] = 0;
  else if (bytes[64] === 27) bytes[64] = 28;
  else if (bytes[64] === 28) bytes[64] = 27;
  return hexlify(bytes);
}

describe("preconfirmations (v0)", () => {
  it("computes digest and verifies a single-signer receipt", () => {
    const privKey = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
    const signer = computeAddress(new SigningKey(privKey).publicKey);

    const input = {
      status: "pending" as const,
      chainId: "ynx_9001-1",
      evmChainId: 9001n,
      txHash: "0x" + "11".repeat(32),
      targetBlock: 123n,
      issuedAt: 456n,
    };

    const digest = computePreconfirmDigestV0(input);
    const signature = goStyleSignatureBytes(digest, privKey);

    const res = verifyPreconfirmReceiptV0({
      status: input.status,
      chainId: input.chainId,
      evmChainId: "0x2329",
      txHash: input.txHash,
      targetBlock: "0x7b",
      issuedAt: "0x1c8",
      signer,
      digest,
      signature,
    });

    expect(res.ok).toBe(true);
    expect(res.validSigners).toEqual([signer]);
  });

  it("verifies threshold multi-signer receipts", () => {
    const priv1 = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
    const priv2 = "0x8b3a350cf5c34c9194ca3a545d3e122a3c0c1e34b6c1aa7e4e7cf1b0f00a2a2b";
    const priv3 = "0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f2e0e9d85e1f2b1c4e8d7";

    const key1 = new SigningKey(priv1);
    const key2 = new SigningKey(priv2);
    const key3 = new SigningKey(priv3);
    const s1 = computeAddress(key1.publicKey);
    const s2 = computeAddress(key2.publicKey);
    const s3 = computeAddress(key3.publicKey);

    const digest = computePreconfirmDigestV0({
      status: "included",
      chainId: "ynx_9001-1",
      evmChainId: 9001n,
      txHash: "0x" + "22".repeat(32),
      targetBlock: 999n,
      issuedAt: 777n,
    });

    const sig1 = goStyleSignatureBytes(digest, priv1);
    const sig2 = goStyleSignatureBytes(digest, priv2);
    const sig3 = goStyleSignatureBytes(digest, priv3);

    const res = verifyPreconfirmReceiptV0({
      status: "included",
      chainId: "ynx_9001-1",
      evmChainId: "0x2329",
      txHash: "0x" + "22".repeat(32),
      targetBlock: "0x3e7",
      issuedAt: "0x309",
      signer: s1,
      digest,
      signature: sig1,
      signers: [s1, s2, s3],
      signatures: [sig1, sig2, sig3],
      threshold: 2,
    });

    expect(res.ok).toBe(true);
    expect(res.validSigners.length).toBeGreaterThanOrEqual(2);
  });

  it("does not count duplicate signer entries toward threshold", () => {
    const privKey = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
    const signer = computeAddress(new SigningKey(privKey).publicKey);
    const digest = computePreconfirmDigestV0({
      status: "included",
      chainId: "ynx_9001-1",
      evmChainId: 9001n,
      txHash: "0x" + "55".repeat(32),
      targetBlock: 3n,
      issuedAt: 3n,
    });
    const signature = goStyleSignatureBytes(digest, privKey);

    const res = verifyPreconfirmReceiptV0({
      status: "included",
      chainId: "ynx_9001-1",
      evmChainId: "0x2329",
      txHash: "0x" + "55".repeat(32),
      targetBlock: "0x3",
      issuedAt: "0x3",
      signer,
      digest,
      signature,
      signers: [signer, signer],
      signatures: [signature, signature],
      threshold: 2,
    });

    expect(res.ok).toBe(false);
    expect(res.validSigners).toEqual([signer]);
    expect(res.reason).toBe("insufficient valid signatures");
  });

  it("rejects high-s malleable signatures", () => {
    const privKey = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
    const signer = computeAddress(new SigningKey(privKey).publicKey);
    const digest = computePreconfirmDigestV0({
      status: "pending",
      chainId: "ynx_9001-1",
      evmChainId: 9001n,
      txHash: "0x" + "66".repeat(32),
      targetBlock: 4n,
      issuedAt: 4n,
    });
    const signature = toHighSSignature(goStyleSignatureBytes(digest, privKey));

    const res = verifyPreconfirmReceiptV0({
      status: "pending",
      chainId: "ynx_9001-1",
      evmChainId: "0x2329",
      txHash: "0x" + "66".repeat(32),
      targetBlock: "0x4",
      issuedAt: "0x4",
      signer,
      digest,
      signature,
    });

    expect(res.ok).toBe(false);
    expect(res.reason).toBe("insufficient valid signatures");
  });

  it("fails on digest mismatch", () => {
    const privKey = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
    const signer = computeAddress(new SigningKey(privKey).publicKey);

    const digest = computePreconfirmDigestV0({
      status: "pending",
      chainId: "ynx_9001-1",
      evmChainId: 9001n,
      txHash: "0x" + "33".repeat(32),
      targetBlock: 1n,
      issuedAt: 1n,
    });
    const signature = goStyleSignatureBytes(digest, privKey);

    const res = verifyPreconfirmReceiptV0({
      status: "pending",
      chainId: "ynx_9001-1",
      evmChainId: "0x2329",
      txHash: "0x" + "33".repeat(32),
      targetBlock: "0x1",
      issuedAt: "0x1",
      signer,
      digest: "0x" + "00".repeat(32),
      signature,
    });

    expect(res.ok).toBe(false);
    expect(res.reason).toBe("digest mismatch");
  });

  it("verifies allowlisted signers only", () => {
    const privKey = "0x59c6995e998f97a5a0044966f094538b292c0acdf0f39c6a9c3d6f64b87b84c1";
    const signer = computeAddress(new SigningKey(privKey).publicKey);

    const digest = computePreconfirmDigestV0({
      status: "pending",
      chainId: "ynx_9001-1",
      evmChainId: 9001n,
      txHash: "0x" + "44".repeat(32),
      targetBlock: 2n,
      issuedAt: 2n,
    });
    const signature = goStyleSignatureBytes(digest, privKey);

    const ok = verifyPreconfirmReceiptV0(
      {
        status: "pending",
        chainId: "ynx_9001-1",
        evmChainId: "0x2329",
        txHash: "0x" + "44".repeat(32),
        targetBlock: "0x2",
        issuedAt: "0x2",
        signer,
        digest,
        signature,
      },
      { allowlist: [signer] },
    );
    expect(ok.ok).toBe(true);

    const bad = verifyPreconfirmReceiptV0(
      {
        status: "pending",
        chainId: "ynx_9001-1",
        evmChainId: "0x2329",
        txHash: "0x" + "44".repeat(32),
        targetBlock: "0x2",
        issuedAt: "0x2",
        signer,
        digest,
        signature,
      },
      { allowlist: ["0x0000000000000000000000000000000000000001"] },
    );
    expect(bad.ok).toBe(false);
    expect(bad.reason).toBe("insufficient valid signatures");
  });
});
