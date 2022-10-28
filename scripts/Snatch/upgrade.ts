import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const Snatch = await ethers.getContractFactory("Snatch");
  console.log("Upgrade to Snatch...");
  const snatch = await upgrades.upgradeProxy(
    "",
    Snatch
  );
  console.log("Snatch proxy deployed to:", snatch.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
