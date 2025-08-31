const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("🚀 Deploying Aetherweb3 Modular Contracts System...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  // Deploy ModularLeader contract
  console.log("\n📋 Deploying ModularLeader...");
  const ModularLeader = await ethers.getContractFactory("ModularLeader");
  const modularLeader = await ModularLeader.deploy();
  await modularLeader.waitForDeployment();
  const modularLeaderAddress = await modularLeader.getAddress();
  console.log("✅ ModularLeader deployed to:", modularLeaderAddress);

  // Deploy example modular contracts
  console.log("\n🔧 Deploying Modular Contracts...");

  // Deploy FeeCollectorModular
  console.log("Deploying FeeCollectorModular...");
  const FeeCollectorModular = await ethers.getContractFactory("FeeCollectorModular");
  const feeRecipient = process.env.FEE_RECIPIENT || deployer.address;
  const feeCollector = await FeeCollectorModular.deploy(modularLeaderAddress, feeRecipient);
  await feeCollector.waitForDeployment();
  const feeCollectorAddress = await feeCollector.getAddress();
  console.log("✅ FeeCollectorModular deployed to:", feeCollectorAddress);

  // Deploy ValidatorModular
  console.log("Deploying ValidatorModular...");
  const ValidatorModular = await ethers.getContractFactory("ValidatorModular");
  const validator = await ValidatorModular.deploy(modularLeaderAddress);
  await validator.waitForDeployment();
  const validatorAddress = await validator.getAddress();
  console.log("✅ ValidatorModular deployed to:", validatorAddress);

  // Deploy LoggerModular
  console.log("Deploying LoggerModular...");
  const LoggerModular = await ethers.getContractFactory("LoggerModular");
  const logger = await LoggerModular.deploy(modularLeaderAddress);
  await logger.waitForDeployment();
  const loggerAddress = await logger.getAddress();
  console.log("✅ LoggerModular deployed to:", loggerAddress);

  // Deploy RewardDistributorModular (requires reward token)
  console.log("Deploying RewardDistributorModular...");
  const rewardToken = process.env.REWARD_TOKEN;
  if (rewardToken) {
    const RewardDistributorModular = await ethers.getContractFactory("RewardDistributorModular");
    const rewardDistributor = await RewardDistributorModular.deploy(modularLeaderAddress, rewardToken);
    await rewardDistributor.waitForDeployment();
    const rewardDistributorAddress = await rewardDistributor.getAddress();
    console.log("✅ RewardDistributorModular deployed to:", rewardDistributorAddress);
  } else {
    console.log("⚠️  RewardDistributorModular skipped - REWARD_TOKEN not set in .env");
  }

  // Configure the ModularLeader with deployed contracts
  console.log("\n⚙️  Configuring ModularLeader...");

  // Create modular slot configurations
  const slots = [
    {
      contractAddress: feeCollectorAddress,
      enabled: true,
      name: "Fee Collector",
      contractType: ethers.keccak256(ethers.toUtf8Bytes("FEE_COLLECTOR"))
    },
    {
      contractAddress: validatorAddress,
      enabled: true,
      name: "Validator",
      contractType: ethers.keccak256(ethers.toUtf8Bytes("VALIDATOR"))
    },
    {
      contractAddress: loggerAddress,
      enabled: true,
      name: "Logger",
      contractType: ethers.keccak256(ethers.toUtf8Bytes("LOGGER"))
    }
  ];

  // If reward distributor was deployed, add it
  if (rewardToken) {
    const RewardDistributorModular = await ethers.getContractFactory("RewardDistributorModular");
    const rewardDistributor = await RewardDistributorModular.attach(rewardDistributorAddress);
    slots.push({
      contractAddress: rewardDistributorAddress,
      enabled: true,
      name: "Reward Distributor",
      contractType: ethers.keccak256(ethers.toUtf8Bytes("REWARD_DISTRIBUTOR"))
    });
  }

  // Initialize the leader contract
  console.log("Initializing ModularLeader with", slots.length, "modular contracts...");
  const initTx = await modularLeader.initialize(slots);
  await initTx.wait();
  console.log("✅ ModularLeader initialized successfully");

  // Configure tuple system
  console.log("\n🎯 Configuring Tuple System...");

  // Enable some tuple hooks
  await modularLeader.setTupleState(2, true); // BEFORE_EXECUTE
  await modularLeader.setTupleState(3, true); // AFTER_EXECUTE

  // Assign contracts to tuple hooks
  await modularLeader.setTupleContract(2, validatorAddress); // BEFORE_EXECUTE -> Validator
  await modularLeader.setTupleContract(3, loggerAddress);   // AFTER_EXECUTE -> Logger

  console.log("✅ Tuple system configured");

  // Display deployment summary
  console.log("\n🎉 Deployment Summary:");
  console.log("======================");
  console.log("ModularLeader:", modularLeaderAddress);
  console.log("FeeCollectorModular:", feeCollectorAddress);
  console.log("ValidatorModular:", validatorAddress);
  console.log("LoggerModular:", loggerAddress);
  if (rewardToken) {
    console.log("RewardDistributorModular:", rewardDistributorAddress);
  }
  console.log("\n📋 Next Steps:");
  console.log("1. Update your frontend to interact with the ModularLeader contract");
  console.log("2. Test the modular contract execution");
  console.log("3. Configure additional tuple hooks as needed");
  console.log("4. Add more modular contracts to the system");

  // Verify contracts on Etherscan (if on mainnet/testnet)
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("\n🔍 Verifying contracts on Etherscan...");
    try {
      await hre.run("verify:verify", {
        address: modularLeaderAddress,
        constructorArguments: [],
      });
      console.log("✅ ModularLeader verified");

      await hre.run("verify:verify", {
        address: feeCollectorAddress,
        constructorArguments: [modularLeaderAddress, feeRecipient],
      });
      console.log("✅ FeeCollectorModular verified");

      await hre.run("verify:verify", {
        address: validatorAddress,
        constructorArguments: [modularLeaderAddress],
      });
      console.log("✅ ValidatorModular verified");

      await hre.run("verify:verify", {
        address: loggerAddress,
        constructorArguments: [modularLeaderAddress],
      });
      console.log("✅ LoggerModular verified");

      if (rewardToken) {
        await hre.run("verify:verify", {
          address: rewardDistributorAddress,
          constructorArguments: [modularLeaderAddress, rewardToken],
        });
        console.log("✅ RewardDistributorModular verified");
      }
    } catch (error) {
      console.log("⚠️  Contract verification failed:", error.message);
    }
  }

  console.log("\n✨ Aetherweb3 Modular Contracts System deployed successfully!");
}

// Handle errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
