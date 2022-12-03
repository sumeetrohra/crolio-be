// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
require("@nomiclabs/hardhat-etherscan");
require("dotenv");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  // console.log("Account balance:", (await deployer.getBalance()).toString());

  // const Token = await ethers.getContractFactory("Crolio");
  // const token = await Token.deploy(
  //   "0xE592427A0AEce92De3Edee1F18E0157C05861564",
  //   "0xD62F04191C827667dF606Ca57BBE9B7fF2206087"
  // );
  // await token.wait;
  // console.log("Token address:", token.address);

  await hre.run("verify:verify", {
    address: "0x7717F536d5a2cB738586AF30bD588F3F8954DE7a",
    contract: "contracts/Crolio.sol:Crolio",
    constructorArguments: [
      "0xE592427A0AEce92De3Edee1F18E0157C05861564",
      "0xD62F04191C827667dF606Ca57BBE9B7fF2206087",
    ],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// fUSDC: 0xD62F04191C827667dF606Ca57BBE9B7fF2206087
// fDAI: 0xF285239F96c444AC2EB262269840477DDf1Df765
// fBTC: 0xc0D21266BE0f6524ae5C69D7B824F73338e25448
// fETH: 0x7ED4d01ad78ADa738CA03b6279BDcCC1c89c75fF

// Uniswap swaprouter: https://mumbai.polygonscan.com/address/0xE592427A0AEce92De3Edee1F18E0157C05861564#code

// Crolio: 0x7717F536d5a2cB738586AF30bD588F3F8954DE7a
