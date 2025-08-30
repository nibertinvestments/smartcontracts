const { ethers } = require("hardhat");

async function estimateGas() {
  console.log("Estimating gas costs for Aetherweb3 deployment...\n");

  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", deployer.address);
  console.log("Deployer balance:", ethers.utils.formatEther(await deployer.getBalance()), "ETH\n");

  // Estimate PoolDeployer deployment
  const PoolDeployer = await ethers.getContractFactory("Aetherweb3PoolDeployer");
  const poolDeployerGas = await PoolDeployer.signer.estimateGas(
    PoolDeployer.getDeployTransaction()
  );
  console.log("PoolDeployer deployment gas:", poolDeployerGas.toString());

  // Deploy PoolDeployer to get its address for Factory estimation
  const poolDeployer = await PoolDeployer.deploy();
  await poolDeployer.deployed();
  console.log("PoolDeployer deployed at:", poolDeployer.address);

  // Estimate Factory deployment
  const Factory = await ethers.getContractFactory("Aetherweb3Factory");
  const factoryGas = await Factory.signer.estimateGas(
    Factory.getDeployTransaction(poolDeployer.address)
  );
  console.log("Factory deployment gas:", factoryGas.toString());

  // Estimate Token deployment
  const Token = await ethers.getContractFactory("Aetherweb3Token");
  const initialSupply = ethers.utils.parseEther("1000000");
  const tokenGas = await Token.signer.estimateGas(
    Token.getDeployTransaction(initialSupply)
  );
  console.log("Token deployment gas:", tokenGas.toString());

  // Calculate totals
  const totalGas = poolDeployerGas.add(factoryGas).add(tokenGas);
  const gasPrice = await ethers.provider.getGasPrice();
  const totalCost = totalGas.mul(gasPrice);

  console.log("\n--- Gas Estimation Summary ---");
  console.log("Total gas units:", totalGas.toString());
  console.log("Gas price:", ethers.utils.formatUnits(gasPrice, "gwei"), "gwei");
  console.log("Estimated cost:", ethers.utils.formatEther(totalCost), "ETH");

  // Current ETH price approximation (you might want to fetch real price)
  const ethPriceUSD = 3000; // Update with current price
  const totalCostUSD = parseFloat(ethers.utils.formatEther(totalCost)) * ethPriceUSD;
  console.log("Estimated cost (USD):", totalCostUSD.toFixed(2), "USD");

  console.log("\n⚠️  Note: Actual costs may vary based on network congestion and gas price fluctuations");
  console.log("💡 Consider deploying during off-peak hours for lower gas costs");
}

async function main() {
  await estimateGas();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
