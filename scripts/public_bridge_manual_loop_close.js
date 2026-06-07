#!/usr/bin/env node
"use strict";

const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
let ethers;
try {
  ({ ethers } = require("ethers"));
} catch {
  ({ ethers } = require(path.resolve(__dirname, "../infra/bridge-service/node_modules/ethers")));
}

const routeIds = (process.env.YNX_MANUAL_LOOP_ROUTES || "btc-testnet-btc,bnb-testnet-bnb,tron-shasta-usdt")
  .split(",")
  .map((item) => item.trim())
  .filter(Boolean);

const bridgeBase = (process.env.YNX_BRIDGE_LOCAL_URL || process.env.BRIDGE_BASE_URL || "http://127.0.0.1:38083/bridge").replace(/\/$/, "");
const token = process.env.BRIDGE_OPERATOR_TOKEN || "";
const routesFile =
  process.env.BRIDGE_ROUTES_FILE ||
  path.resolve(__dirname, "../infra/bridge-service/config/testnet-routes.json");
const rpcUrl = process.env.BRIDGE_YNX_RPC_URL || process.env.YNX_PUBLIC_EVM_RPC || "https://evm.ynxweb4.com";
const privateKey = process.env.AI_ONCHAIN_PRIVATE_KEY || process.env.YNX_EVM_PRIVATE_KEY || "";
const stamp = process.env.YNX_MANUAL_LOOP_STAMP || new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);

const gatewayAbi = [
  "function burnForBridgeMapped(address token,uint256 amount,uint64 destinationChainId,bytes32 destinationRecipient)",
];
const erc20Abi = [
  "function approve(address spender,uint256 amount) returns (bool)",
  "function balanceOf(address account) view returns (uint256)",
];

const defaultAmounts = {
  "btc-testnet-btc": "1",
  "bnb-testnet-bnb": "1",
  "tron-shasta-usdt": "1",
};

function must(condition, message) {
  if (!condition) throw new Error(message);
}

function requestJson(targetUrl, options = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(targetUrl);
    const body = options.body === undefined ? "" : JSON.stringify(options.body);
    const transport = url.protocol === "https:" ? https : http;
    const req = transport.request(
      {
        method: options.method || "GET",
        hostname: url.hostname,
        port: url.port || (url.protocol === "https:" ? 443 : 80),
        path: `${url.pathname}${url.search}`,
        timeout: Number(options.timeout_ms || 30000),
        headers: {
          ...(body ? { "content-type": "application/json", "content-length": Buffer.byteLength(body) } : {}),
          ...(token ? { "x-ynx-bridge-token": token } : {}),
          ...(options.headers || {}),
        },
      },
      (res) => {
        let raw = "";
        res.on("data", (chunk) => {
          raw += chunk.toString();
        });
        res.on("end", () => {
          let parsed = {};
          try {
            parsed = raw ? JSON.parse(raw) : {};
          } catch {
            parsed = { raw };
          }
          resolve({ status: res.statusCode || 0, body: parsed });
        });
      },
    );
    req.on("timeout", () => req.destroy(new Error("request_timeout")));
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function bytes32Recipient(address) {
  return ethers.zeroPadValue(address, 32);
}

async function postOk(pathname, body, expected = [200, 201]) {
  const response = await requestJson(`${bridgeBase}${pathname}`, { method: "POST", body });
  if (!expected.includes(response.status) || response.body?.ok === false) {
    throw new Error(`${pathname} failed: status=${response.status} body=${JSON.stringify(response.body)}`);
  }
  return response.body;
}

async function mineOneBlock(provider, wallet) {
  const tx = await wallet.sendTransaction({ to: wallet.address, value: 0n });
  await tx.wait(1);
  return tx.hash;
}

async function main() {
  must(token, "BRIDGE_OPERATOR_TOKEN is required");
  must(privateKey, "AI_ONCHAIN_PRIVATE_KEY or YNX_EVM_PRIVATE_KEY is required");
  const routesConfig = JSON.parse(fs.readFileSync(routesFile, "utf8"));
  const gatewayAddress = process.env.BRIDGE_GATEWAY_ADDRESS || routesConfig.gateway;
  must(gatewayAddress, "bridge gateway address is required");

  const provider = new ethers.JsonRpcProvider(rpcUrl);
  const wallet = new ethers.Wallet(privateKey, provider);
  const gateway = new ethers.Contract(gatewayAddress, gatewayAbi, wallet);
  const results = [];

  for (const routeId of routeIds) {
    const route = (routesConfig.routes || []).find((item) => item.routeId === routeId);
    must(route, `route not found: ${routeId}`);
    const amount = BigInt(process.env[`YNX_MANUAL_LOOP_AMOUNT_${routeId.toUpperCase().replace(/[^A-Z0-9]/g, "_")}`] || defaultAmounts[routeId] || "1");
    const sourceTxHash = ethers.id(`ynx-public-testnet-manual-deposit:${routeId}:${stamp}`);
    const releaseTxHash = ethers.id(`ynx-public-testnet-manual-release:${routeId}:${stamp}`);

    const deposit = await postOk("/deposits/prove", {
      route_id: routeId,
      recipient: wallet.address,
      amount_base_units: amount.toString(),
      confirmations: Math.max(1, Number(route.minConfirmations || 1)),
      source_tx_hash: sourceTxHash,
      proof: {
        mode: "operator-attested-public-testnet-manual-deposit",
        source_network: route.sourceNetwork,
        source_asset: route.asset,
        generated_at: new Date().toISOString(),
        note: "Manual public-testnet route smoke proof; not a mainnet custody or redemption claim.",
      },
    });
    const tokenContract = new ethers.Contract(route.wrappedToken, erc20Abi, wallet);
    const balance = await tokenContract.balanceOf(wallet.address);
    if (balance < amount) {
      throw new Error(`${routeId} minted balance too low: balance=${balance} amount=${amount}`);
    }

    const approveTx = await tokenContract.approve(gatewayAddress, amount);
    const approveReceipt = await approveTx.wait(1);
    const burnTx = await gateway.burnForBridgeMapped(
      route.wrappedToken,
      amount,
      BigInt(route.sourceChainId),
      bytes32Recipient(wallet.address),
    );
    const burnReceipt = await burnTx.wait(1);
    await mineOneBlock(provider, wallet);

    const scan = await postOk("/withdrawal-watchers/scan", {}, [200]);
    let withdrawal = null;
    for (const item of scan.items || []) {
      for (const queued of item.items || []) {
        if (queued.status && queued.withdrawal_id) {
          const detail = await requestJson(`${bridgeBase}/withdrawals/${queued.withdrawal_id}`);
          if (detail.body?.withdrawal?.burn_tx_hash === burnTx.hash) withdrawal = detail.body.withdrawal;
        }
      }
    }

    if (!withdrawal) {
      const requested = await postOk("/withdrawals/request", {
        route_id: routeId,
        amount_base_units: amount.toString(),
        destination_recipient: wallet.address,
        burn_tx_hash: burnTx.hash,
        proof: {
          mode: "ynx-wallet-burn-transaction",
          approve_tx_hash: approveTx.hash,
          burn_tx_hash: burnTx.hash,
          burn_block_number: burnReceipt.blockNumber,
        },
      });
      withdrawal = requested.withdrawal;
    }

    const released = await postOk(`/withdrawals/${withdrawal.withdrawal_id}/mark-released`, {
      release_tx_hash: releaseTxHash,
      proof: {
        mode: "operator-attested-public-testnet-manual-release",
        source_network: route.sourceNetwork,
        source_asset: route.asset,
        generated_at: new Date().toISOString(),
        note: "Manual public-testnet release record; not a mainnet custody or redemption claim.",
      },
    });

    results.push({
      route_id: routeId,
      deposit_id: deposit.deposit.deposit_id,
      deposit_status: deposit.deposit.status,
      source_tx_hash: sourceTxHash,
      approve_tx_hash: approveTx.hash,
      approve_block_number: approveReceipt.blockNumber,
      burn_tx_hash: burnTx.hash,
      burn_block_number: burnReceipt.blockNumber,
      withdrawal_id: withdrawal.withdrawal_id,
      release_tx_hash: releaseTxHash,
      release_status: released.withdrawal.status,
    });
  }

  console.log(JSON.stringify({ ok: true, wallet: wallet.address, stamp, results }, null, 2));
}

main().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
