const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Aetherweb3DAO", function () {
    let dao, timelock, token, owner, proposer, voter1, voter2, voter3;
    const VOTING_DELAY = 1; // 1 second for testing
    const VOTING_PERIOD = 50; // 50 blocks for testing
    const PROPOSAL_THRESHOLD = ethers.utils.parseEther("100000"); // 100k tokens
    const QUORUM_PERCENTAGE = 10;

    beforeEach(async function () {
        [owner, proposer, voter1, voter2, voter3] = await ethers.getSigners();

        // Deploy token
        const Token = await ethers.getContractFactory("Aetherweb3Token");
        token = await Token.deploy(
            "Aetherweb3 Token",
            "AETH",
            ethers.utils.parseEther("1000000"), // 1M tokens
            owner.address
        );
        await token.deployed();

        // Deploy timelock
        const Timelock = await ethers.getContractFactory("Aetherweb3Timelock");
        timelock = await Timelock.deploy(VOTING_DELAY);
        await timelock.deployed();

        // Deploy DAO
        const DAO = await ethers.getContractFactory("Aetherweb3DAO");
        dao = await DAO.deploy(token.address, timelock.address);
        await dao.deployed();

        // Transfer ownership of timelock to DAO
        await timelock.transferOwnership(dao.address);

        // Distribute tokens
        await token.transfer(proposer.address, PROPOSAL_THRESHOLD);
        await token.transfer(voter1.address, ethers.utils.parseEther("50000"));
        await token.transfer(voter2.address, ethers.utils.parseEther("30000"));
        await token.transfer(voter3.address, ethers.utils.parseEther("20000"));
    });

    describe("Proposal Creation", function () {
        it("Should create a proposal", async function () {
            const targets = [token.address];
            const values = [0];
            const calldatas = [token.interface.encodeFunctionData("name")];
            const description = "Test proposal";

            await expect(dao.connect(proposer).propose(targets, values, calldatas, description))
                .to.emit(dao, "ProposalCreated")
                .withArgs(1, proposer.address, targets, values, calldatas, description, anyValue, anyValue);
        });

        it("Should reject proposal from insufficient balance", async function () {
            const targets = [token.address];
            const values = [0];
            const calldatas = [token.interface.encodeFunctionData("name")];
            const description = "Test proposal";

            await expect(dao.connect(voter3).propose(targets, values, calldatas, description))
                .to.be.revertedWith("Aetherweb3DAO: proposer balance below threshold");
        });

        it("Should reject empty proposal", async function () {
            const targets = [];
            const values = [];
            const calldatas = [];
            const description = "Empty proposal";

            await expect(dao.connect(proposer).propose(targets, values, calldatas, description))
                .to.be.revertedWith("Aetherweb3DAO: empty proposal");
        });
    });

    describe("Voting", function () {
        let proposalId;

        beforeEach(async function () {
            // Create proposal
            const targets = [token.address];
            const values = [0];
            const calldatas = [token.interface.encodeFunctionData("name")];
            const description = "Test proposal";

            const tx = await dao.connect(proposer).propose(targets, values, calldatas, description);
            const receipt = await tx.wait();
            proposalId = receipt.events[0].args.proposalId;

            // Advance time past voting delay
            await ethers.provider.send("evm_increaseTime", [VOTING_DELAY + 1]);
            await ethers.provider.send("evm_mine");
        });

        it("Should cast vote", async function () {
            await expect(dao.connect(voter1).castVote(proposalId, 1))
                .to.emit(dao, "VoteCast")
                .withArgs(voter1.address, proposalId, 1, ethers.utils.parseEther("50000"), "");
        });

        it("Should cast vote with reason", async function () {
            const reason = "I support this proposal";
            await expect(dao.connect(voter1).castVoteWithReason(proposalId, 1, reason))
                .to.emit(dao, "VoteCast")
                .withArgs(voter1.address, proposalId, 1, ethers.utils.parseEther("50000"), reason);
        });

        it("Should reject double voting", async function () {
            await dao.connect(voter1).castVote(proposalId, 1);
            await expect(dao.connect(voter1).castVote(proposalId, 1))
                .to.be.revertedWith("Aetherweb3DAO: already voted");
        });

        it("Should reject vote on inactive proposal", async function () {
            // Advance time past voting period
            await ethers.provider.send("evm_increaseTime", [VOTING_PERIOD + 1]);
            await ethers.provider.send("evm_mine");

            await expect(dao.connect(voter1).castVote(proposalId, 1))
                .to.be.revertedWith("Aetherweb3DAO: proposal not active");
        });
    });

    describe("Proposal Execution", function () {
        let proposalId;

        beforeEach(async function () {
            // Create proposal
            const targets = [timelock.address];
            const values = [0];
            const calldatas = [timelock.interface.encodeFunctionData("setDelay", [3])];
            const description = "Update timelock delay";

            const tx = await dao.connect(proposer).propose(targets, values, calldatas, description);
            const receipt = await tx.wait();
            proposalId = receipt.events[0].args.proposalId;

            // Advance time past voting delay
            await ethers.provider.send("evm_increaseTime", [VOTING_DELAY + 1]);
            await ethers.provider.send("evm_mine");

            // Cast votes (need quorum)
            await dao.connect(voter1).castVote(proposalId, 1); // 50k votes
            await dao.connect(voter2).castVote(proposalId, 1); // 30k votes
            await dao.connect(voter3).castVote(proposalId, 1); // 20k votes
            // Total: 100k votes, quorum: 10% of 1M = 100k
        });

        it("Should execute successful proposal", async function () {
            // Advance time past voting period
            await ethers.provider.send("evm_increaseTime", [VOTING_PERIOD + 1]);
            await ethers.provider.send("evm_mine");

            // Check proposal state
            expect(await dao.state(proposalId)).to.equal(3); // Succeeded

            // Execute proposal
            await expect(dao.execute(proposalId))
                .to.emit(dao, "ProposalExecuted")
                .withArgs(proposalId);
        });

        it("Should reject execution of unsuccessful proposal", async function () {
            // Only voter1 votes for, voter2 and voter3 vote against
            await dao.connect(voter1).castVote(proposalId, 1);
            await dao.connect(voter2).castVote(proposalId, 0);
            await dao.connect(voter3).castVote(proposalId, 0);

            // Advance time past voting period
            await ethers.provider.send("evm_increaseTime", [VOTING_PERIOD + 1]);
            await ethers.provider.send("evm_mine");

            // Check proposal state
            expect(await dao.state(proposalId)).to.equal(4); // Defeated

            // Try to execute
            await expect(dao.execute(proposalId))
                .to.be.revertedWith("Aetherweb3DAO: proposal not successful");
        });
    });

    describe("Proposal Cancellation", function () {
        let proposalId;

        beforeEach(async function () {
            // Create proposal
            const targets = [token.address];
            const values = [0];
            const calldatas = [token.interface.encodeFunctionData("name")];
            const description = "Test proposal";

            const tx = await dao.connect(proposer).propose(targets, values, calldatas, description);
            const receipt = await tx.wait();
            proposalId = receipt.events[0].args.proposalId;
        });

        it("Should cancel proposal by proposer", async function () {
            await expect(dao.connect(proposer).cancel(proposalId))
                .to.emit(dao, "ProposalCanceled")
                .withArgs(proposalId);
        });

        it("Should cancel proposal by token holder with sufficient balance", async function () {
            await expect(dao.connect(voter1).cancel(proposalId))
                .to.emit(dao, "ProposalCanceled")
                .withArgs(proposalId);
        });

        it("Should reject cancellation after voting starts", async function () {
            // Advance time past voting delay
            await ethers.provider.send("evm_increaseTime", [VOTING_DELAY + 1]);
            await ethers.provider.send("evm_mine");

            await expect(dao.connect(proposer).cancel(proposalId))
                .to.be.revertedWith("Aetherweb3DAO: proposal not pending");
        });
    });

    describe("View Functions", function () {
        it("Should return correct proposal state", async function () {
            // Create proposal
            const targets = [token.address];
            const values = [0];
            const calldatas = [token.interface.encodeFunctionData("name")];
            const description = "Test proposal";

            const tx = await dao.connect(proposer).propose(targets, values, calldatas, description);
            const receipt = await tx.wait();
            const proposalId = receipt.events[0].args.proposalId;

            // Initially pending
            expect(await dao.state(proposalId)).to.equal(0); // Pending

            // After voting delay
            await ethers.provider.send("evm_increaseTime", [VOTING_DELAY + 1]);
            await ethers.provider.send("evm_mine");
            expect(await dao.state(proposalId)).to.equal(1); // Active

            // After voting period
            await ethers.provider.send("evm_increaseTime", [VOTING_PERIOD + 1]);
            await ethers.provider.send("evm_mine");
            expect(await dao.state(proposalId)).to.equal(4); // Defeated (no votes)
        });

        it("Should return correct proposal details", async function () {
            const targets = [token.address];
            const values = [0];
            const calldatas = [token.interface.encodeFunctionData("name")];
            const description = "Test proposal";

            const tx = await dao.connect(proposer).propose(targets, values, calldatas, description);
            const receipt = await tx.wait();
            const proposalId = receipt.events[0].args.proposalId;

            const proposal = await dao.getProposal(proposalId);
            expect(proposal.id).to.equal(proposalId);
            expect(proposal.proposer).to.equal(proposer.address);
            expect(proposal.description).to.equal(description);
            expect(proposal.targets).to.deep.equal(targets);
        });
    });
});
