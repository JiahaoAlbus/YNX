import { describe, expect, it } from "vitest";

import { decodeYNAddress, encodeYNAddress, isYNAddress } from "../src/ynAddress.js";

describe("YN address format", () => {
  it("round-trips a canonical EVM address", () => {
    const evm = "0x0000000000000000000000000000000000000000";
    const yn = encodeYNAddress(evm, { version: 1 });
    expect(yn.startsWith("YN")).toBe(true);

    const decoded = decodeYNAddress(yn, 1);
    expect(decoded.evmAddress).toBe(evm);
    expect(decoded.version).toBe(1);
  });

  it("rejects non-YN prefixes", () => {
    expect(() => decodeYNAddress("T123")).toThrow(/Invalid YN prefix/);
  });

  it("isYNAddress() detects invalid strings", () => {
    expect(isYNAddress("YNnotbase58")).toBe(false);
  });
});

