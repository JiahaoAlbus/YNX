#!/usr/bin/env node
import { decodeYNAddress, encodeYNAddress } from "./ynAddress.js";

function usage(): never {
  console.error(
    [
      "Usage:",
      "  ynx address encode <0x...>",
      "  ynx address decode <YN...>",
      "",
      "Examples:",
      "  ynx address encode 0x0000000000000000000000000000000000000000",
      "  ynx address decode YN...",
    ].join("\n"),
  );
  process.exit(2);
}

const [topic, action, value] = process.argv.slice(2);
if (topic !== "address" || action === undefined || value === undefined) {
  usage();
}

if (action === "encode") {
  console.log(encodeYNAddress(value));
  process.exit(0);
}

if (action === "decode") {
  const decoded = decodeYNAddress(value);
  console.log(decoded.evmAddress);
  process.exit(0);
}

usage();
