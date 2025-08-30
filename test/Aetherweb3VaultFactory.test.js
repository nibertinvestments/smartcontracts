const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aetherweb3VaultFactory", function () {
    let factory;
    let stakingToken;
    let rewardToken;
    let dao;
    let owner;
    let user1;
    let user2;
    let feeRecipient;

    const CREATION_FEE = ethers.utils.parseEther("0.1");

    beforeEach(async function () {
        [owner, user1, user2, feeRecipient] = await ethers.getSigners();

        // Deploy mock tokens
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        stakingToken = await MockERC20.deploy("Staking Token", "STAKE");
        rewardToken = await MockERC20.deploy("Reward Token", "REWARD");

        // Deploy mock DAO
        const MockDAO = await ethers.getContractFactory("MockDAO");
        dao = await MockDAO.deploy();

        // Deploy factory
        const VaultFactory = await ethers.getContractFactory("Aetherweb3VaultFactory");
        factory = await VaultFactory.deploy(feeRecipient.address);
    });

    describe("Deployment", function () {
        it("Should set the correct fee recipient", async function () {
            expect(await factory.feeRecipient()).to.equal(feeRecipient.address);
        });

        it("Should start unpaused", async function () {
            expect(await factory.isPaused()).to.be.false;
        });

        it("Should have zero creation fee by default", async function () {
            expect(await factory.creationFee()).to.equal(0);
        });
    });

    describe("Vault Creation", function () {
        const validParams = {
            stakingToken: null, // Will be set in tests
            rewardToken: null, // Will be set in tests
            dao: null, // Will be set in tests
            rewardRate: ethers.utils.parseEther("1"),
            emergencyPenalty: 1000, // 10%
            name: "Test Vault",
            symbol: "TEST-VAULT"
        };

        beforeEach(async function () {
            validParams.stakingToken = stakingToken.address;
            validParams.rewardToken = rewardToken.address;
            validParams.dao = dao.address;
        });

        it("Should create vault with valid parameters", async function () {
            const tx = await factory.connect(user1).createVault(validParams);
            const receipt = await tx.wait();

            // Check event
            expect(receipt.events).to.have.lengthOf(1);
            const event = receipt.events[0];
            expect(event.event).to.equal("VaultCreated");

            const vaultAddress = event.args.vault;
            expect(vaultAddress).to.not.equal(ethers.constants.AddressZero);

            // Check registry
            expect(await factory.isVault(vaultAddress)).to.be.true;
            expect(await factory.vaultCreators(vaultAddress)).to.equal(user1.address);

            // Check vault count
            expect(await factory.getVaultCount()).to.equal(1);
        });

        it("Should store vault parameters correctly", async function () {
            await factory.connect(user1).createVault(validParams);

            const vaults = await factory.getAllVaults();
            const vaultAddress = vaults[0];

            const [params, creator] = await factory.getVaultInfo(vaultAddress);

            expect(params.stakingToken).to.equal(stakingToken.address);
            expect(params.rewardToken).to.equal(rewardToken.address);
            expect(params.dao).to.equal(dao.address);
            expect(params.rewardRate).to.equal(validParams.rewardRate);
            expect(params.emergencyPenalty).to.equal(validParams.emergencyPenalty);
            expect(params.name).to.equal(validParams.name);
            expect(params.symbol).to.equal(validParams.symbol);
            expect(creator).to.equal(user1.address);
        });

        it("Should reject invalid staking token", async function () {
            const invalidParams = { ...validParams };
            invalidParams.stakingToken = ethers.constants.AddressZero;

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: invalid staking token");
        });

        it("Should reject invalid reward token", async function () {
            const invalidParams = { ...validParams };
            invalidParams.rewardToken = ethers.constants.AddressZero;

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: invalid reward token");
        });

        it("Should reject invalid DAO address", async function () {
            const invalidParams = { ...validParams };
            invalidParams.dao = ethers.constants.AddressZero;

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: invalid DAO address");
        });

        it("Should reject zero reward rate", async function () {
            const invalidParams = { ...validParams };
            invalidParams.rewardRate = 0;

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: reward rate must be > 0");
        });

        it("Should reject emergency penalty too high", async function () {
            const invalidParams = { ...validParams };
            invalidParams.emergencyPenalty = 6000; // 60% > 50% max

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: penalty too high");
        });

        it("Should reject empty name", async function () {
            const invalidParams = { ...validParams };
            invalidParams.name = "";

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: name required");
        });

        it("Should reject empty symbol", async function () {
            const invalidParams = { ...validParams };
            invalidParams.symbol = "";

            await expect(
                factory.connect(user1).createVault(invalidParams)
            ).to.be.revertedWith("Aetherweb3VaultFactory: symbol required");
        });
    });

    describe("Batch Vault Creation", function () {
        it("Should create multiple vaults in batch", async function () {
            const paramsArray = [
                {
                    stakingToken: stakingToken.address,
                    rewardToken: rewardToken.address,
                    dao: dao.address,
                    rewardRate: ethers.utils.parseEther("1"),
                    emergencyPenalty: 1000,
                    name: "Vault 1",
                    symbol: "V1"
                },
                {
                    stakingToken: stakingToken.address,
                    rewardToken: rewardToken.address,
                    dao: dao.address,
                    rewardRate: ethers.utils.parseEther("2"),
                    emergencyPenalty: 1500,
                    name: "Vault 2",
                    symbol: "V2"
                }
            ];

            await factory.connect(user1).createVaults(paramsArray);

            expect(await factory.getVaultCount()).to.equal(2);

            const vaults = await factory.getAllVaults();
            expect(vaults).to.have.lengthOf(2);
        });

        it("Should handle creation fees in batch", async function () {
            await factory.setCreationFee(CREATION_FEE);

            const paramsArray = [
                {
                    stakingToken: stakingToken.address,
                    rewardToken: rewardToken.address,
                    dao: dao.address,
                    rewardRate: ethers.utils.parseEther("1"),
                    emergencyPenalty: 1000,
                    name: "Vault 1",
                    symbol: "V1"
                }
            ];

            const totalFee = CREATION_FEE;

            await factory.connect(user1).createVaults(paramsArray, { value: totalFee });

            expect(await factory.getVaultCount()).to.equal(1);
        });

        it("Should refund excess fees in batch creation", async function () {
            await factory.setCreationFee(CREATION_FEE);

            const paramsArray = [
                {
                    stakingToken: stakingToken.address,
                    rewardToken: rewardToken.address,
                    dao: dao.address,
                    rewardRate: ethers.utils.parseEther("1"),
                    emergencyPenalty: 1000,
                    name: "Vault 1",
                    symbol: "V1"
                }
            ];

            const excessFee = ethers.utils.parseEther("0.5");
            const totalValue = CREATION_FEE.add(excessFee);

            const initialBalance = await user1.getBalance();

            const tx = await factory.connect(user1).createVaults(paramsArray, { value: totalValue });
            const receipt = await tx.wait();

            const gasCost = receipt.gasUsed.mul(tx.gasPrice);
            const finalBalance = await user1.getBalance();

            // Should have spent gas + creation fee, but received excess back
            const expectedBalance = initialBalance.sub(gasCost).sub(CREATION_FEE);
            expect(finalBalance).to.equal(expectedBalance);
        });
    });

    describe("Fee System", function () {
        beforeEach(async function () {
            await factory.setCreationFee(CREATION_FEE);
        });

        it("Should require creation fee", async function () {
            const params = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Test Vault",
                symbol: "TEST-VAULT"
            };

            await expect(
                factory.connect(user1).createVault(params)
            ).to.be.revertedWith("Aetherweb3VaultFactory: insufficient fee");
        });

        it("Should accept correct creation fee", async function () {
            const params = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Test Vault",
                symbol: "TEST-VAULT"
            };

            const initialFeeRecipientBalance = await feeRecipient.getBalance();

            await factory.connect(user1).createVault(params, { value: CREATION_FEE });

            const finalFeeRecipientBalance = await feeRecipient.getBalance();
            expect(finalFeeRecipientBalance).to.equal(initialFeeRecipientBalance.add(CREATION_FEE));
        });

        it("Should update creation fee", async function () {
            const newFee = ethers.utils.parseEther("0.2");

            await expect(factory.setCreationFee(newFee))
                .to.emit(factory, "CreationFeeUpdated")
                .withArgs(CREATION_FEE, newFee);

            expect(await factory.creationFee()).to.equal(newFee);
        });

        it("Should update fee recipient", async function () {
            await expect(factory.setFeeRecipient(user2.address))
                .to.emit(factory, "FeeRecipientUpdated")
                .withArgs(feeRecipient.address, user2.address);

            expect(await factory.feeRecipient()).to.equal(user2.address);
        });

        it("Should reject zero address as fee recipient", async function () {
            await expect(
                factory.setFeeRecipient(ethers.constants.AddressZero)
            ).to.be.revertedWith("Aetherweb3VaultFactory: invalid address");
        });
    });

    describe("Query Functions", function () {
        let vault1, vault2, vault3;

        beforeEach(async function () {
            const baseParams = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Test Vault",
                symbol: "TEST-VAULT"
            };

            // Create vaults by different users
            await factory.connect(user1).createVault(baseParams);
            await factory.connect(user2).createVault(baseParams);
            await factory.connect(user1).createVault(baseParams);

            const vaults = await factory.getAllVaults();
            vault1 = vaults[0];
            vault2 = vaults[1];
            vault3 = vaults[2];
        });

        it("Should return all vaults", async function () {
            const vaults = await factory.getAllVaults();
            expect(vaults).to.have.lengthOf(3);
            expect(vaults[0]).to.equal(vault1);
            expect(vaults[1]).to.equal(vault2);
            expect(vaults[2]).to.equal(vault3);
        });

        it("Should return vaults by creator", async function () {
            const user1Vaults = await factory.getVaultsByCreator(user1.address);
            expect(user1Vaults).to.have.lengthOf(2);

            const user2Vaults = await factory.getVaultsByCreator(user2.address);
            expect(user2Vaults).to.have.lengthOf(1);
            expect(user2Vaults[0]).to.equal(vault2);
        });

        it("Should return vaults by staking token", async function () {
            const tokenVaults = await factory.getVaultsByStakingToken(stakingToken.address);
            expect(tokenVaults).to.have.lengthOf(3);
        });

        it("Should return correct vault count", async function () {
            expect(await factory.getVaultCount()).to.equal(3);
        });

        it("Should return vault info", async function () {
            const [params, creator] = await factory.getVaultInfo(vault1);
            expect(creator).to.equal(user1.address);
            expect(params.stakingToken).to.equal(stakingToken.address);
        });

        it("Should reject invalid vault for info query", async function () {
            await expect(
                factory.getVaultInfo(ethers.constants.AddressZero)
            ).to.be.revertedWith("Aetherweb3VaultFactory: not a factory vault");
        });
    });

    describe("Address Prediction", function () {
        it("Should predict vault address", async function () {
            const params = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Test Vault",
                symbol: "TEST-VAULT"
            };

            const predictedAddress = await factory.predictVaultAddress(params, user1.address);
            expect(predictedAddress).to.not.equal(ethers.constants.AddressZero);
        });
    });

    describe("Pause Functionality", function () {
        it("Should pause and unpause factory", async function () {
            // Pause
            await factory.pause();
            expect(await factory.isPaused()).to.be.true;

            // Unpause
            await factory.unpause();
            expect(await factory.isPaused()).to.be.false;
        });

        it("Should prevent vault creation when paused", async function () {
            await factory.pause();

            const params = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Test Vault",
                symbol: "TEST-VAULT"
            };

            await expect(
                factory.connect(user1).createVault(params)
            ).to.be.revertedWith("Aetherweb3VaultFactory: factory is paused");
        });

        it("Should allow vault creation when unpaused", async function () {
            await factory.pause();
            await factory.unpause();

            const params = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Test Vault",
                symbol: "TEST-VAULT"
            };

            await expect(
                factory.connect(user1).createVault(params)
            ).to.not.be.reverted;
        });
    });

    describe("Emergency Functions", function () {
        it("Should allow emergency withdrawal of ETH", async function () {
            // Send ETH to factory
            await user1.sendTransaction({
                to: factory.address,
                value: ethers.utils.parseEther("1")
            });

            const initialOwnerBalance = await owner.getBalance();

            await factory.emergencyWithdraw();

            const finalOwnerBalance = await owner.getBalance();
            expect(finalOwnerBalance).to.be.gt(initialOwnerBalance);
        });

        it("Should reject emergency withdrawal with no balance", async function () {
            await expect(
                factory.emergencyWithdraw()
            ).to.be.revertedWith("Aetherweb3VaultFactory: no balance to withdraw");
        });
    });

    describe("Access Control", function () {
        it("Should only allow owner to set creation fee", async function () {
            await expect(
                factory.connect(user1).setCreationFee(CREATION_FEE)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should only allow owner to set fee recipient", async function () {
            await expect(
                factory.connect(user1).setFeeRecipient(user2.address)
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should only allow owner to pause", async function () {
            await expect(
                factory.connect(user1).pause()
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should only allow owner to unpause", async function () {
            await factory.pause();

            await expect(
                factory.connect(user1).unpause()
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should only allow owner to emergency withdraw", async function () {
            await expect(
                factory.connect(user1).emergencyWithdraw()
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });
    });

    describe("Integration Tests", function () {
        it("Should create functional vault", async function () {
            const params = {
                stakingToken: stakingToken.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("1"),
                emergencyPenalty: 1000,
                name: "Integration Vault",
                symbol: "INT-VAULT"
            };

            const tx = await factory.connect(user1).createVault(params);
            const receipt = await tx.wait();

            const vaultAddress = receipt.events[0].args.vault;
            const vault = await ethers.getContractAt("Aetherweb3StakingVault", vaultAddress);

            // Verify vault is functional
            expect(await vault.stakingToken()).to.equal(stakingToken.address);
            expect(await vault.rewardToken()).to.equal(rewardToken.address);
            expect(await vault.dao()).to.equal(dao.address);
        });

        it("Should handle multiple different configurations", async function () {
            // Deploy additional tokens
            const tokenA = await (await ethers.getContractFactory("MockERC20")).deploy("Token A", "TA");
            const tokenB = await (await ethers.getContractFactory("MockERC20")).deploy("Token B", "TB");

            const params1 = {
                stakingToken: stakingToken.address,
                rewardToken: tokenA.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("0.5"),
                emergencyPenalty: 500,
                name: "Vault A",
                symbol: "VA"
            };

            const params2 = {
                stakingToken: tokenB.address,
                rewardToken: rewardToken.address,
                dao: dao.address,
                rewardRate: ethers.utils.parseEther("2"),
                emergencyPenalty: 2000,
                name: "Vault B",
                symbol: "VB"
            };

            await factory.connect(user1).createVault(params1);
            await factory.connect(user2).createVault(params2);

            expect(await factory.getVaultCount()).to.equal(2);

            const vaults = await factory.getAllVaults();
            const vaultA = await ethers.getContractAt("Aetherweb3StakingVault", vaults[0]);
            const vaultB = await ethers.getContractAt("Aetherweb3StakingVault", vaults[1]);

            expect(await vaultA.rewardToken()).to.equal(tokenA.address);
            expect(await vaultB.stakingToken()).to.equal(tokenB.address);
        });
    });
});
