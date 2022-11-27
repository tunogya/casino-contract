import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const Cash = await ethers.getContractFactory("Cash");
  console.log("Upgrade to Cash...");
  const cash = await upgrades.upgradeProxy(
    "0x14Ce4f38ea40Bb46d65Ed840bff5717E8FAf9Cb2",
    Cash
  );
  console.log("Cash proxy deployed to:", cash.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
