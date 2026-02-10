import hardhatEthersPlugin from "@nomicfoundation/hardhat-ethers";
import hardhatMochaPlugin from "@nomicfoundation/hardhat-mocha";
import { defineConfig } from "hardhat/config";

const DEVNET_MNEMONIC = "test test test test test test test test test test test junk";
// Hardhat local node (simulated EVM) uses 31337 by default.
const HARDHAT_CHAIN_ID = 31337;
// YNX chain local devnet (Cosmos EVM) default EIP-155 chain id.
const YNX_CHAIN_ID = 9001;

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
    }
  },
});
