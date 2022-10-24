import { ethers, upgrades } from "hardhat";

const AirnodeRrpV0: Record<number, string> = {
  5: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  1: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  42161: "0xb015ACeEdD478fc497A798Ab45fcED8BdEd08924",
  43114: "0xC02Ea0f403d5f3D45a4F1d0d817e7A2601346c9E",
  56: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  250: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  100: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  1088: "0xC02Ea0f403d5f3D45a4F1d0d817e7A2601346c9E",
  2001: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  1284: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  1285: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  10: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  137: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
  30: "0xa0AD79D995DdeeB18a14eAef56A549A04e3Aa1Bd",
};

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId;
  console.log("Chain ID:", chainId);
  const gas = await ethers.provider.getGasPrice();
  console.log("Gas price:", gas.toString());
  const airnodeRrp = AirnodeRrpV0[chainId];
  console.log("AirnodeRrpV0:", airnodeRrp);
  const FourDucksV1 = await ethers.getContractFactory("FourDucksV1");
  console.log("Deploying FourDucksV1...");
  const fourDucksV1 = await upgrades.deployProxy(FourDucksV1, [airnodeRrp], {
    initializer: "initialize",
  });
  await fourDucksV1.deployed();
  console.log("FourDucks proxy deployed to:", fourDucksV1.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
