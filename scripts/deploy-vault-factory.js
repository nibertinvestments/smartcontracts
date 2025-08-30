const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Deployment script for Aetherweb3VaultFactory
 */
async function main() {
    console.log("Starting Aetherweb3VaultFactory deployment...");

    // Get signers
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    // Check balance
    const balance = await deployer.getBalance();
    console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");

    // Get network
    const network = await ethers.provider.getNetwork();
    console.log("Network:", network.name, "(Chain ID:", network.chainId, ")");

    // Configuration
    const config = {
        feeRecipient: deployer.address, // Default to deployer, can be changed later
        creationFee: ethers.utils.parseEther("0.01"), // 0.01 ETH creation fee
    };

    console.log("Configuration:");
    console.log("- Fee Recipient:", config.feeRecipient);
    console.log("- Creation Fee:", ethers.utils.formatEther(config.creationFee), "ETH");

    // Deploy Vault Factory
    console.log("\nDeploying Aetherweb3VaultFactory...");
    const VaultFactory = await ethers.getContractFactory("Aetherweb3VaultFactory");
    const factory = await VaultFactory.deploy(config.feeRecipient);

    console.log("Waiting for deployment...");
    await factory.deployed();

    console.log("✅ Aetherweb3VaultFactory deployed to:", factory.address);

    // Set creation fee if different from default
    if (config.creationFee.gt(0)) {
        console.log("\nSetting creation fee...");
        const setFeeTx = await factory.setCreationFee(config.creationFee);
        await setFeeTx.wait();
        console.log("✅ Creation fee set to:", ethers.utils.formatEther(config.creationFee), "ETH");
    }

    // Verify deployment
    console.log("\nVerifying deployment...");
    const feeRecipient = await factory.feeRecipient();
    const creationFee = await factory.creationFee();
    const isPaused = await factory.isPaused();
    const vaultCount = await factory.getVaultCount();

    console.log("Verification Results:");
    console.log("- Fee Recipient:", feeRecipient);
    console.log("- Creation Fee:", ethers.utils.formatEther(creationFee), "ETH");
    console.log("- Is Paused:", isPaused);
    console.log("- Initial Vault Count:", vaultCount.toString());

    // Save deployment info
    const deploymentInfo = {
        network: network.name,
        chainId: network.chainId,
        deployer: deployer.address,
        contract: {
            name: "Aetherweb3VaultFactory",
            address: factory.address,
            feeRecipient: feeRecipient,
            creationFee: creationFee.toString(),
            isPaused: isPaused,
            vaultCount: vaultCount.toString()
        },
        config: config,
        deploymentTime: new Date().toISOString(),
        blockNumber: await ethers.provider.getBlockNumber()
    };

    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.join(__dirname, "../deployments");
    if (!fs.existsSync(deploymentsDir)) {
        fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    // Save deployment info
    const deploymentFile = path.join(deploymentsDir, `vault-factory-${network.name}.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
    console.log("✅ Deployment info saved to:", deploymentFile);

    // Display next steps
    console.log("\n🎉 Deployment completed successfully!");
    console.log("\nNext Steps:");
    console.log("1. Update fee recipient if needed:");
    console.log(`   factory.setFeeRecipient(newRecipientAddress)`);
    console.log("2. Test vault creation:");
    console.log(`   factory.createVault(vaultParams, { value: creationFee })`);
    console.log("3. Verify contract on block explorer");
    console.log("4. Update frontend with factory address");

    return {
        factory: factory.address,
        deploymentInfo
    };
}

/**
 * Test vault creation after deployment
 */
async function testVaultCreation(factoryAddress) {
    console.log("\n🧪 Testing vault creation...");

    const [tester] = await ethers.getSigners();
    const factory = await ethers.getContractAt("Aetherweb3VaultFactory", factoryAddress);

    // Mock token addresses (replace with actual addresses)
    const mockStakingToken = "0x0000000000000000000000000000000000000001";
    const mockRewardToken = "0x0000000000000000000000000000000000000002";
    const mockDAO = "0x0000000000000000000000000000000000000003";

    const vaultParams = {
        stakingToken: mockStakingToken,
        rewardToken: mockRewardToken,
        dao: mockDAO,
        rewardRate: ethers.utils.parseEther("1"),
        emergencyPenalty: 1000, // 10%
        name: "Test Vault",
        symbol: "TEST-VAULT"
    };

    const creationFee = await factory.creationFee();

    try {
        console.log("Creating test vault...");
        const tx = await factory.createVault(vaultParams, { value: creationFee });
        const receipt = await tx.wait();

        const vaultCreatedEvent = receipt.events.find(e => e.event === 'VaultCreated');
        const vaultAddress = vaultCreatedEvent.args.vault;

        console.log("✅ Test vault created at:", vaultAddress);

        // Verify vault info
        const [params, creator] = await factory.getVaultInfo(vaultAddress);
        console.log("- Creator:", creator);
        console.log("- Staking Token:", params.stakingToken);
        console.log("- Reward Token:", params.rewardToken);
        console.log("- Reward Rate:", ethers.utils.formatEther(params.rewardRate), "tokens/sec");

        return vaultAddress;
    } catch (error) {
        console.log("❌ Test vault creation failed:", error.message);
        console.log("Note: This is expected if using mock addresses");
    }
}

/**
 * Batch deployment example
 */
async function deployMultipleVaults(factoryAddress) {
    console.log("\n📦 Testing batch vault deployment...");

    const factory = await ethers.getContractAt("Aetherweb3VaultFactory", factoryAddress);

    // Example vault configurations
    const vaultConfigs = [
        {
            stakingToken: "0x0000000000000000000000000000000000000001",
            rewardToken: "0x0000000000000000000000000000000000000002",
            dao: "0x0000000000000000000000000000000000000003",
            rewardRate: ethers.utils.parseEther("0.5"),
            emergencyPenalty: 500, // 5%
            name: "Low Risk Vault",
            symbol: "LR-VAULT"
        },
        {
            stakingToken: "0x0000000000000000000000000000000000000001",
            rewardToken: "0x0000000000000000000000000000000000000004",
            dao: "0x0000000000000000000000000000000000000003",
            rewardRate: ethers.utils.parseEther("2"),
            emergencyPenalty: 2000, // 20%
            name: "High Reward Vault",
            symbol: "HR-VAULT"
        }
    ];

    const creationFee = await factory.creationFee();
    const totalFee = creationFee.mul(vaultConfigs.length);

    try {
        console.log(`Creating ${vaultConfigs.length} vaults...`);
        const tx = await factory.createVaults(vaultConfigs, { value: totalFee });
        const receipt = await tx.wait();

        console.log("✅ Batch deployment completed");
        console.log("- Gas used:", receipt.gasUsed.toString());

        const finalVaultCount = await factory.getVaultCount();
        console.log("- Total vaults:", finalVaultCount.toString());

    } catch (error) {
        console.log("❌ Batch deployment failed:", error.message);
    }
}

// Execute deployment
if (require.main === module) {
    main()
        .then(async (result) => {
            // Optional: Run tests
            if (process.env.RUN_TESTS === "true") {
                await testVaultCreation(result.factory);
                await deployMultipleVaults(result.factory);
            }

            process.exit(0);
        })
        .catch((error) => {
            console.error("Deployment failed:", error);
            process.exit(1);
        });
}

module.exports = { main, testVaultCreation, deployMultipleVaults };
