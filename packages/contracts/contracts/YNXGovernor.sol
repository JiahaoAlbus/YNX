// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";
import { GovernorSettings } from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import { GovernorVotesQuorumFraction } from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovernorTimelockControl } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { YNXGovernorCountingVeto } from "./YNXGovernorCountingVeto.sol";

contract YNXGovernor is
    Governor,
    GovernorSettings,
    YNXGovernorCountingVeto,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    IERC20 public immutable nyxt;
    address public immutable treasury;

    uint256 public immutable proposalDeposit;

    // 33.4% veto threshold, in basis points.
    uint256 public constant VETO_BPS = 3340;
    uint256 public constant BPS_DENOMINATOR = 10_000;

    mapping(uint256 proposalId => bool finalized) public proposalDepositFinalized;

    error DepositAlreadyFinalized();
    error DepositNotFinalizable();

    constructor(
        IVotes nyxtVotes,
        IERC20 nyxtErc20,
        TimelockController timelock,
        address treasury_,
        uint48 votingDelayBlocks,
        uint32 votingPeriodBlocks,
        uint256 proposalThresholdVotes,
        uint256 proposalDepositAmount,
        uint256 quorumPercent
    )
        Governor("YNXGovernor")
        GovernorSettings(votingDelayBlocks, votingPeriodBlocks, proposalThresholdVotes)
        GovernorVotes(nyxtVotes)
        GovernorVotesQuorumFraction(quorumPercent)
        GovernorTimelockControl(timelock)
    {
        nyxt = nyxtErc20;
        treasury = treasury_;
        proposalDeposit = proposalDepositAmount;
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        uint256 proposalId = super.propose(targets, values, calldatas, description);

        if (proposalDeposit > 0) {
            nyxt.transferFrom(msg.sender, address(this), proposalDeposit);
        }

        return proposalId;
    }

    function proposalVetoed(uint256 proposalId) public view returns (bool) {
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes, uint256 vetoVotes) = proposalVotes(proposalId);
        uint256 totalVotes = againstVotes + forVotes + abstainVotes + vetoVotes;
        if (totalVotes == 0) return false;
        return (vetoVotes * BPS_DENOMINATOR) >= (totalVotes * VETO_BPS);
    }

    function finalizeProposalDeposit(uint256 proposalId) external {
        if (proposalDepositFinalized[proposalId]) revert DepositAlreadyFinalized();

        ProposalState st = state(proposalId);
        if (
            st == ProposalState.Pending || st == ProposalState.Active || st == ProposalState.Succeeded
                || st == ProposalState.Queued
        ) {
            revert DepositNotFinalizable();
        }

        proposalDepositFinalized[proposalId] = true;
        if (proposalDeposit == 0) return;

        address proposer = proposalProposer(proposalId);
        if (proposer == address(0)) return;

        if (proposalVetoed(proposalId)) {
            nyxt.transfer(treasury, proposalDeposit);
        } else {
            nyxt.transfer(proposer, proposalDeposit);
        }
    }

    // --- Quorum / Success rules ---

    function _quorumReached(uint256 proposalId) internal view override returns (bool) {
        (uint256 againstVotes, uint256 forVotes,, uint256 vetoVotes) = proposalVotes(proposalId);
        uint256 participating = againstVotes + forVotes + vetoVotes; // excluding abstain
        return participating >= quorum(proposalSnapshot(proposalId));
    }

    function _voteSucceeded(uint256 proposalId) internal view override returns (bool) {
        if (proposalVetoed(proposalId)) return false;
        (uint256 againstVotes, uint256 forVotes,,) = proposalVotes(proposalId);
        return forVotes > againstVotes;
    }

    // --- Required overrides ---

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }
}
