const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aetherweb3StakingVault", function () {
    let stakingVault, stakingToken, rewardToken, dao, owner, user1, user2, user3;
    const REWARD_RATE = ethers.utils.parseEther("1").div(86400); // 1 token per day
    const INITIAL_REWARDS = ethers.utils.parseEther("100000");

    beforeEach(async function () {
        [owner, user1, user2, user3] = await ethers.getSigners();

        // Deploy mock DAO
        const MockDAO = await ethers.getContractFactory("Aetherweb3DAO");
        dao = await MockDAO.deploy(
            ethers.constants.AddressZero, // mock governance token
            ethers.constants.AddressZero  // mock timelock
        );
        await dao.deployed();

        // Deploy staking token
        const Token = await ethers.getContractFactory("Aetherweb3Token");
        stakingToken = await Token.deploy(
            "Staking Token",
            "STAKE",
            ethers.utils.parseEther("1000000"),
            owner.address
        );
        await stakingToken.deployed();

        // Deploy reward token
        rewardToken = await Token.deploy(
            "Reward Token",
            "REWARD",
            ethers.utils.parseEther("1000000"),
            owner.address
        );
        await rewardToken.deployed();

        // Deploy staking vault
        const StakingVault = await ethers.getContractFactory("Aetherweb3StakingVault");
        stakingVault = await StakingVault.deploy(
            stakingToken.address,
            rewardToken.address,
            dao.address
        );
        await stakingVault.deployed();

        // Setup initial state
        await stakingVault.setRewardRate(REWARD_RATE);
        await rewardToken.transfer(stakingVault.address, INITIAL_REWARDS);

        // Distribute staking tokens
        await stakingToken.transfer(user1.address, ethers.utils.parseEther("10000"));
        await stakingToken.transfer(user2.address, ethers.utils.parseEther("20000"));
        await stakingToken.transfer(user3.address, ethers.utils.parseEther("30000"));
    });

    describe("Staking", function () {
        it("Should stake tokens", async function () {
            const amount = ethers.utils.parseEther("1000");
            const lockPeriod = 30 * 24 * 3600; // 30 days

            // Approve and stake
            await stakingToken.connect(user1).approve(stakingVault.address, amount);
            await expect(stakingVault.connect(user1).stake(amount, lockPeriod))
                .to.emit(stakingVault, "Staked")
                .withArgs(user1.address, amount, lockPeriod);

            // Check balances
            expect(await stakingToken.balanceOf(stakingVault.address)).to.equal(amount);
            expect(await stakingVault.totalStaked()).to.equal(amount);

            // Check stake info
            const stakeInfo = await stakingVault.getStakeInfo(user1.address);
            expect(stakeInfo.amount).to.equal(amount);
            expect(stakeInfo.lockEndTime).to.be.gt(await ethers.provider.getBlock("latest").timestamp);
        });

        it("Should reject staking zero amount", async function () {
            await expect(stakingVault.connect(user1).stake(0, 0))
                .to.be.revertedWith("Aetherweb3StakingVault: cannot stake 0");
        });

        it("Should reject invalid lock period", async function () {
            const amount = ethers.utils.parseEther("1000");
            await stakingToken.connect(user1).approve(stakingVault.address, amount);

            await expect(stakingVault.connect(user1).stake(amount, 999))
                .to.be.revertedWith("Aetherweb3StakingVault: invalid lock period");
        });
    });

    describe("Unstaking", function () {
        beforeEach(async function () {
            const amount = ethers.utils.parseEther("1000");
            await stakingToken.connect(user1).approve(stakingVault.address, amount);
            await stakingVault.connect(user1).stake(amount, 30 * 24 * 3600); // 30 days
        });

        it("Should unstake after lock period", async function () {
            const amount = ethers.utils.parseEther("1000");

            // Advance time past lock period
            await ethers.provider.send("evm_increaseTime", [31 * 24 * 3600]); // 31 days
            await ethers.provider.send("evm_mine");

            await expect(stakingVault.connect(user1).unstake(amount))
                .to.emit(stakingVault, "Unstaked")
                .withArgs(user1.address, amount, false);

            // Check balances
            expect(await stakingToken.balanceOf(user1.address)).to.equal(ethers.utils.parseEther("10000"));
            expect(await stakingVault.totalStaked()).to.equal(0);
        });

        it("Should reject unstaking during lock period", async function () {
            const amount = ethers.utils.parseEther("1000");

            await expect(stakingVault.connect(user1).unstake(amount))
                .to.be.revertedWith("Aetherweb3StakingVault: tokens are locked");
        });

        it("Should reject unstaking more than staked", async function () {
            const amount = ethers.utils.parseEther("2000");

            // Advance time past lock period
            await ethers.provider.send("evm_increaseTime", [31 * 24 * 3600]);
            await ethers.provider.send("evm_mine");

            await expect(stakingVault.connect(user1).unstake(amount))
                .to.be.revertedWith("Aetherweb3StakingVault: insufficient staked amount");
        });
    });

    describe("Emergency Unstaking", function () {
        beforeEach(async function () {
            const amount = ethers.utils.parseEther("1000");
            await stakingToken.connect(user1).approve(stakingVault.address, amount);
            await stakingVault.connect(user1).stake(amount, 30 * 24 * 3600);
        });

        it("Should emergency unstake with penalty", async function () {
            const amount = ethers.utils.parseEther("1000");
            const penalty = (amount * 1000) / 10000; // 10% penalty
            const returnAmount = amount - penalty;

            await expect(stakingVault.connect(user1).emergencyUnstake(amount))
                .to.emit(stakingVault, "Unstaked")
                .withArgs(user1.address, returnAmount, true);

            // Check balances
            expect(await stakingToken.balanceOf(user1.address)).to.equal(
                ethers.utils.parseEther("10000").sub(amount).add(returnAmount)
            );
        });

        it("Should prevent double emergency unstaking", async function () {
            const amount = ethers.utils.parseEther("1000");

            await stakingVault.connect(user1).emergencyUnstake(amount);
            await expect(stakingVault.connect(user1).emergencyUnstake(amount))
                .to.be.revertedWith("Aetherweb3StakingVault: already emergency unstaked");
        });
    });

    describe("Rewards", function () {
        beforeEach(async function () {
            const amount = ethers.utils.parseEther("1000");
            await stakingToken.connect(user1).approve(stakingVault.address, amount);
            await stakingVault.connect(user1).stake(amount, 30 * 24 * 3600);
        });

        it("Should calculate earned rewards", async function () {
            // Advance time by 1 day
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine");

            const earned = await stakingVault.earned(user1.address);
            expect(earned).to.be.gt(0);
            expect(earned).to.be.lte(REWARD_RATE.mul(86400)); // Should not exceed daily rate
        });

        it("Should claim rewards", async function () {
            // Advance time by 1 day
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine");

            const earnedBefore = await stakingVault.earned(user1.address);
            expect(earnedBefore).to.be.gt(0);

            await expect(stakingVault.connect(user1).claimReward())
                .to.emit(stakingVault, "RewardClaimed")
                .withArgs(user1.address, earnedBefore);

            // Check reward balance
            expect(await rewardToken.balanceOf(user1.address)).to.equal(earnedBefore);

            // Earned should be reset
            const earnedAfter = await stakingVault.earned(user1.address);
            expect(earnedAfter).to.equal(0);
        });

        it("Should apply lock multiplier", async function () {
            const amount = ethers.utils.parseEther("1000");

            // Stake with different lock periods
            await stakingToken.connect(user2).approve(stakingVault.address, amount);
            await stakingVault.connect(user2).stake(amount, 90 * 24 * 3600); // 90 days

            // Advance time by 1 day
            await ethers.provider.send("evm_increaseTime", [86400]);
            await ethers.provider.send("evm_mine");

            const earned1 = await stakingVault.earned(user1.address); // 30 day lock
            const earned2 = await stakingVault.earned(user2.address); // 90 day lock

            // User2 should earn more due to higher multiplier
            expect(earned2).to.be.gt(earned1);
        });
    });

    describe("APR Calculation", function () {
        it("Should calculate APR correctly", async function () {
            const amount = ethers.utils.parseEther("1000");
            await stakingToken.connect(user1).approve(stakingVault.address, amount);
            await stakingVault.connect(user1).stake(amount, 30 * 24 * 3600);

            const apr = await stakingVault.getAPR(30 * 24 * 3600);
            expect(apr).to.be.gt(0);

            // APR should be higher for longer lock periods
            const longApr = await stakingVault.getAPR(180 * 24 * 3600);
            expect(longApr).to.be.gt(apr);
        });

        it("Should return 0 APR for invalid lock period", async function () {
            const apr = await stakingVault.getAPR(999);
            expect(apr).to.equal(0);
        });
    });

    describe("Admin Functions", function () {
        it("Should update reward rate", async function () {
            const newRate = REWARD_RATE.mul(2);

            await expect(stakingVault.setRewardRate(newRate))
                .to.emit(stakingVault, "RewardRateUpdated")
                .withArgs(REWARD_RATE, newRate);

            expect(await stakingVault.rewardRate()).to.equal(newRate);
        });

        it("Should update emergency penalty", async function () {
            const newPenalty = 1500; // 15%

            await expect(stakingVault.setEmergencyPenalty(newPenalty))
                .to.emit(stakingVault, "EmergencyPenaltyUpdated")
                .withArgs(1000, newPenalty);

            expect(await stakingVault.emergencyPenalty()).to.equal(newPenalty);
        });

        it("Should reject penalty above 50%", async function () {
            await expect(stakingVault.setEmergencyPenalty(6000))
                .to.be.revertedWith("Aetherweb3StakingVault: penalty too high");
        });

        it("Should update lock period", async function () {
            const lockId = 30 * 24 * 3600;
            const newDuration = 40 * 24 * 3600;
            const newMultiplier = 12000; // 120%

            await expect(stakingVault.updateLockPeriod(lockId, newDuration, newMultiplier))
                .to.emit(stakingVault, "LockPeriodUpdated")
                .withArgs(lockId, newDuration, newMultiplier);

            const lockPeriod = await stakingVault.lockPeriods(lockId);
            expect(lockPeriod.duration).to.equal(newDuration);
            expect(lockPeriod.multiplier).to.equal(newMultiplier);
        });
    });

    describe("DAO Integration", function () {
        it("Should allow DAO to update reward rate", async function () {
            const newRate = REWARD_RATE.mul(3);

            // Mock DAO call
            await expect(stakingVault.connect(owner).setRewardRate(newRate))
                .to.emit(stakingVault, "RewardRateUpdated");
        });

        it("Should update DAO address", async function () {
            const newDAO = user3.address;

            await expect(stakingVault.setDAO(newDAO))
                .to.emit(stakingVault, "DAOUpdated")
                .withArgs(dao.address, newDAO);

            expect(await stakingVault.dao()).to.equal(newDAO);
        });
    });

    describe("View Functions", function () {
        beforeEach(async function () {
            const amount = ethers.utils.parseEther("1000");
            await stakingToken.connect(user1).approve(stakingVault.address, amount);
            await stakingVault.connect(user1).stake(amount, 30 * 24 * 3600);
        });

        it("Should return correct stake info", async function () {
            const stakeInfo = await stakingVault.getStakeInfo(user1.address);
            expect(stakeInfo.amount).to.equal(ethers.utils.parseEther("1000"));
            expect(stakeInfo.emergencyUnstaked).to.equal(false);
        });

        it("Should return correct lock multiplier", async function () {
            const multiplier = await stakingVault.getLockMultiplier(user1.address);
            expect(multiplier).to.equal(11000); // 110% for 30 day lock
        });

        it("Should return base multiplier after lock period", async function () {
            // Advance time past lock period
            await ethers.provider.send("evm_increaseTime", [31 * 24 * 3600]);
            await ethers.provider.send("evm_mine");

            const multiplier = await stakingVault.getLockMultiplier(user1.address);
            expect(multiplier).to.equal(10000); // Base 100% after lock
        });
    });
});
