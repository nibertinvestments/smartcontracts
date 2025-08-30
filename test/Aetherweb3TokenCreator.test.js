const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aetherweb3TokenCreator", function () {
  let tokenCreator;
  let owner;
  let user1;
  let user2;
  let feeRecipient;
  const creationFee = ethers.utils.parseEther("0.005");

  beforeEach(async function () {
    [owner, user1, user2, feeRecipient] = await ethers.getSigners();

    const TokenCreator = await ethers.getContractFactory("Aetherweb3TokenCreator");
    tokenCreator = await TokenCreator.deploy(feeRecipient.address);
    await tokenCreator.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct fee recipient", async function () {
      expect(await tokenCreator.feeRecipient()).to.equal(feeRecipient.address);
    });

    it("Should set the correct creation fee", async function () {
      expect(await tokenCreator.CREATION_FEE()).to.equal(creationFee);
    });

    it("Should set the correct owner", async function () {
      expect(await tokenCreator.owner()).to.equal(owner.address);
    });
  });

  describe("Token Creation", function () {
    describe("Standard Token", function () {
      it("Should create a standard token successfully", async function () {
        const tokenName = "Test Token";
        const tokenSymbol = "TEST";
        const initialSupply = ethers.utils.parseEther("1000000");

        const tx = await tokenCreator.connect(user1).createStandardToken(
          tokenName,
          tokenSymbol,
          initialSupply,
          18,
          { value: creationFee }
        );

        await tx.wait();

        // Check that token was created
        const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
        expect(creatorTokens.length).to.equal(1);

        const createdToken = creatorTokens[0];
        expect(createdToken.name).to.equal(tokenName);
        expect(createdToken.symbol).to.equal(tokenSymbol);
        expect(createdToken.initialSupply).to.equal(initialSupply);
        expect(createdToken.creator).to.equal(user1.address);
      });

      it("Should reject token creation without sufficient fee", async function () {
        const tokenName = "Test Token";
        const tokenSymbol = "TEST";
        const initialSupply = ethers.utils.parseEther("1000000");

        await expect(
          tokenCreator.connect(user1).createStandardToken(
            tokenName,
            tokenSymbol,
            initialSupply,
            18,
            { value: ethers.utils.parseEther("0.001") }
          )
        ).to.be.revertedWith("Insufficient fee");
      });

      it("Should refund excess payment", async function () {
        const tokenName = "Test Token";
        const tokenSymbol = "TEST";
        const initialSupply = ethers.utils.parseEther("1000000");

        const initialBalance = await user1.getBalance();

        const tx = await tokenCreator.connect(user1).createStandardToken(
          tokenName,
          tokenSymbol,
          initialSupply,
          18,
          { value: ethers.utils.parseEther("0.01") } // More than required
        );

        const receipt = await tx.wait();
        const gasCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);

        const finalBalance = await user1.getBalance();

        // Should have been charged exactly 0.005 ETH plus gas
        const expectedBalance = initialBalance.sub(creationFee).sub(gasCost);
        expect(finalBalance).to.equal(expectedBalance);
      });
    });

    describe("Full Featured Token", function () {
      it("Should create a full featured token with all options", async function () {
        const tokenName = "Full Featured Token";
        const tokenSymbol = "FFT";
        const initialSupply = ethers.utils.parseEther("10000000");
        const maxSupply = ethers.utils.parseEther("100000000");

        const taxConfig = {
          buyTax: 300, // 3%
          sellTax: 500, // 5%
          transferTax: 100, // 1%
          taxWallet: user2.address,
          taxOnBuys: true,
          taxOnSells: true,
          taxOnTransfers: true
        };

        const reflectionConfig = {
          reflectionFee: 200, // 2%
          rewardToken: ethers.constants.AddressZero,
          autoClaim: true,
          minTokensForClaim: ethers.utils.parseEther("1000")
        };

        const tokenParams = {
          name: tokenName,
          symbol: tokenSymbol,
          initialSupply: initialSupply,
          decimals: 18,
          maxSupply: maxSupply,
          owner: user1.address,
          features: {
            burnable: true,
            mintable: true,
            pausable: true,
            capped: true,
            taxable: true,
            reflection: true,
            governance: true,
            flashMint: true,
            permit: true
          },
          taxConfig: taxConfig,
          reflectionConfig: reflectionConfig,
          salt: ethers.utils.randomBytes(32)
        };

        const tx = await tokenCreator.connect(user1).createToken(
          tokenParams,
          { value: creationFee }
        );

        await tx.wait();

        const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
        expect(creatorTokens.length).to.equal(1);

        const createdToken = creatorTokens[0];
        expect(createdToken.name).to.equal(tokenName);
        expect(createdToken.symbol).to.equal(tokenSymbol);
        expect(createdToken.tokenType).to.equal(9); // FULL_FEATURED
      });
    });

    describe("Custom Token Features", function () {
      it("Should create a burnable token", async function () {
        const tokenParams = {
          name: "Burnable Token",
          symbol: "BURN",
          initialSupply: ethers.utils.parseEther("1000000"),
          decimals: 18,
          maxSupply: 0,
          owner: user1.address,
          features: {
            burnable: true,
            mintable: false,
            pausable: false,
            capped: false,
            taxable: false,
            reflection: false,
            governance: false,
            flashMint: false,
            permit: false
          },
          taxConfig: {
            buyTax: 0,
            sellTax: 0,
            transferTax: 0,
            taxWallet: ethers.constants.AddressZero,
            taxOnBuys: false,
            taxOnSells: false,
            taxOnTransfers: false
          },
          reflectionConfig: {
            reflectionFee: 0,
            rewardToken: ethers.constants.AddressZero,
            autoClaim: false,
            minTokensForClaim: 0
          },
          salt: ethers.utils.randomBytes(32)
        };

        await tokenCreator.connect(user1).createToken(tokenParams, { value: creationFee });

        const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
        expect(creatorTokens[0].tokenType).to.equal(1); // BURNABLE
      });

      it("Should create a governance token", async function () {
        const tokenParams = {
          name: "Governance Token",
          symbol: "GOV",
          initialSupply: ethers.utils.parseEther("1000000"),
          decimals: 18,
          maxSupply: 0,
          owner: user1.address,
          features: {
            burnable: false,
            mintable: false,
            pausable: false,
            capped: false,
            taxable: false,
            reflection: false,
            governance: true,
            flashMint: false,
            permit: false
          },
          taxConfig: {
            buyTax: 0,
            sellTax: 0,
            transferTax: 0,
            taxWallet: ethers.constants.AddressZero,
            taxOnBuys: false,
            taxOnSells: false,
            taxOnTransfers: false
          },
          reflectionConfig: {
            reflectionFee: 0,
            rewardToken: ethers.constants.AddressZero,
            autoClaim: false,
            minTokensForClaim: 0
          },
          salt: ethers.utils.randomBytes(32)
        };

        await tokenCreator.connect(user1).createToken(tokenParams, { value: creationFee });

        const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
        expect(creatorTokens[0].tokenType).to.equal(6); // GOVERNANCE
      });
    });
  });

  describe("Token Verification", function () {
    let tokenAddress;

    beforeEach(async function () {
      const tokenName = "Test Token";
      const tokenSymbol = "TEST";
      const initialSupply = ethers.utils.parseEther("1000000");

      const tx = await tokenCreator.connect(user1).createStandardToken(
        tokenName,
        tokenSymbol,
        initialSupply,
        18,
        { value: creationFee }
      );

      await tx.wait();

      const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
      tokenAddress = creatorTokens[0].tokenAddress;
    });

    it("Should allow creator to verify their token", async function () {
      await tokenCreator.connect(user1).verifyToken(tokenAddress);

      const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
      expect(creatorTokens[0].verified).to.equal(true);
    });

    it("Should not allow non-creator to verify token", async function () {
      await expect(
        tokenCreator.connect(user2).verifyToken(tokenAddress)
      ).to.be.revertedWith("Not token creator");
    });

    it("Should not allow verifying already verified token", async function () {
      await tokenCreator.connect(user1).verifyToken(tokenAddress);

      await expect(
        tokenCreator.connect(user1).verifyToken(tokenAddress)
      ).to.be.revertedWith("Already verified");
    });
  });

  describe("Fee Management", function () {
    it("Should collect fees correctly", async function () {
      const initialFees = await tokenCreator.totalFeesCollected();

      await tokenCreator.connect(user1).createStandardToken(
        "Test Token",
        "TEST",
        ethers.utils.parseEther("1000000"),
        18,
        { value: creationFee }
      );

      const finalFees = await tokenCreator.totalFeesCollected();
      expect(finalFees.sub(initialFees)).to.equal(creationFee);
    });

    it("Should allow owner to update fee recipient", async function () {
      const newFeeRecipient = user2.address;

      await tokenCreator.updateFeeRecipient(newFeeRecipient);
      expect(await tokenCreator.feeRecipient()).to.equal(newFeeRecipient);
    });

    it("Should not allow non-owner to update fee recipient", async function () {
      await expect(
        tokenCreator.connect(user1).updateFeeRecipient(user2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow owner to set fee exemptions", async function () {
      await tokenCreator.setFeeExempt(user1.address, true);
      expect(await tokenCreator.feeExempt(user1.address)).to.equal(true);
    });

    it("Should allow fee-exempt users to create tokens without payment", async function () {
      await tokenCreator.setFeeExempt(user1.address, true);

      await tokenCreator.connect(user1).createStandardToken(
        "Free Token",
        "FREE",
        ethers.utils.parseEther("1000000"),
        18,
        { value: 0 } // No payment needed
      );

      const creatorTokens = await tokenCreator.getCreatorTokens(user1.address);
      expect(creatorTokens.length).to.equal(1);
    });
  });

  describe("Emergency Controls", function () {
    it("Should allow owner to pause the contract", async function () {
      await tokenCreator.emergencyPause();
      expect(await tokenCreator.paused()).to.equal(true);
    });

    it("Should allow owner to unpause the contract", async function () {
      await tokenCreator.emergencyPause();
      await tokenCreator.emergencyUnpause();
      expect(await tokenCreator.paused()).to.equal(false);
    });

    it("Should not allow token creation when paused", async function () {
      await tokenCreator.emergencyPause();

      await expect(
        tokenCreator.connect(user1).createStandardToken(
          "Test Token",
          "TEST",
          ethers.utils.parseEther("1000000"),
          18,
          { value: creationFee }
        )
      ).to.be.revertedWith("Pausable: paused");
    });

    it("Should not allow non-owner to pause/unpause", async function () {
      await expect(
        tokenCreator.connect(user1).emergencyPause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Statistics", function () {
    it("Should track total tokens created", async function () {
      const initialCount = (await tokenCreator.getCreationStats())[0];

      await tokenCreator.connect(user1).createStandardToken(
        "Token 1",
        "T1",
        ethers.utils.parseEther("1000000"),
        18,
        { value: creationFee }
      );

      await tokenCreator.connect(user2).createStandardToken(
        "Token 2",
        "T2",
        ethers.utils.parseEther("1000000"),
        18,
        { value: creationFee }
      );

      const finalCount = (await tokenCreator.getCreationStats())[0];
      expect(finalCount.sub(initialCount)).to.equal(2);
    });

    it("Should track total fees collected", async function () {
      const initialFees = (await tokenCreator.getCreationStats())[1];

      await tokenCreator.connect(user1).createStandardToken(
        "Test Token",
        "TEST",
        ethers.utils.parseEther("1000000"),
        18,
        { value: creationFee }
      );

      const finalFees = (await tokenCreator.getCreationStats())[1];
      expect(finalFees.sub(initialFees)).to.equal(creationFee);
    });
  });

  describe("Input Validation", function () {
    it("Should reject empty token name", async function () {
      const tokenParams = {
        name: "",
        symbol: "TEST",
        initialSupply: ethers.utils.parseEther("1000000"),
        decimals: 18,
        maxSupply: 0,
        owner: user1.address,
        features: {
          burnable: false,
          mintable: false,
          pausable: false,
          capped: false,
          taxable: false,
          reflection: false,
          governance: false,
          flashMint: false,
          permit: false
        },
        taxConfig: {
          buyTax: 0,
          sellTax: 0,
          transferTax: 0,
          taxWallet: ethers.constants.AddressZero,
          taxOnBuys: false,
          taxOnSells: false,
          taxOnTransfers: false
        },
        reflectionConfig: {
          reflectionFee: 0,
          rewardToken: ethers.constants.AddressZero,
          autoClaim: false,
          minTokensForClaim: 0
        },
        salt: ethers.utils.randomBytes(32)
      };

      await expect(
        tokenCreator.connect(user1).createToken(tokenParams, { value: creationFee })
      ).to.be.revertedWith("Name required");
    });

    it("Should reject invalid decimals", async function () {
      await expect(
        tokenCreator.connect(user1).createStandardToken(
          "Test Token",
          "TEST",
          ethers.utils.parseEther("1000000"),
          19, // Invalid decimals
          { value: creationFee }
        )
      ).to.be.revertedWith("Invalid decimals");
    });

    it("Should reject zero initial supply", async function () {
      await expect(
        tokenCreator.connect(user1).createStandardToken(
          "Test Token",
          "TEST",
          0, // Zero supply
          18,
          { value: creationFee }
        )
      ).to.be.revertedWith("Initial supply required");
    });
  });
});
