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
  const FourDucks = await ethers.getContractFactory("Snatch");
  console.log("Deploying FourDucks...");
  // const fourDucks = await FourDucks.deploy(airnodeRrp);
  // await fourDucks.deployed();
  const fourDucks = await FourDucks.attach(
    "0x3dA52e06A6c7dEff72c9016Aa59a8a9DD702C73C"
  );
  console.log("FourDucks deployed to:", fourDucks.address);
  console.log("You need to get sponsor-address. The code is:");
  // // https://docs.api3.org/qrng/reference/providers.html#airnode
  console.log(`npx @api3/airnode-admin derive-sponsor-wallet-address \
  --airnode-xpub xpub6DXSDTZBd4aPVXnv6Q3SmnGUweFv6j24SK77W4qrSFuhGgi666awUiXakjXruUSCDQhhctVG7AQt67gMdaRAsDnDXv23bBRKsMWvRzo6kbf \
  --airnode-address 0x9d3C147cA16DB954873A498e0af5852AB39139f2 \
  --sponsor-address ${fourDucks.address}`);

  // await fourDucks.setRequestParameters(
  //   "0x9d3C147cA16DB954873A498e0af5852AB39139f2",
  //   "0xfb6d017bb87991b7495f563db3c8cf59ff87b09781947bb1e417006ad7f55a78",
  //   "0xfa364e2014D3Ce9cae4E321F0E4ce3a4c8f2b306"
  // );
  console.log("setRequestParameters done");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
