import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const Cash = await ethers.getContractFactory("Cash");
  console.log("Deploying Cash...");
  const cash = await upgrades.deployProxy(Cash, {
    initializer: "initialize",
  });
  await cash.deployed();
  console.log("Cash proxy deployed to:", cash.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
