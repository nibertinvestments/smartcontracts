// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAetherweb3DAO.sol";

/**
 * @title Aetherweb3DAO
 * @dev Decentralized Autonomous Organization for Aetherweb3 governance
 * Allows token holders to create and vote on proposals
 */
contract Aetherweb3DAO is IAetherweb3DAO, ReentrancyGuard, Ownable {
    // Governance token
    IERC20 public immutable governanceToken;

    // Timelock contract for delayed execution
    address public timelock;

    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        mapping(address => Receipt) receipts;
    }

    // Vote receipt
    struct Receipt {
        bool hasVoted;
        uint8 support; // 0 = Against, 1 = For, 2 = Abstain
        uint256 votes;
    }

    // Proposal state
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

    // Governance parameters
    uint256 public constant VOTING_PERIOD = 7 days; // 7 days voting period
    uint256 public constant VOTING_DELAY = 1 days; // 1 day delay before voting starts
    uint256 public constant PROPOSAL_THRESHOLD = 100000 * 10**18; // 100k tokens to create proposal
    uint256 public constant QUORUM_PERCENTAGE = 10; // 10% of total supply needed for quorum

    // State variables
    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public latestProposalIds;

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        uint256 startTime,
        uint256 endTime
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event TimelockSet(address indexed oldTimelock, address indexed newTimelock);

    // Modifiers
    modifier onlyTimelock() {
        require(msg.sender == timelock, "Aetherweb3DAO: caller must be timelock");
        _;
    }

    /**
     * @dev Constructor
     * @param _governanceToken Address of the governance token
     * @param _timelock Address of the timelock contract
     */
    constructor(address _governanceToken, address _timelock) {
        require(_governanceToken != address(0), "Aetherweb3DAO: invalid governance token");
        require(_timelock != address(0), "Aetherweb3DAO: invalid timelock");

        governanceToken = IERC20(_governanceToken);
        timelock = _timelock;
    }

    /**
     * @dev Create a new proposal
     * @param targets Target addresses for proposal calls
     * @param values ETH values for proposal calls
     * @param calldatas Calldata for proposal calls
     * @param description Proposal description
     * @return proposalId The ID of the created proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256) {
        require(
            governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "Aetherweb3DAO: proposer balance below threshold"
        );
        require(targets.length == values.length, "Aetherweb3DAO: invalid proposal length");
        require(targets.length == calldatas.length, "Aetherweb3DAO: invalid proposal length");
        require(targets.length > 0, "Aetherweb3DAO: empty proposal");
        require(targets.length <= 10, "Aetherweb3DAO: too many actions");

        uint256 proposalId = ++proposalCount;
        Proposal storage proposal = proposals[proposalId];

        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.targets = targets;
        proposal.values = values;
        proposal.calldatas = calldatas;
        proposal.description = description;
        proposal.startTime = block.timestamp + VOTING_DELAY;
        proposal.endTime = proposal.startTime + VOTING_PERIOD;

        latestProposalIds[msg.sender] = proposalId;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            calldatas,
            description,
            proposal.startTime,
            proposal.endTime
        );

        return proposalId;
    }

    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The proposal ID
     * @param support Vote type (0 = Against, 1 = For, 2 = Abstain)
     */
    function castVote(uint256 proposalId, uint8 support) external {
        _castVote(msg.sender, proposalId, support, "");
    }

    /**
     * @dev Cast a vote with reason
     * @param proposalId The proposal ID
     * @param support Vote type (0 = Against, 1 = For, 2 = Abstain)
     * @param reason Vote reason
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        _castVote(msg.sender, proposalId, support, reason);
    }

    /**
     * @dev Cast vote by signature (for gasless voting)
     * @param proposalId The proposal ID
     * @param support Vote type
     * @param v Signature v
     * @param r Signature r
     * @param s Signature s
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Aetherweb3DAO")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("CastVote(uint256 proposalId,uint8 support)"),
                proposalId,
                support
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "Aetherweb3DAO: invalid signature");

        _castVote(signatory, proposalId, support, "");
    }

    /**
     * @dev Internal vote casting function
     */
    function _castVote(
        address voter,
        uint256 proposalId,
        uint8 support,
        string memory reason
    ) internal {
        require(state(proposalId) == ProposalState.Active, "Aetherweb3DAO: proposal not active");
        require(support <= 2, "Aetherweb3DAO: invalid vote type");

        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];

        require(!receipt.hasVoted, "Aetherweb3DAO: already voted");

        uint256 votes = governanceToken.balanceOf(voter);
        require(votes > 0, "Aetherweb3DAO: no voting power");

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        emit VoteCast(voter, proposalId, support, votes, reason);
    }

    /**
     * @dev Execute a successful proposal
     * @param proposalId The proposal ID to execute
     */
    function execute(uint256 proposalId) external payable {
        require(state(proposalId) == ProposalState.Succeeded, "Aetherweb3DAO: proposal not successful");

        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            (bool success, ) = proposal.targets[i].call{value: proposal.values[i]}(
                proposal.calldatas[i]
            );
            require(success, "Aetherweb3DAO: execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Cancel a proposal
     * @param proposalId The proposal ID to cancel
     */
    function cancel(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Pending, "Aetherweb3DAO: proposal not pending");

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer ||
            governanceToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "Aetherweb3DAO: insufficient rights to cancel"
        );

        proposal.canceled = true;
        emit ProposalCanceled(proposalId);
    }

    /**
     * @dev Get the state of a proposal
     * @param proposalId The proposal ID
     * @return The proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId <= proposalCount && proposalId > 0, "Aetherweb3DAO: invalid proposal id");

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }

        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (block.timestamp <= proposal.startTime) {
            return ProposalState.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalState.Active;
        }

        if (_quorumReached(proposalId) && proposal.forVotes > proposal.againstVotes) {
            return ProposalState.Succeeded;
        }

        return ProposalState.Defeated;
    }

    /**
     * @dev Check if quorum is reached
     */
    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = proposals[proposalId];
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        uint256 totalSupply = governanceToken.totalSupply();

        return totalVotes >= (totalSupply * QUORUM_PERCENTAGE) / 100;
    }

    /**
     * @dev Get proposal details
     */
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
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            proposal.description,
            proposal.startTime,
            proposal.endTime,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.abstainVotes,
            proposal.executed,
            proposal.canceled
        );
    }

    /**
     * @dev Get vote receipt for a voter on a proposal
     */
    function getReceipt(uint256 proposalId, address voter) external view returns (
        bool hasVoted,
        uint8 support,
        uint256 votes
    ) {
        Receipt storage receipt = proposals[proposalId].receipts[voter];
        return (receipt.hasVoted, receipt.support, receipt.votes);
    }

    /**
     * @dev Update timelock address (only owner)
     */
    function setTimelock(address newTimelock) external onlyOwner {
        require(newTimelock != address(0), "Aetherweb3DAO: invalid timelock");
        address oldTimelock = timelock;
        timelock = newTimelock;
        emit TimelockSet(oldTimelock, newTimelock);
    }

    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
}
