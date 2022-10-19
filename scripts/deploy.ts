import { ethers } from "hardhat";

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
  const airnodeRrp = AirnodeRrpV0[chainId];
  console.log("AirnodeRrpV0:", airnodeRrp);
  const Snatch = await ethers.getContractFactory("Snatch");
  const snatcher = await Snatch.deploy(airnodeRrp);
  await snatcher.deployed();
  // const snatcher = await Snatch.attach(
  //   ""
  // );
  console.log("Snatch deployed to:", snatcher.address);
  console.log("You need to get sponsor-address. The code is:");
  // https://docs.api3.org/qrng/reference/providers.html#airnode
  // console.log(`npx @api3/airnode-admin derive-sponsor-wallet-address \
  // --airnode-xpub xpub6DXSDTZBd4aPVXnv6Q3SmnGUweFv6j24SK77W4qrSFuhGgi666awUiXakjXruUSCDQhhctVG7AQt67gMdaRAsDnDXv23bBRKsMWvRzo6kbf \
  // --airnode-address 0x9d3C147cA16DB954873A498e0af5852AB39139f2 \
  // --sponsor-address ${snatcher.address}`);
  // console.log("You need to set setRequestParameters");
  const WUSD = await ethers.getContractFactory("WakandaUSD");
  const wusd = await WUSD.attach("0xDfcBBb16FeEB9dD9cE3870f6049bD11d28390FbF");
  console.log("WUSD deployed to:", wusd.address);
  const Diamond = await ethers.getContractFactory("Diamond");
  const diamond = await Diamond.attach(
    "0xDc5f81Ffa28761Fb5305072043EbF629A5c12351"
  );
  console.log("Diamond deployed to:", diamond.address);
  await snatcher.createPool({
    paymentToken: wusd.address,
    singleDrawPrice: ethers.utils.parseEther("60"),
    batchDrawPrice: ethers.utils.parseEther("270"),
    batchDrawSize: 5,
    rarePrizeToken: diamond.address,
    rarePrizeInitRate: ethers.utils.parseEther("0.00001"),
    rarePrizeAvgRate: ethers.utils.parseEther("0.008"),
    rarePrizeValue: ethers.utils.parseEther("1"),
    rarePrizeMaxRP: 200,
    normalPrizesToken: [wusd.address, wusd.address, wusd.address],
    normalPrizesValue: [
      ethers.utils.parseEther("10"),
      ethers.utils.parseEther("20"),
      ethers.utils.parseEther("30"),
    ],
    normalPrizesRate: [
      ethers.utils.parseEther("0.4"),
      ethers.utils.parseEther("0.2"),
      ethers.utils.parseEther("0.1"),
    ],
  });
  // console.log("createPool done");
  await wusd.approve(snatcher.address, ethers.constants.MaxUint256);
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
