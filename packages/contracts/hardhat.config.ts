import hardhatEthersPlugin from "@nomicfoundation/hardhat-ethers";
import hardhatMochaPlugin from "@nomicfoundation/hardhat-mocha";
import { defineConfig } from "hardhat/config";

const DEVNET_MNEMONIC = "test test test test test test test test test test test junk";
// NOTE: Hardhat's node currently defaults to 31337. Keep devnet consistent with that.
// We can change this once the base-chain client exists.
const DEVNET_CHAIN_ID = 31337;

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
      chainId: DEVNET_CHAIN_ID,
      accounts: {
        mnemonic: DEVNET_MNEMONIC,
        accountsBalance: "1000000000000000000000000"
      }
    },
    localhost: {
      type: "http",
      chainType: "l1",
      chainId: DEVNET_CHAIN_ID,
      url: "http://127.0.0.1:8545",
      accounts: {
        mnemonic: DEVNET_MNEMONIC
      }
    }
  },
});
