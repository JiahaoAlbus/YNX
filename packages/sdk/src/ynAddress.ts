import bs58check from "bs58check";
import { getAddress } from "ethers";

export type YNAddressOptions = {
  version?: number;
};

const DEFAULT_VERSION = 0x01;

function hexToBytes(hex: string): Uint8Array {
  const normalized = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (normalized.length !== 40) {
    throw new Error("Invalid EVM address length");
  }
  return Uint8Array.from(Buffer.from(normalized, "hex"));
}

function bytesToHex(bytes: Uint8Array): string {
  return `0x${Buffer.from(bytes).toString("hex")}`;
}

/**
 * Encodes an EVM canonical address (`0x` + 20 bytes) into a human-friendly `YN...` string.
 *
 * Format (v0):
 * - Prefix: ASCII "YN"
 * - Payload: Base58Check( [1-byte version] || [20-byte address] )
 *
 * Notes:
 * - The `YN` prefix is explicit to guarantee the visible prefix.
 * - Versioning is included for forward compatibility.
 */
export function encodeYNAddress(evmAddress: string, options: YNAddressOptions = {}): string {
  const version = options.version ?? DEFAULT_VERSION;
  if (!Number.isInteger(version) || version < 0 || version > 255) {
    throw new Error("Invalid version");
  }

  const checksummed = getAddress(evmAddress);
  const addressBytes = hexToBytes(checksummed);
  const payload = Buffer.concat([Buffer.from([version]), Buffer.from(addressBytes)]);
  return `YN${bs58check.encode(payload)}`;
}

export type DecodedYNAddress = {
  evmAddress: string;
  version: number;
};

export function decodeYNAddress(ynAddress: string, expectedVersion?: number): DecodedYNAddress {
  if (!ynAddress.startsWith("YN")) {
    throw new Error("Invalid YN prefix");
  }

  const decoded = bs58check.decode(ynAddress.slice(2));
  if (decoded.length !== 1 + 20) {
    throw new Error("Invalid payload length");
  }

  const version = decoded[0] ?? 0;
  if (expectedVersion !== undefined && version !== expectedVersion) {
    throw new Error("Unsupported version");
  }

  const addressBytes = decoded.subarray(1);
  const evmAddress = getAddress(bytesToHex(addressBytes));
  return { evmAddress, version };
}

export function isYNAddress(value: string): boolean {
  try {
    decodeYNAddress(value);
    return true;
  } catch {
    return false;
  }
}

