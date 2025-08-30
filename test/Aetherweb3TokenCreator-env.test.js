const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aetherweb3TokenCreator Environment Configuration", function () {
  let tokenCreator;
  let owner;
  let user;
  let feeRecipient;
  let creationFee;

  beforeEach(async function () {
    // Load environment variables
    feeRecipient = process.env.FEE_RECIPIENT || "0xD10AA6E922a4F1804db6Ad3f0960Ed3dc116DD57";
    creationFee = process.env.CREATION_FEE || ethers.utils.parseEther("0.005");

    [owner, user] = await ethers.getSigners();

    const Aetherweb3TokenCreator = await ethers.getContractFactory("Aetherweb3TokenCreator");
    tokenCreator = await Aetherweb3TokenCreator.deploy(feeRecipient, creationFee);
    await tokenCreator.deployed();
  });

  describe("Environment Configuration", function () {
    it("Should initialize with correct fee recipient from environment", async function () {
      expect(await tokenCreator.feeRecipient()).to.equal(feeRecipient);
    });

    it("Should initialize with correct creation fee from environment", async function () {
      expect(await tokenCreator.creationFee()).to.equal(creationFee);
    });

    it("Should allow owner to update fee recipient", async function () {
      const newRecipient = user.address;
      await tokenCreator.updateFeeRecipient(newRecipient);
      expect(await tokenCreator.feeRecipient()).to.equal(newRecipient);
    });

    it("Should allow owner to update creation fee", async function () {
      const newFee = ethers.utils.parseEther("0.01");
      await tokenCreator.updateCreationFee(newFee);
      expect(await tokenCreator.creationFee()).to.equal(newFee);
    });

    it("Should reject invalid fee recipient", async function () {
      await expect(
        tokenCreator.updateFeeRecipient(ethers.constants.AddressZero)
      ).to.be.revertedWith("Invalid fee recipient");
    });

    it("Should reject invalid creation fee", async function () {
      await expect(
        tokenCreator.updateCreationFee(0)
      ).to.be.revertedWith("Invalid creation fee");
    });
  });

  describe("Token Creation with Environment Fees", function () {
    it("Should create token with correct fee from environment", async function () {
      const initialBalance = await ethers.provider.getBalance(feeRecipient);

      // Create a standard token
      await tokenCreator.createStandardToken(
        "Test Token",
        "TEST",
        ethers.utils.parseEther("1000000"),
        18,
        { value: creationFee }
      );

      const finalBalance = await ethers.provider.getBalance(feeRecipient);
      expect(finalBalance.sub(initialBalance)).to.equal(creationFee);
    });

    it("Should reject token creation with insufficient fee", async function () {
      const insufficientFee = creationFee.sub(1);

      await expect(
        tokenCreator.createStandardToken(
          "Test Token",
          "TEST",
          ethers.utils.parseEther("1000000"),
          18,
          { value: insufficientFee }
        )
      ).to.be.revertedWith("Insufficient fee");
    });

    it("Should allow fee-exempt addresses to create tokens without fee", async function () {
      await tokenCreator.connect(owner).setFeeExempt(user.address, true);

      await tokenCreator.connect(user).createStandardToken(
        "Test Token",
        "TEST",
        ethers.utils.parseEther("1000000"),
        18,
        { value: 0 }
      );

      // Should succeed without paying fee
    });
  });

  describe("Fee Management", function () {
    it("Should allow owner to withdraw accumulated fees", async function () {
      // Create a token to accumulate fees
      await tokenCreator.createStandardToken(
        "Test Token",
        "TEST",
        ethers.utils.parseEther("1000000"),
        18,
        { value: creationFee }
      );

      const contractBalance = await ethers.provider.getBalance(tokenCreator.address);
      expect(contractBalance).to.equal(creationFee);

      const initialOwnerBalance = await ethers.provider.getBalance(owner.address);

      // Withdraw fees
      await tokenCreator.withdrawFees();

      const finalContractBalance = await ethers.provider.getBalance(tokenCreator.address);
      expect(finalContractBalance).to.equal(0);
    });

    it("Should reject fee withdrawal when no fees available", async function () {
      await expect(
        tokenCreator.withdrawFees()
      ).to.be.revertedWith("No fees to withdraw");
    });
  });
});
