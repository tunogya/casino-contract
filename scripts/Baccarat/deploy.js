const { ethers, upgrades } = require("hardhat");

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const Baccarat = await ethers.getContractFactory("Baccarat");
  console.log("Deploying Baccarat...");
  const baccarat = await upgrades.deployProxy(Baccarat, {
    initializer: "initialize",
  });
  await baccarat.deployed();
  console.log("Baccarat proxy deployed to:", baccarat.address);
}

main();
