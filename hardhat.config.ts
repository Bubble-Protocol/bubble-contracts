import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-web3";

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  paths: {
    sources: "./contracts",
    // sources: "./test/contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};

export default config;
