const { ethers } = require("hardhat");

async function verifyContracts() {
  console.log("Verifying Aetherweb3 contracts...");

  // Contract addresses (update these after deployment)
  const FACTORY_ADDRESS = "0x..."; // Update with actual address
  const POOL_DEPLOYER_ADDRESS = "0x..."; // Update with actual address
  const TOKEN_ADDRESS = "0x..."; // Update with actual address

  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name, "Chain ID:", network.chainId);

  try {
    // Verify Factory contract
    console.log("Verifying Aetherweb3Factory...");
    await hre.run("verify:verify", {
      address: FACTORY_ADDRESS,
      constructorArguments: [POOL_DEPLOYER_ADDRESS],
    });
    console.log("✅ Aetherweb3Factory verified");

    // Verify PoolDeployer contract
    console.log("Verifying Aetherweb3PoolDeployer...");
    await hre.run("verify:verify", {
      address: POOL_DEPLOYER_ADDRESS,
      constructorArguments: [],
    });
    console.log("✅ Aetherweb3PoolDeployer verified");

    // Verify Token contract (if deployed separately)
    if (TOKEN_ADDRESS !== "0x...") {
      console.log("Verifying Aetherweb3Token...");
      await hre.run("verify:verify", {
        address: TOKEN_ADDRESS,
        constructorArguments: [ethers.utils.parseEther("1000000")], // Update with actual supply
      });
      console.log("✅ Aetherweb3Token verified");
    }

    console.log("🎉 All contracts verified successfully!");
  } catch (error) {
    console.error("❌ Verification failed:", error.message);
  }
}

async function main() {
  await verifyContracts();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
