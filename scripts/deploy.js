const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Aetherweb3 PoolFactory...");

  // Deploy PoolDeployer first
  const PoolDeployer = await ethers.getContractFactory("Aetherweb3PoolDeployer");
  const poolDeployer = await PoolDeployer.deploy();
  await poolDeployer.deployed();
  console.log("PoolDeployer deployed to:", poolDeployer.address);

  // Deploy Factory with PoolDeployer address
  const Factory = await ethers.getContractFactory("Aetherweb3Factory");
  const factory = await Factory.deploy(poolDeployer.address);
  await factory.deployed();
  console.log("Aetherweb3Factory deployed to:", factory.address);

  // Set factory address in PoolDeployer
  await poolDeployer.setFactoryAddress(factory.address);
  console.log("Factory address set in PoolDeployer");

  console.log("Deployment complete!");
  console.log("Factory address:", factory.address);
  console.log("PoolDeployer address:", poolDeployer.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
