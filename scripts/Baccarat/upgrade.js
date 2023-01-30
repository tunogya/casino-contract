const { ethers, upgrades } = require("hardhat");

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const Baccarat = await ethers.getContractFactory("Baccarat");
  console.log("Upgrade to Baccarat...");
  const baccarat = await upgrades.upgradeProxy(
    "0xda10F7A4DC8ffaa45E4F2C5e4265f3F156A0f8A4",
    Baccarat
  );
  console.log("Baccarat proxy deployed to:", baccarat.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
