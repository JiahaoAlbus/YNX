#!/usr/bin/env node
import { decodeYNAddress, encodeYNAddress } from "./ynAddress.js";
import { verifyPreconfirmReceiptV0, type PreconfirmReceiptV0 } from "./preconfirmations.js";

function usage(): never {
  console.error(
    [
      "Usage:",
      "  ynx address encode <0x...>",
      "  ynx address decode <YN...>",
      "  ynx preconfirm verify <0xTxHash> --rpc <url> [--allowlist <addr1,addr2,...>]",
      "",
      "Examples:",
      "  ynx address encode 0x0000000000000000000000000000000000000000",
      "  ynx address decode YN...",
      "  ynx preconfirm verify 0x<txHash> --rpc http://127.0.0.1:8545",
    ].join("\n"),
  );
  process.exit(2);
}

type JsonRpcResponse<T> =
  | { jsonrpc: "2.0"; id: number | string; result: T }
  | { jsonrpc: "2.0"; id: number | string; error: { code: number; message: string; data?: unknown } };

async function jsonRpc<T>(url: string, method: string, params: unknown[]): Promise<T> {
  const body = { jsonrpc: "2.0", id: 1, method, params };
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}`);
  }
  const payload = (await res.json()) as JsonRpcResponse<T>;
  if ("error" in payload) {
    throw new Error(payload.error.message);
  }
  return payload.result;
}

function parseFlagValue(args: string[], name: string): string | undefined {
  const i = args.indexOf(name);
  if (i === -1) return undefined;
  return args[i + 1];
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const topic = args[0];

  if (topic === "address") {
    const action = args[1];
    const value = args[2];
    if (action === undefined || value === undefined) usage();

    if (action === "encode") {
      console.log(encodeYNAddress(value));
      return;
    }

    if (action === "decode") {
      const decoded = decodeYNAddress(value);
      console.log(decoded.evmAddress);
      return;
    }

    usage();
  }

  if (topic === "preconfirm") {
    const action = args[1];
    if (action !== "verify") usage();

    const txHash = args.find((a) => a.startsWith("0x") && a.length === 66);
    if (!txHash) usage();

    const rpc = parseFlagValue(args, "--rpc");
    if (!rpc) usage();

    const allowlistCsv = parseFlagValue(args, "--allowlist");
    const allowlist = allowlistCsv ? allowlistCsv.split(",").map((s) => s.trim()).filter(Boolean) : undefined;

    const receipt = await jsonRpc<PreconfirmReceiptV0>(rpc, "ynx_preconfirmTx", [txHash]);
    const verified = verifyPreconfirmReceiptV0(receipt, { allowlist });

    if (!verified.ok) {
      console.error(JSON.stringify(verified, null, 2));
      process.exit(1);
    }
    console.log(JSON.stringify(verified, null, 2));
    return;
  }

  usage();
}

main().catch((err) => {
  const msg = err instanceof Error ? err.message : String(err);
  console.error(msg);
  process.exit(1);
});
