const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();

    console.log("Deploying Aetherweb3 Governance Contracts...");
    console.log("Deployer address:", deployer.address);

    // Deploy Aetherweb3Token first
    console.log("\n1. Deploying Aetherweb3Token...");
    const Aetherweb3Token = await ethers.getContractFactory("Aetherweb3Token");
    const token = await Aetherweb3Token.deploy(
        "Aetherweb3 Governance Token",
        "AETH",
        ethers.utils.parseEther("100000000"), // 100M tokens
        deployer.address
    );
    await token.deployed();
    console.log("Aetherweb3Token deployed to:", token.address);

    // Deploy Timelock
    console.log("\n2. Deploying Aetherweb3Timelock...");
    const Aetherweb3Timelock = await ethers.getContractFactory("Aetherweb3Timelock");
    const timelock = await Aetherweb3Timelock.deploy(2 * 24 * 3600); // 2 days delay
    await timelock.deployed();
    console.log("Aetherweb3Timelock deployed to:", timelock.address);

    // Deploy DAO
    console.log("\n3. Deploying Aetherweb3DAO...");
    const Aetherweb3DAO = await ethers.getContractFactory("Aetherweb3DAO");
    const dao = await Aetherweb3DAO.deploy(token.address, timelock.address);
    await dao.deployed();
    console.log("Aetherweb3DAO deployed to:", dao.address);

    // Transfer timelock ownership to DAO
    console.log("\n4. Transferring timelock ownership to DAO...");
    await timelock.transferOwnership(dao.address);
    console.log("Timelock ownership transferred to DAO");

    // Deploy Staking Vault
    console.log("\n5. Deploying Aetherweb3StakingVault...");
    const Aetherweb3StakingVault = await ethers.getContractFactory("Aetherweb3StakingVault");
    const stakingVault = await Aetherweb3StakingVault.deploy(
        token.address,  // staking token
        token.address,  // reward token (same as staking for now)
        dao.address     // DAO address
    );
    await stakingVault.deployed();
    console.log("Aetherweb3StakingVault deployed to:", stakingVault.address);

    // Setup initial reward rate (1 token per day)
    const rewardRate = ethers.utils.parseEther("1").div(86400);
    await stakingVault.setRewardRate(rewardRate);
    console.log("Initial reward rate set to:", rewardRate.toString(), "tokens per second");

    // Allocate initial rewards to staking vault
    const initialRewards = ethers.utils.parseEther("1000000"); // 1M tokens
    await token.transfer(stakingVault.address, initialRewards);
    console.log("Allocated", ethers.utils.formatEther(initialRewards), "tokens to staking vault");

    // Authorize DAO as timelock executor
    console.log("\n6. Authorizing DAO as timelock executor...");
    await timelock.connect(deployer).authorizeExecutor(dao.address);
    console.log("DAO authorized as timelock executor");

    console.log("\n🎉 All governance contracts deployed successfully!");
    console.log("\nContract Addresses:");
    console.log("==================");
    console.log("Aetherweb3Token:", token.address);
    console.log("Aetherweb3Timelock:", timelock.address);
    console.log("Aetherweb3DAO:", dao.address);
    console.log("Aetherweb3StakingVault:", stakingVault.address);

    console.log("\nNext Steps:");
    console.log("===========");
    console.log("1. Distribute governance tokens to community");
    console.log("2. Set up initial DAO proposals");
    console.log("3. Configure staking vault parameters");
    console.log("4. Test governance functionality");

    // Verify contracts on Etherscan (if on mainnet)
    if (network.name === "mainnet") {
        console.log("\nVerifying contracts on Etherscan...");

        try {
            await hre.run("verify:verify", {
                address: token.address,
                constructorArguments: [
                    "Aetherweb3 Governance Token",
                    "AETH",
                    ethers.utils.parseEther("100000000"),
                    deployer.address
                ],
            });
            console.log("Aetherweb3Token verified");

            await hre.run("verify:verify", {
                address: timelock.address,
                constructorArguments: [2 * 24 * 3600],
            });
            console.log("Aetherweb3Timelock verified");

            await hre.run("verify:verify", {
                address: dao.address,
                constructorArguments: [token.address, timelock.address],
            });
            console.log("Aetherweb3DAO verified");

            await hre.run("verify:verify", {
                address: stakingVault.address,
                constructorArguments: [token.address, token.address, dao.address],
            });
            console.log("Aetherweb3StakingVault verified");

        } catch (error) {
            console.log("Verification failed:", error.message);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
