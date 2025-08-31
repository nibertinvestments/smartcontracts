const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying Complete Modular Contracts System...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);

  // Deploy all modular contracts
  console.log("📦 Deploying FeeCollectorModular...");
  const FeeCollectorModular = await ethers.getContractFactory("FeeCollectorModular");
  const feeCollector = await FeeCollectorModular.deploy();
  await feeCollector.waitForDeployment();
  console.log("✅ FeeCollectorModular deployed to:", await feeCollector.getAddress());

  console.log("📦 Deploying ValidatorModular...");
  const ValidatorModular = await ethers.getContractFactory("ValidatorModular");
  const validator = await ValidatorModular.deploy();
  await validator.waitForDeployment();
  console.log("✅ ValidatorModular deployed to:", await validator.getAddress());

  console.log("📦 Deploying LoggerModular...");
  const LoggerModular = await ethers.getContractFactory("LoggerModular");
  const logger = await LoggerModular.deploy();
  await logger.waitForDeployment();
  console.log("✅ LoggerModular deployed to:", await logger.getAddress());

  console.log("📦 Deploying RewardDistributorModular...");
  const RewardDistributorModular = await ethers.getContractFactory("RewardDistributorModular");
  const rewardDistributor = await RewardDistributorModular.deploy();
  await rewardDistributor.waitForDeployment();
  console.log("✅ RewardDistributorModular deployed to:", await rewardDistributor.getAddress());

  console.log("📦 Deploying DynamicFeeModular...");
  const DynamicFeeModular = await ethers.getContractFactory("DynamicFeeModular");
  const dynamicFee = await DynamicFeeModular.deploy();
  await dynamicFee.waitForDeployment();
  console.log("✅ DynamicFeeModular deployed to:", await dynamicFee.getAddress());

  console.log("📦 Deploying MEVProtectionModular...");
  const MEVProtectionModular = await ethers.getContractFactory("MEVProtectionModular");
  const mevProtection = await MEVProtectionModular.deploy();
  await mevProtection.waitForDeployment();
  console.log("✅ MEVProtectionModular deployed to:", await mevProtection.getAddress());

  console.log("📦 Deploying SwapLogicModular...");
  const SwapLogicModular = await ethers.getContractFactory("SwapLogicModular");
  const swapLogic = await SwapLogicModular.deploy();
  await swapLogic.waitForDeployment();
  console.log("✅ SwapLogicModular deployed to:", await swapLogic.getAddress());

  console.log("📦 Deploying AccessControlModular...");
  const AccessControlModular = await ethers.getContractFactory("AccessControlModular");
  const accessControl = await AccessControlModular.deploy();
  await accessControl.waitForDeployment();
  console.log("✅ AccessControlModular deployed to:", await accessControl.getAddress());

  console.log("📦 Deploying EmergencyModular...");
  const EmergencyModular = await ethers.getContractFactory("EmergencyModular");
  const emergency = await EmergencyModular.deploy();
  await emergency.waitForDeployment();
  console.log("✅ EmergencyModular deployed to:", await emergency.getAddress());

  console.log("📦 Deploying OracleModular...");
  const OracleModular = await ethers.getContractFactory("OracleModular");
  const oracle = await OracleModular.deploy();
  await oracle.waitForDeployment();
  console.log("✅ OracleModular deployed to:", await oracle.getAddress());

  console.log("📦 Deploying TreasuryModular...");
  const TreasuryModular = await ethers.getContractFactory("TreasuryModular");
  const treasury = await TreasuryModular.deploy();
  await treasury.waitForDeployment();
  console.log("✅ TreasuryModular deployed to:", await treasury.getAddress());

  console.log("📦 Deploying StakingModular...");
  const StakingModular = await ethers.getContractFactory("StakingModular");
  const staking = await StakingModular.deploy();
  await staking.waitForDeployment();
  console.log("✅ StakingModular deployed to:", await staking.getAddress());

  console.log("📦 Deploying GovernanceModular...");
  const GovernanceModular = await ethers.getContractFactory("GovernanceModular");
  const governance = await GovernanceModular.deploy();
  await governance.waitForDeployment();
  console.log("✅ GovernanceModular deployed to:", await governance.getAddress());

  // Deploy leader contract
  console.log("📦 Deploying ModularLeader...");
  const ModularLeader = await ethers.getContractFactory("ModularLeader");
  const leader = await ModularLeader.deploy();
  await leader.waitForDeployment();
  console.log("✅ ModularLeader deployed to:", await leader.getAddress());

  // Configure the leader contract
  console.log("⚙️  Configuring ModularLeader with all contracts...");

  // Register all modular contracts in leader slots
  await leader.setContractSlot(0, await feeCollector.getAddress(), true);
  console.log("   Slot 0: FeeCollector registered");

  await leader.setContractSlot(1, await validator.getAddress(), true);
  console.log("   Slot 1: Validator registered");

  await leader.setContractSlot(2, await logger.getAddress(), true);
  console.log("   Slot 2: Logger registered");

  await leader.setContractSlot(3, await rewardDistributor.getAddress(), true);
  console.log("   Slot 3: RewardDistributor registered");

  await leader.setContractSlot(4, await dynamicFee.getAddress(), true);
  console.log("   Slot 4: DynamicFee registered");

  await leader.setContractSlot(5, await mevProtection.getAddress(), true);
  console.log("   Slot 5: MEVProtection registered");

  await leader.setContractSlot(6, await swapLogic.getAddress(), true);
  console.log("   Slot 6: SwapLogic registered");

  await leader.setContractSlot(7, await accessControl.getAddress(), true);
  console.log("   Slot 7: AccessControl registered");

  await leader.setContractSlot(8, await emergency.getAddress(), true);
  console.log("   Slot 8: Emergency registered");

  await leader.setContractSlot(9, await oracle.getAddress(), true);
  console.log("   Slot 9: Oracle registered");

  await leader.setContractSlot(10, await treasury.getAddress(), true);
  console.log("   Slot 10: Treasury registered");

  await leader.setContractSlot(11, await staking.getAddress(), true);
  console.log("   Slot 11: Staking registered");

  await leader.setContractSlot(12, await governance.getAddress(), true);
  console.log("   Slot 12: Governance registered");

  // Transfer ownership of all modular contracts to leader
  console.log("🔐 Transferring ownership to ModularLeader...");
  await feeCollector.transferOwnership(await leader.getAddress());
  await validator.transferOwnership(await leader.getAddress());
  await logger.transferOwnership(await leader.getAddress());
  await rewardDistributor.transferOwnership(await leader.getAddress());
  await dynamicFee.transferOwnership(await leader.getAddress());
  await mevProtection.transferOwnership(await leader.getAddress());
  await swapLogic.transferOwnership(await leader.getAddress());
  await accessControl.transferOwnership(await leader.getAddress());
  await emergency.transferOwnership(await leader.getAddress());
  await oracle.transferOwnership(await leader.getAddress());
  await treasury.transferOwnership(await leader.getAddress());
  await staking.transferOwnership(await leader.getAddress());
  await governance.transferOwnership(await leader.getAddress());
  console.log("   Ownership transferred to ModularLeader");

  // Deploy test contract
  console.log("📦 Deploying ModularContractsTest...");
  const ModularContractsTest = await ethers.getContractFactory("ModularContractsTest");
  const testContract = await ModularContractsTest.deploy();
  await testContract.waitForDeployment();
  console.log("✅ ModularContractsTest deployed to:", await testContract.getAddress());

  console.log("\n🎉 Complete Modular Contracts System deployed successfully!");
  console.log("📋 Contract Addresses:");
  console.log("   ModularLeader:", await leader.getAddress());
  console.log("   FeeCollectorModular:", await feeCollector.getAddress());
  console.log("   ValidatorModular:", await validator.getAddress());
  console.log("   LoggerModular:", await logger.getAddress());
  console.log("   RewardDistributorModular:", await rewardDistributor.getAddress());
  console.log("   DynamicFeeModular:", await dynamicFee.getAddress());
  console.log("   MEVProtectionModular:", await mevProtection.getAddress());
  console.log("   SwapLogicModular:", await swapLogic.getAddress());
  console.log("   AccessControlModular:", await accessControl.getAddress());
  console.log("   EmergencyModular:", await emergency.getAddress());
  console.log("   OracleModular:", await oracle.getAddress());
  console.log("   TreasuryModular:", await treasury.getAddress());
  console.log("   StakingModular:", await staking.getAddress());
  console.log("   GovernanceModular:", await governance.getAddress());
  console.log("   ModularContractsTest:", await testContract.getAddress());

  // Run tests
  console.log("\n🧪 Running comprehensive tests...");
  try {
    const tx = await testContract.testModularSystem();
    await tx.wait();
    console.log("✅ All tests passed!");
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }

  console.log("\n🚀 Modular Contracts System is ready for production use!");
  console.log("💡 Next steps:");
  console.log("   1. Configure contract parameters for your specific use case");
  console.log("   2. Set up price feeds for OracleModular");
  console.log("   3. Configure access control roles");
  console.log("   4. Test integration with your existing systems");
  console.log("   5. Deploy to mainnet when ready");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });
