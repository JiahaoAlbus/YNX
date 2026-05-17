import hardhatEthersPlugin from "@nomicfoundation/hardhat-ethers";
import hardhatMochaPlugin from "@nomicfoundation/hardhat-mocha";
import { defineConfig } from "hardhat/config";
import fs from "node:fs";
import path from "node:path";

const DEVNET_MNEMONIC = "test test test test test test test test test test test junk";
// Hardhat local node (simulated EVM) uses 31337 by default.
const HARDHAT_CHAIN_ID = 31337;
// YNX chain local devnet (Cosmos EVM) default EIP-155 chain id.
const YNX_CHAIN_ID = 9001;
const YNX_PUBLIC_CHAIN_ID = 9102;

function loadEnvFile(filePath: string) {
  if (!fs.existsSync(filePath)) return;
  const raw = fs.readFileSync(filePath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadEnvFile(path.resolve(process.cwd(), "../../.env"));
loadEnvFile(path.resolve(process.cwd(), ".env"));

function privateKeyAccounts(): string[] | "remote" {
  const raw =
    process.env.YNX_EVM_PRIVATE_KEY ??
    process.env.EVM_PRIVATE_KEY ??
    process.env.PRIVATE_KEY ??
    "";
  const keys = raw
    .split(",")
    .map((key) => key.trim())
    .filter(Boolean)
    .map((key) => (key.startsWith("0x") ? key : `0x${key}`));
  return keys.length > 0 ? keys : "remote";
}

export default defineConfig({
  plugins: [hardhatEthersPlugin, hardhatMochaPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.24",
        settings: {
          evmVersion: "cancun",
          optimizer: { enabled: true, runs: 200 },
        },
      },
    },
  },
  networks: {
    default: {
      type: "edr-simulated",
      chainType: "l1",
      chainId: HARDHAT_CHAIN_ID,
      accounts: {
        mnemonic: DEVNET_MNEMONIC,
        accountsBalance: "1000000000000000000000000"
      }
    },
    localhost: {
      type: "http",
      chainType: "l1",
      chainId: HARDHAT_CHAIN_ID,
      url: "http://127.0.0.1:8545",
      accounts: {
        mnemonic: DEVNET_MNEMONIC
      }
    },
    ynxdev: {
      type: "http",
      chainType: "l1",
      chainId: YNX_CHAIN_ID,
      url: "http://127.0.0.1:8545",
      accounts: {
        mnemonic: DEVNET_MNEMONIC
      }
    },
    ynxpublic: {
      type: "http",
      chainType: "l1",
      chainId: YNX_PUBLIC_CHAIN_ID,
      url: process.env.YNX_PUBLIC_EVM_RPC_URL ?? "https://evm.ynxweb4.com",
      accounts: privateKeyAccounts(),
      gas: "auto",
      gasPrice: "auto",
    }
  },
});
