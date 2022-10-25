import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const SnatchV2 = await ethers.getContractFactory("SnatchV2");
  console.log("Upgrade to SnatchV2...");
  const snatchV2 = await upgrades.upgradeProxy(
    "0x39e55b5E450b4e18d993B446C83086423e2E93F0",
    SnatchV2
  );
  await snatchV2.deployed();
  console.log("Snatch proxy deployed to:", snatchV2.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
