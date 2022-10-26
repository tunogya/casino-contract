import { ethers, upgrades } from "hardhat";

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const FourDucksV2 = await ethers.getContractFactory("FourDucksV2");
  console.log("Upgrade to FourDucksV2...");
  const fourDucks = await upgrades.upgradeProxy(
    "0x100a14Fd9F79EcC5AEFcDbbec1e6Fd0FA2a48A02",
    FourDucksV2
  );
  console.log("FourDucks proxy deployed to:", fourDucks.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
