// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IAetherweb3DAO
 * @dev Interface for the Aetherweb3DAO contract
 */
interface IAetherweb3DAO {
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

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function castVote(uint256 proposalId, uint8 support) external;

    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external;

    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function execute(uint256 proposalId) external payable;

    function cancel(uint256 proposalId) external;

    function state(uint256 proposalId) external view returns (ProposalState);

    function getProposal(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool canceled
    );

    function getReceipt(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        uint8 support,
        uint256 votes
    );

    function governanceToken() external view returns (address);
    function timelock() external view returns (address);
    function proposalCount() external view returns (uint256);
    function proposals(uint256 proposalId) external view returns (
        uint256 id,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes,
        bool executed,
        bool canceled
    );
}
