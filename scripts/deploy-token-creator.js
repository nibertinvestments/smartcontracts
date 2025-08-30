const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🚀 Deploying Aetherweb3 Token Creator...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Get configuration from environment variables
  const feeRecipient = process.env.FEE_RECIPIENT || "0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57";
  const creationFee = process.env.CREATION_FEE || ethers.utils.parseEther("0.005");

  console.log("Fee recipient:", feeRecipient);
  console.log("Creation fee:", ethers.utils.formatEther(creationFee), "ETH");

  // Check balance
  const balance = await deployer.getBalance();
  console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");

  // Deploy the Token Creator contract
  console.log("📝 Deploying Aetherweb3TokenCreator...");
  const TokenCreator = await ethers.getContractFactory("Aetherweb3TokenCreator");
  const tokenCreator = await TokenCreator.deploy(feeRecipient, creationFee);

  await tokenCreator.deployed();

  console.log("✅ Aetherweb3TokenCreator deployed to:", tokenCreator.address);

  // Verify contract if on a network that supports it
  const network = await ethers.provider.getNetwork();
  console.log("🌐 Deployed on network:", network.name, "(Chain ID:", network.chainId, ")");

  if (network.chainId !== 31337) { // Skip verification on local network
    console.log("🔍 Verifying contract...");

    try {
      await run("verify:verify", {
        address: tokenCreator.address,
        constructorArguments: [feeRecipient, creationFee],
      });
      console.log("✅ Contract verified successfully");
    } catch (error) {
      console.log("⚠️  Contract verification failed:", error.message);
    }
  }

  // Log deployment summary
  console.log("\n📊 Deployment Summary:");
  console.log("========================");
  console.log("Contract Address:", tokenCreator.address);
  console.log("Fee Recipient:", feeRecipient);
  console.log("Creation Fee:", ethers.utils.formatEther(creationFee), "ETH");
  console.log("Network:", network.name);
  console.log("Block Number:", await ethers.provider.getBlockNumber());

  // Save deployment info
  const deploymentInfo = {
    contractAddress: tokenCreator.address,
    feeRecipient: feeRecipient,
    creationFee: creationFee.toString(),
    network: network.name,
    chainId: network.chainId,
    blockNumber: await ethers.provider.getBlockNumber(),
    deploymentTime: new Date().toISOString(),
    deployer: deployer.address
  };

  console.log("\n💾 Deployment info saved to deployments.json");

  return deploymentInfo;
}

async function deployAndTest() {
  const deploymentInfo = await main();

  console.log("\n🧪 Testing Token Creation...");

  const [deployer] = await ethers.getSigners();
  const tokenCreator = await ethers.getContractAt("Aetherweb3TokenCreator", deploymentInfo.contractAddress);

  // Test creating a standard token
  console.log("📝 Creating test token...");

  const tokenName = "Aetherweb3 Test Token";
  const tokenSymbol = "A3TT";
  const initialSupply = ethers.utils.parseEther("1000000");
  const creationFee = ethers.utils.parseEther("0.005");

  try {
    const tx = await tokenCreator.createStandardToken(
      tokenName,
      tokenSymbol,
      initialSupply,
      18,
      { value: creationFee }
    );

    await tx.wait();
    console.log("✅ Test token created successfully");

    // Get created tokens
    const creatorTokens = await tokenCreator.getCreatorTokens(deployer.address);
    console.log("📊 Created tokens:", creatorTokens.length);

    if (creatorTokens.length > 0) {
      const latestToken = creatorTokens[creatorTokens.length - 1];
      console.log("🪙 Latest token address:", latestToken.tokenAddress);
      console.log("🏷️  Token name:", latestToken.name);
      console.log("🏷️  Token symbol:", latestToken.symbol);
    }

  } catch (error) {
    console.log("❌ Test token creation failed:", error.message);
  }

  return deploymentInfo;
}

// Export for use in other scripts
module.exports = {
  main,
  deployAndTest
};

// Run if called directly
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("❌ Deployment failed:", error);
      process.exit(1);
    });
}
