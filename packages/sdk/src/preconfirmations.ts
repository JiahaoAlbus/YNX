import { concat, getAddress, getBytes, hexlify, keccak256, recoverAddress } from "ethers";

const TX_CONFIRM_DIGEST_PREFIX = "YNX_TXCONFIRM_V0";

export type PreconfirmStatus = "pending" | "included" | (string & {});

export type PreconfirmReceiptV0 = {
  status: PreconfirmStatus;
  chainId: string;
  evmChainId: string | number | bigint;
  txHash: string;
  targetBlock: string | number | bigint;
  issuedAt: string | number | bigint;
  signer: string;
  digest: string;
  signature: string;
  signers?: string[];
  signatures?: string[];
  threshold?: number;
};

export type ComputePreconfirmDigestV0Input = {
  status: PreconfirmStatus;
  chainId: string;
  evmChainId: bigint;
  txHash: string;
  targetBlock: bigint;
  issuedAt: bigint;
};

function u16be(n: number): Uint8Array {
  if (!Number.isInteger(n) || n < 0 || n > 0xffff) {
    throw new Error(`Invalid uint16: ${n}`);
  }
  const out = new Uint8Array(2);
  out[0] = (n >> 8) & 0xff;
  out[1] = n & 0xff;
  return out;
}

function u64be(n: bigint): Uint8Array {
  if (n < 0n || n > 0xffff_ffff_ffff_ffffn) {
    throw new Error(`Invalid uint64: ${n.toString()}`);
  }
  const out = new Uint8Array(8);
  let x = n;
  for (let i = 7; i >= 0; i--) {
    out[i] = Number(x & 0xffn);
    x >>= 8n;
  }
  return out;
}

function parseHexQuantity(value: string): bigint {
  const v = value.trim().toLowerCase();
  if (!v.startsWith("0x")) throw new Error(`Invalid hex quantity: ${value}`);
  if (v === "0x") return 0n;
  return BigInt(v);
}

function parseNumberish(value: string | number | bigint): bigint {
  if (typeof value === "bigint") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value) || !Number.isInteger(value)) {
      throw new Error(`Invalid number: ${value}`);
    }
    return BigInt(value);
  }
  const s = value.trim();
  if (s.startsWith("0x") || s.startsWith("0X")) return parseHexQuantity(s);
  if (!/^\d+$/.test(s)) throw new Error(`Invalid decimal: ${value}`);
  return BigInt(s);
}

function normalizeTxHash(txHash: string): Uint8Array {
  const bytes = getBytes(txHash);
  if (bytes.length !== 32) {
    throw new Error(`Invalid txHash length: ${bytes.length} (expected 32)`);
  }
  return bytes;
}

function statusMode(status: PreconfirmStatus): number {
  return status.toLowerCase() === "included" ? 1 : 0;
}

export function computePreconfirmDigestV0(input: ComputePreconfirmDigestV0Input): string {
  const chainId = input.chainId.trim() === "" ? "unknown" : input.chainId.trim();
  const chainIdBytes = new TextEncoder().encode(chainId);
  const chainIdLen = Math.min(chainIdBytes.length, 65535);
  const chainIdBytesCapped = chainIdBytes.subarray(0, chainIdLen);

  const mode = statusMode(input.status);
  const msg = concat([
    new TextEncoder().encode(TX_CONFIRM_DIGEST_PREFIX),
    Uint8Array.from([mode]),
    u16be(chainIdBytesCapped.length),
    chainIdBytesCapped,
    u64be(input.evmChainId),
    normalizeTxHash(input.txHash),
    u64be(input.targetBlock),
    u64be(input.issuedAt),
  ]);

  return keccak256(msg);
}

function normalizeSignatureForRecovery(sigBytes: Uint8Array): string {
  if (sigBytes.length !== 65) {
    throw new Error(`Invalid signature length: ${sigBytes.length} (expected 65)`);
  }
  const v = sigBytes[64] ?? 0;
  if (v === 0 || v === 1) {
    sigBytes[64] = v + 27;
  }
  if (sigBytes[64] !== 27 && sigBytes[64] !== 28) {
    throw new Error(`Invalid signature v: ${sigBytes[64]}`);
  }
  return hexlify(sigBytes);
}

export type VerifyPreconfirmReceiptOptions = {
  allowlist?: string[];
};

export type VerifyPreconfirmReceiptResult = {
  ok: boolean;
  digest: string;
  threshold: number;
  validSigners: string[];
  reason?: string;
};

export function verifyPreconfirmReceiptV0(
  receipt: PreconfirmReceiptV0,
  options: VerifyPreconfirmReceiptOptions = {},
): VerifyPreconfirmReceiptResult {
  const allowlist = options.allowlist?.map((a) => getAddress(a));
  const allowset = allowlist ? new Set(allowlist) : undefined;

  let digest: string;
  try {
    digest = computePreconfirmDigestV0({
      status: receipt.status,
      chainId: receipt.chainId,
      evmChainId: parseNumberish(receipt.evmChainId),
      txHash: receipt.txHash,
      targetBlock: parseNumberish(receipt.targetBlock),
      issuedAt: parseNumberish(receipt.issuedAt),
    });
  } catch (err) {
    return { ok: false, digest: "0x", threshold: 0, validSigners: [], reason: (err as Error).message };
  }

  if (receipt.digest && receipt.digest.toLowerCase() !== digest.toLowerCase()) {
    return { ok: false, digest, threshold: 0, validSigners: [], reason: "digest mismatch" };
  }

  const signers = receipt.signers?.length ? receipt.signers : [receipt.signer];
  const signatures = receipt.signatures?.length ? receipt.signatures : [receipt.signature];
  if (signers.length !== signatures.length) {
    return { ok: false, digest, threshold: 0, validSigners: [], reason: "signers/signatures length mismatch" };
  }

  const threshold = receipt.threshold && receipt.threshold > 0 ? receipt.threshold : signers.length;
  if (threshold > signers.length) {
    return { ok: false, digest, threshold, validSigners: [], reason: "threshold exceeds signer count" };
  }

  const validSigners: string[] = [];
  for (let i = 0; i < signers.length; i++) {
    const sig = signatures[i] ?? "0x";
    try {
      const signer = getAddress(signers[i] ?? "0x0000000000000000000000000000000000000000");
      if (allowset && !allowset.has(signer)) continue;

      const sigBytes = getBytes(sig);
      const normalized = normalizeSignatureForRecovery(sigBytes);
      const recovered = getAddress(recoverAddress(digest, normalized));
      if (recovered !== signer) continue;
      validSigners.push(signer);
    } catch {
      continue;
    }
  }

  if (validSigners.length < threshold) {
    return { ok: false, digest, threshold, validSigners, reason: "insufficient valid signatures" };
  }

  return { ok: true, digest, threshold, validSigners };
}
