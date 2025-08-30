const { run } = require("hardhat");

async function main() {
  const network = process.env.HARDHAT_NETWORK || "hardhat";

  console.log(`Verifying Aetherweb3TokenCreator on ${network}...`);

  // Get the deployed contract address from environment or deployment file
  const contractAddress = process.env.TOKEN_CREATOR_ADDRESS;

  if (!contractAddress) {
    console.error("Please set TOKEN_CREATOR_ADDRESS environment variable");
    process.exit(1);
  }

  // Get the fee recipient address
  const feeRecipient = process.env.FEE_RECIPIENT || "0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57";

  try {
    console.log(`Verifying contract at: ${contractAddress}`);
    console.log(`Fee recipient: ${feeRecipient}`);

    // Verify the contract
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [feeRecipient],
      contract: "contracts/Aetherweb3TokenCreator.sol:Aetherweb3TokenCreator",
    });

    console.log("✅ Contract verification successful!");
    console.log(`View on explorer: ${getExplorerUrl(network, contractAddress)}`);

  } catch (error) {
    console.error("❌ Contract verification failed:", error.message);

    // If verification fails, try with different compiler settings
    console.log("🔄 Retrying with different compiler settings...");

    try {
      await run("verify:verify", {
        address: contractAddress,
        constructorArguments: [feeRecipient],
        contract: "contracts/Aetherweb3TokenCreator.sol:Aetherweb3TokenCreator",
        optimizer: {
          enabled: true,
          runs: 200,
        },
      });

      console.log("✅ Contract verification successful on retry!");
      console.log(`View on explorer: ${getExplorerUrl(network, contractAddress)}`);

    } catch (retryError) {
      console.error("❌ Contract verification failed on retry:", retryError.message);
      console.log("\n🔧 Troubleshooting tips:");
      console.log("1. Make sure the contract is deployed and confirmed");
      console.log("2. Check that the API key is set correctly");
      console.log("3. Verify the constructor arguments are correct");
      console.log("4. Try running verification manually with the correct parameters");
      process.exit(1);
    }
  }
}

function getExplorerUrl(network, address) {
  const explorers = {
    mainnet: `https://etherscan.io/address/${address}`,
    sepolia: `https://sepolia.etherscan.io/address/${address}`,
    goerli: `https://goerli.etherscan.io/address/${address}`,
    polygon: `https://polygonscan.com/address/${address}`,
    polygonMumbai: `https://mumbai.polygonscan.com/address/${address}`,
    bsc: `https://bscscan.com/address/${address}`,
    bscTestnet: `https://testnet.bscscan.com/address/${address}`,
    arbitrum: `https://arbiscan.io/address/${address}`,
    arbitrumGoerli: `https://goerli.arbiscan.io/address/${address}`,
    optimism: `https://optimistic.etherscan.io/address/${address}`,
    optimismGoerli: `https://goerli-optimism.etherscan.io/address/${address}`,
    avalanche: `https://snowtrace.io/address/${address}`,
    avalancheFuji: `https://testnet.snowtrace.io/address/${address}`,
    fantom: `https://ftmscan.com/address/${address}`,
    fantomTestnet: `https://testnet.ftmscan.com/address/${address}`,
  };

  return explorers[network] || `https://etherscan.io/address/${address}`;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
