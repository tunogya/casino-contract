import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const FourDucks = await ethers.getContractFactory("FourDucks");
  console.log("Upgrade to FourDucks...");
  const fourDucks = await upgrades.upgradeProxy(
    "0x97306f1c9679f5DE1c5223F2b2AC8EFBc5BF6caC",
    FourDucks
  );
  console.log("FourDucks proxy deployed to:", fourDucks.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
