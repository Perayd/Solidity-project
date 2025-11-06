// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SimpleDAO {
    using Counters for Counters.Counter;
    Counters.Counter private _proposalIds;

    IERC20 public governanceToken;
    uint256 public votingPeriod; // seconds

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 start; // timestamp
        uint256 end;   // timestamp
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted; // proposalId => voter => voted

    event ProposalCreated(uint256 id, address proposer, string description, uint256 start, uint256 end);
    event Voted(uint256 proposalId, address voter, bool support, uint256 weight);
    event Executed(uint256 proposalId);

    constructor(IERC20 token_, uint256 votingPeriodSeconds_) {
        governanceToken = token_;
        votingPeriod = votingPeriodSeconds_;
    }

    function propose(string calldata description) external returns (uint256) {
        _proposalIds.increment();
        uint256 id = _proposalIds.current();
        uint256 start = block.timestamp;
        uint256 end = block.timestamp + votingPeriod;
        proposals[id] = Proposal({
            id: id,
            proposer: msg.sender,
            description: description,
            start: start,
            end: end,
            forVotes: 0,
            againstVotes: 0,
            executed: false
        });
        emit ProposalCreated(id, msg.sender, description, start, end);
        return id;
    }

    function vote(uint256 proposalId, bool support) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.start && block.timestamp <= p.end, "Voting closed");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = governanceToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.end, "Voting not ended");
        require(!p.executed, "Already executed");
        p.executed = true;
        // Simple execution model: nothing to run automatically.
        // Off-chain: listeners can check `forVotes` vs `againstVotes` and carry out actions.
        emit Executed(proposalId);
    }

    // Convenience view
    function proposalVotes(uint256 proposalId) external view returns (uint256 forVotes, uint256 againstVotes) {
        Proposal storage p = proposals[proposalId];
        return (p.forVotes, p.againstVotes);
    }
}
