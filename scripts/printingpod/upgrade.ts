import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const PrintingPod = await ethers.getContractFactory("PrintingPod");
  console.log("Upgrade to PrintingPod...");
  const printingpod = await upgrades.upgradeProxy(
    "0x63d4b961BF4668cE9C41a9dC3d96b3e69a4fb517",
    PrintingPod
  );
  console.log("PrintingPod proxy deployed to:", printingpod.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
