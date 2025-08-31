// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IModularContract.sol";
import "../interfaces/IModularTuple.sol";

contract GovernanceModular is IModularContract, Ownable, ReentrancyGuard {
    address public leaderContract;
    bool public paused;

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        address targetContract;
        bytes data;
        uint256 value;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool canceled;
        ProposalState state;
    }

    enum ProposalState {
        Pending,
        Active,
        Succeeded,
        Defeated,
        Queued,
        Executed,
        Canceled
    }

    struct Vote {
        bool hasVoted;
        bool support;
        uint256 votes;
        uint256 timestamp;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => Vote)) public votes;
    mapping(address => uint256) public votingPower;
    mapping(address => uint256) public lastVoteTime;

    uint256 public proposalCount;
    uint256 public constant VOTING_PERIOD = 50400; // 7 days in blocks (assuming 12s blocks)
    uint256 public constant EXECUTION_DELAY = 7200; // 1 day in blocks
    uint256 public constant PROPOSAL_THRESHOLD = 1000 ether; // Minimum voting power to propose
    uint256 public constant QUORUM_THRESHOLD = 10000 ether; // Minimum votes for quorum

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingPowerUpdated(address indexed user, uint256 oldPower, uint256 newPower);

    modifier onlyLeader() {
        require(msg.sender == leaderContract, "Only leader can call");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier validProposal(uint256 proposalId) {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        _;
    }

    constructor() {
        // Initialize with some default voting power for testing
        votingPower[owner()] = 10000 ether;
    }

    function setLeader(address _leader) external onlyOwner {
        leaderContract = _leader;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function updateVotingPower(address user, uint256 newPower) external onlyOwner {
        uint256 oldPower = votingPower[user];
        votingPower[user] = newPower;

        emit VotingPowerUpdated(user, oldPower, newPower);
    }

    function delegateVotingPower(address delegate, uint256 amount) external {
        require(votingPower[msg.sender] >= amount, "Insufficient voting power");

        votingPower[msg.sender] -= amount;
        votingPower[delegate] += amount;

        emit VotingPowerUpdated(msg.sender, votingPower[msg.sender] + amount, votingPower[msg.sender]);
        emit VotingPowerUpdated(delegate, votingPower[delegate] - amount, votingPower[delegate]);
    }

    function executeTuple(
        IModularTuple.TupleType tupleType,
        address caller,
        bytes calldata data
    ) external onlyLeader whenNotPaused nonReentrant returns (bytes memory) {

        if (tupleType == IModularTuple.TupleType.BeforeAction) {
            // Could validate governance-related actions
            return abi.encode(validateGovernanceAction(caller, data));
        }

        if (tupleType == IModularTuple.TupleType.BeforeExecution) {
            (address executor, bytes memory executionData) = abi.decode(data, (address, bytes));
            // Check if this is a governance execution
            return abi.encode(validateProposalExecution(executor, executionData));
        }

        return abi.encode(true);
    }

    function propose(
        string calldata title,
        string calldata description,
        address targetContract,
        bytes calldata data,
        uint256 value
    ) external whenNotPaused returns (uint256) {
        require(votingPower[msg.sender] >= PROPOSAL_THRESHOLD, "Insufficient voting power");
        require(bytes(title).length > 0, "Title required");
        require(bytes(description).length > 0, "Description required");

        uint256 proposalId = ++proposalCount;

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            title: title,
            description: description,
            targetContract: targetContract,
            data: data,
            value: value,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_PERIOD,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            canceled: false,
            state: ProposalState.Active
        });

        emit ProposalCreated(proposalId, msg.sender, title);
        return proposalId;
    }

    function castVote(uint256 proposalId, bool support) external whenNotPaused validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp <= proposal.endTime, "Voting period ended");

        Vote storage userVote = votes[proposalId][msg.sender];
        require(!userVote.hasVoted, "Already voted");

        uint256 voterPower = votingPower[msg.sender];
        require(voterPower > 0, "No voting power");

        // Record vote
        userVote.hasVoted = true;
        userVote.support = support;
        userVote.votes = voterPower;
        userVote.timestamp = block.timestamp;

        // Update proposal votes
        if (support) {
            proposal.forVotes += voterPower;
        } else {
            proposal.againstVotes += voterPower;
        }

        lastVoteTime[msg.sender] = block.timestamp;

        emit VoteCast(proposalId, msg.sender, support, voterPower);
    }

    function castVoteWithReason(
        uint256 proposalId,
        bool support,
        string calldata reason
    ) external whenNotPaused validProposal(proposalId) nonReentrant {
        // Same as castVote but with reason (for future use)
        castVote(proposalId, support);
    }

    function executeProposal(uint256 proposalId) external whenNotPaused validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Active, "Proposal not active");
        require(block.timestamp > proposal.endTime, "Voting period not ended");
        require(!proposal.executed, "Already executed");

        // Check if proposal succeeded
        bool succeeded = proposal.forVotes > proposal.againstVotes;
        bool hasQuorum = (proposal.forVotes + proposal.againstVotes) >= QUORUM_THRESHOLD;

        if (succeeded && hasQuorum) {
            proposal.state = ProposalState.Succeeded;

            // Queue for execution with delay
            if (block.timestamp >= proposal.endTime + EXECUTION_DELAY) {
                _executeProposal(proposal);
            } else {
                proposal.state = ProposalState.Queued;
            }
        } else {
            proposal.state = ProposalState.Defeated;
        }
    }

    function executeQueuedProposal(uint256 proposalId) external whenNotPaused validProposal(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Queued, "Proposal not queued");
        require(block.timestamp >= proposal.endTime + EXECUTION_DELAY, "Execution delay not met");

        _executeProposal(proposal);
    }

    function _executeProposal(Proposal storage proposal) internal {
        require(!proposal.executed, "Already executed");

        // Execute the proposal
        if (proposal.targetContract != address(0)) {
            (bool success,) = proposal.targetContract.call{value: proposal.value}(proposal.data);
            require(success, "Proposal execution failed");
        }

        proposal.executed = true;
        proposal.state = ProposalState.Executed;

        emit ProposalExecuted(proposal.id);
    }

    function cancelProposal(uint256 proposalId) external validProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Cannot cancel executed proposal");
        require(!proposal.canceled, "Already canceled");

        bool canCancel = (
            msg.sender == proposal.proposer ||
            msg.sender == owner() ||
            block.timestamp > proposal.endTime + 30 days // Emergency cancel after 30 days
        );

        require(canCancel, "Cannot cancel proposal");

        proposal.canceled = true;
        proposal.state = ProposalState.Canceled;

        emit ProposalCanceled(proposalId);
    }

    function validateGovernanceAction(address caller, bytes memory data) internal view returns (bool) {
        // Basic validation for governance actions
        if (caller == address(0)) return false;

        // Could add more sophisticated validation based on data
        return true;
    }

    function validateProposalExecution(address executor, bytes memory data) internal view returns (bool) {
        // Validate proposal execution
        if (executor == address(0)) return false;

        // Check if this is a valid proposal execution
        // This would need more sophisticated logic in production
        return true;
    }

    function getProposal(uint256 proposalId) external view returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalState(uint256 proposalId) external view returns (ProposalState) {
        return proposals[proposalId].state;
    }

    function getVote(uint256 proposalId, address voter) external view returns (Vote memory) {
        return votes[proposalId][voter];
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return votes[proposalId][voter].hasVoted;
    }

    function getVotingPower(address user) external view returns (uint256) {
        return votingPower[user];
    }

    function getProposalVotes(uint256 proposalId) external view returns (
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    ) {
        Proposal memory proposal = proposals[proposalId];
        return (proposal.forVotes, proposal.againstVotes, proposal.abstainVotes);
    }

    function canExecuteProposal(uint256 proposalId) external view returns (bool) {
        Proposal memory proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Succeeded && proposal.state != ProposalState.Queued) {
            return false;
        }

        if (proposal.state == ProposalState.Queued) {
            return block.timestamp >= proposal.endTime + EXECUTION_DELAY;
        }

        return block.timestamp >= proposal.endTime;
    }

    function getActiveProposals() external view returns (uint256[] memory) {
        uint256 activeCount = 0;

        // Count active proposals
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (proposals[i].state == ProposalState.Active) {
                activeCount++;
            }
        }

        uint256[] memory activeProposals = new uint256[](activeCount);
        uint256 index = 0;

        // Collect active proposals
        for (uint256 i = 1; i <= proposalCount; i++) {
            if (proposals[i].state == ProposalState.Active) {
                activeProposals[index++] = i;
            }
        }

        return activeProposals;
    }

    function getContractName() external pure returns (string memory) {
        return "GovernanceModular";
    }

    function getContractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    function getContractType() external pure returns (bytes32) {
        return keccak256("GOVERNANCE");
    }

    function validate(bytes calldata data) external view returns (bool) {
        // Validate governance data
        if (data.length < 32) return false;
        (uint256 proposalId) = abi.decode(data, (uint256));
        return proposalId > 0 && proposalId <= proposalCount;
    }

    function estimateGas(bytes calldata data) external view returns (uint256) {
        return 100000; // Conservative estimate for governance operations
    }

    function isActive() external view returns (bool) {
        return !paused && leaderContract != address(0);
    }

    function getMetadata() external view returns (
        string memory name,
        string memory version,
        bytes32 contractType,
        bool active,
        address leader
    ) {
        return (
            this.getContractName(),
            this.getContractVersion(),
            this.getContractType(),
            this.isActive(),
            leaderContract
        );
    }

    // Emergency function
    function emergencyCancelProposal(uint256 proposalId) external onlyOwner {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.canceled = true;
        proposal.state = ProposalState.Canceled;

        emit ProposalCanceled(proposalId);
    }

    // Receive ETH for proposals that need value
    receive() external payable {}
}
