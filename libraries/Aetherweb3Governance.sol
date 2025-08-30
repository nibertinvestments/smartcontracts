// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Aetherweb3Math.sol";

/**
 * @title Aetherweb3Governance
 * @dev Governance utility library for DAO operations and voting mechanisms
 * @notice Provides voting calculations, proposal management, and governance utilities
 */
library Aetherweb3Governance {
    using Aetherweb3Math for uint256;

    // Voting types
    enum VoteType { Against, For, Abstain }

    // Proposal states
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 startTime;
        uint256 endTime;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }

    // Vote receipt
    struct Receipt {
        bool hasVoted;
        VoteType voteType;
        uint256 votes;
    }

    // Governance parameters
    struct GovernanceParams {
        uint256 votingDelay;      // Delay before voting starts (blocks)
        uint256 votingPeriod;     // Length of voting period (blocks)
        uint256 proposalThreshold; // Minimum tokens to create proposal
        uint256 quorumVotes;      // Minimum votes for quorum
        uint256 timelockDelay;    // Timelock delay for execution
    }

    /**
     * @dev Calculates voting power based on token balance and lock duration
     * @param balance Token balance
     * @param lockDuration Lock duration in seconds
     * @param maxLockDuration Maximum lock duration
     * @param votingMultiplier Maximum voting multiplier
     * @return votingPower Calculated voting power
     */
    function calculateVotingPower(
        uint256 balance,
        uint256 lockDuration,
        uint256 maxLockDuration,
        uint256 votingMultiplier
    ) internal pure returns (uint256 votingPower) {
        if (lockDuration == 0 || maxLockDuration == 0) {
            return balance;
        }

        // Calculate multiplier based on lock duration
        uint256 multiplier = Aetherweb3Math.wmul(
            votingMultiplier,
            lockDuration
        ) / maxLockDuration;

        // Ensure multiplier is at least 1 (100%)
        multiplier = Aetherweb3Math.max(multiplier, Aetherweb3Math.WAD);

        votingPower = Aetherweb3Math.wmul(balance, multiplier);
    }

    /**
     * @dev Calculates quadratic voting power
     * @param balance Token balance
     * @return votingPower Square root of balance for quadratic voting
     */
    function calculateQuadraticVotingPower(uint256 balance) internal pure returns (uint256 votingPower) {
        return Aetherweb3Math.sqrt(balance);
    }

    /**
     * @dev Checks if a proposal has reached quorum
     * @param forVotes Votes in favor
     * @param againstVotes Votes against
     * @param abstainVotes Abstain votes
     * @param totalSupply Total token supply
     * @param quorumPercentage Required quorum percentage (basis points)
     * @return hasQuorum True if quorum is reached
     */
    function hasQuorum(
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        uint256 totalSupply,
        uint256 quorumPercentage
    ) internal pure returns (bool hasQuorum) {
        uint256 totalVotes = forVotes + againstVotes + abstainVotes;
        uint256 quorumAmount = Aetherweb3Math.percent(totalSupply, quorumPercentage);
        return totalVotes >= quorumAmount;
    }

    /**
     * @dev Determines the outcome of a proposal
     * @param forVotes Votes in favor
     * @param againstVotes Votes against
     * @param abstainVotes Abstain votes
     * @return succeeded True if proposal succeeded
     */
    function proposalSucceeded(
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    ) internal pure returns (bool succeeded) {
        return forVotes > againstVotes;
    }

    /**
     * @dev Calculates proposal state based on current conditions
     * @param proposal The proposal to check
     * @param blockNumber Current block number
     * @param totalSupply Total token supply
     * @param quorumPercentage Required quorum percentage
     * @return state Current proposal state
     */
    function getProposalState(
        Proposal storage proposal,
        uint256 blockNumber,
        uint256 totalSupply,
        uint256 quorumPercentage
    ) internal view returns (ProposalState state) {
        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (blockNumber <= proposal.startTime) {
            return ProposalState.Pending;
        }

        if (blockNumber <= proposal.endTime) {
            return ProposalState.Active;
        }

        if (!hasQuorum(
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            totalSupply,
            quorumPercentage
        )) {
            return ProposalState.Defeated;
        }

        if (proposalSucceeded(
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes
        )) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }

    /**
     * @dev Validates proposal parameters
     * @param targets Target addresses
     * @param values ETH values
     * @param signatures Function signatures
     * @param calldatas Function call data
     * @return valid True if proposal is valid
     */
    function validateProposal(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) internal pure returns (bool valid) {
        if (targets.length == 0) return false;
        if (targets.length != values.length) return false;
        if (targets.length != signatures.length) return false;
        if (targets.length != calldatas.length) return false;

        for (uint256 i = 0; i < targets.length; i++) {
            if (targets[i] == address(0)) return false;
        }

        return true;
    }

    /**
     * @dev Calculates proposal hash for unique identification
     * @param targets Target addresses
     * @param values ETH values
     * @param signatures Function signatures
     * @param calldatas Function call data
     * @param descriptionHash Hash of proposal description
     * @return proposalHash Unique proposal hash
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal pure returns (bytes32 proposalHash) {
        return keccak256(abi.encode(
            targets,
            values,
            signatures,
            calldatas,
            descriptionHash
        ));
    }

    /**
     * @dev Calculates delegation hash for meta-transactions
     * @param delegatee Address to delegate to
     * @param nonce Unique nonce
     * @param expiry Expiry timestamp
     * @return delegationHash Unique delegation hash
     */
    function hashDelegation(
        address delegatee,
        uint256 nonce,
        uint256 expiry
    ) internal pure returns (bytes32 delegationHash) {
        return keccak256(abi.encode(
            delegatee,
            nonce,
            expiry
        ));
    }

    /**
     * @dev Calculates vote hash for meta-transactions
     * @param proposalId Proposal ID
     * @param voteType Type of vote
     * @param voter Voter address
     * @param nonce Unique nonce
     * @param expiry Expiry timestamp
     * @return voteHash Unique vote hash
     */
    function hashVote(
        uint256 proposalId,
        VoteType voteType,
        address voter,
        uint256 nonce,
        uint256 expiry
    ) internal pure returns (bytes32 voteHash) {
        return keccak256(abi.encode(
            proposalId,
            voteType,
            voter,
            nonce,
            expiry
        ));
    }
}
