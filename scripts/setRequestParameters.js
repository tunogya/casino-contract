import { ethers } from "hardhat";

// https://docs.api3.org/qrng/reference/providers.html#airnode
// npx @api3/airnode-admin derive-sponsor-wallet-address \
//   --airnode-xpub xpub6DXSDTZBd4aPVXnv6Q3SmnGUweFv6j24SK77W4qrSFuhGgi666awUiXakjXruUSCDQhhctVG7AQt67gMdaRAsDnDXv23bBRKsMWvRzo6kbf \
//   --airnode-address 0x9d3C147cA16DB954873A498e0af5852AB39139f2 \
//   --sponsor-address <use-the-address-of: RemixQrngExample.sol>
async function setRequestParameters() {
  const _airnode = "0x9d3C147cA16DB954873A498e0af5852AB39139f2";
  const _endpointIdUint256 =
    "0xfb6d017bb87991b7495f563db3c8cf59ff87b09781947bb1e417006ad7f55a78";
  const _endpointIdUint256Array =
    "0x27cc2713e7f968e4e86ed274a051a5c8aaee9cca66946f23af6f29ecea9704c3";
  const _sponsorWallet = "0xB6825f3f4C6617cCD79F87d325Fff9Cdb85Db405";
  const Snatch = await ethers.getContractFactory("Snatch");
  const snatch = await Snatch.attach(
    "0xDb9a5821BC58Bf04b6A5961179ec5ac7985c6Cfd"
  );
  await snatch.setRequestParameters(
    _airnode,
    _endpointIdUint256,
    _endpointIdUint256Array,
    _sponsorWallet
  );
}

setRequestParameters().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
