// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";

abstract contract YNXGovernorCountingVeto is Governor {
    struct ProposalVote {
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        uint256 vetoVotes;
        mapping(address voter => bool) hasVoted;
    }

    mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

    function COUNTING_MODE() public pure virtual override returns (string memory) {
        return "support=for,against,abstain,veto&quorum=excluding_abstain&veto=against_with_veto";
    }

    function hasVoted(uint256 proposalId, address account) public view virtual override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[account];
    }

    function proposalVotes(uint256 proposalId)
        public
        view
        returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes, uint256 vetoVotes)
    {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.againstVotes, proposalVote.forVotes, proposalVote.abstainVotes, proposalVote.vetoVotes);
    }

    function _countVote(
        uint256 proposalId,
        address account,
        uint8 support,
        uint256 totalWeight,
        bytes memory /*params*/
    ) internal virtual override returns (uint256) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];

        if (proposalVote.hasVoted[account]) {
            revert GovernorAlreadyCastVote(account);
        }
        proposalVote.hasVoted[account] = true;

        if (support == 0) {
            proposalVote.againstVotes += totalWeight;
        } else if (support == 1) {
            proposalVote.forVotes += totalWeight;
        } else if (support == 2) {
            proposalVote.abstainVotes += totalWeight;
        } else if (support == 3) {
            proposalVote.vetoVotes += totalWeight;
        } else {
            revert GovernorInvalidVoteType();
        }

        return totalWeight;
    }
}
