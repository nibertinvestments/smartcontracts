const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aetherweb3Factory", function () {
  let factory;
  let poolDeployer;
  let owner;
  let user;
  let tokenA;
  let tokenB;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy PoolDeployer
    const PoolDeployer = await ethers.getContractFactory("Aetherweb3PoolDeployer");
    poolDeployer = await PoolDeployer.deploy();
    await poolDeployer.deployed();

    // Deploy Factory
    const Factory = await ethers.getContractFactory("Aetherweb3Factory");
    factory = await Factory.deploy(poolDeployer.address);
    await factory.deployed();

    // Set factory address in deployer
    await poolDeployer.setFactoryAddress(factory.address);

    // Deploy test tokens
    const TestToken = await ethers.getContractFactory("Aetherweb3Token");
    tokenA = await TestToken.deploy(ethers.utils.parseEther("1000000"));
    await tokenA.deployed();

    tokenB = await TestToken.deploy(ethers.utils.parseEther("1000000"));
    await tokenB.deployed();
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
      expect(await factory.owner()).to.equal(owner.address);
    });

    it("Should have correct pool deployer address", async function () {
      expect(await factory.poolDeployer()).to.equal(poolDeployer.address);
    });
  });

  describe("Fee Amounts", function () {
    it("Should have correct initial fee amounts", async function () {
      expect(await factory.feeAmountTickSpacing(500)).to.equal(10);
      expect(await factory.feeAmountTickSpacing(3000)).to.equal(60);
      expect(await factory.feeAmountTickSpacing(10000)).to.equal(200);
    });

    it("Should allow owner to enable new fee amounts", async function () {
      await factory.enableFeeAmount(2500, 50);
      expect(await factory.feeAmountTickSpacing(2500)).to.equal(50);
    });

    it("Should not allow non-owner to enable fee amounts", async function () {
      await expect(factory.connect(user).enableFeeAmount(2500, 50))
        .to.be.revertedWith("Not owner");
    });
  });

  describe("Pool Creation", function () {
    it("Should create a pool successfully", async function () {
      const tx = await factory.createPool(tokenA.address, tokenB.address, 3000);
      const receipt = await tx.wait();

      // Extract pool address from event
      const poolCreatedEvent = receipt.events.find(e => e.event === "PoolCreated");
      const poolAddress = poolCreatedEvent.args.pool;

      expect(poolAddress).to.not.equal(ethers.constants.AddressZero);
      expect(await factory.getPool(tokenA.address, tokenB.address, 3000)).to.equal(poolAddress);
    });

    it("Should not create duplicate pools", async function () {
      await factory.createPool(tokenA.address, tokenB.address, 3000);

      await expect(factory.createPool(tokenA.address, tokenB.address, 3000))
        .to.be.reverted;
    });

    it("Should handle token order correctly", async function () {
      // Create pool with tokens in reverse order
      const tx = await factory.createPool(tokenB.address, tokenA.address, 3000);
      const receipt = await tx.wait();

      const poolCreatedEvent = receipt.events.find(e => e.event === "PoolCreated");
      const poolAddress = poolCreatedEvent.args.pool;

      // Should be able to retrieve with either order
      expect(await factory.getPool(tokenA.address, tokenB.address, 3000)).to.equal(poolAddress);
      expect(await factory.getPool(tokenB.address, tokenA.address, 3000)).to.equal(poolAddress);
    });
  });

  describe("Ownership", function () {
    it("Should allow owner to transfer ownership", async function () {
      await factory.setOwner(user.address);
      expect(await factory.owner()).to.equal(user.address);
    });

    it("Should not allow non-owner to transfer ownership", async function () {
      await expect(factory.connect(user).setOwner(user.address))
        .to.be.revertedWith("Not owner");
    });
  });
});
