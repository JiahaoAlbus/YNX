// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { YNXOrgRegistry } from "./YNXOrgRegistry.sol";
import { IYNXArbitrable } from "./IYNXArbitrable.sol";

contract YNXArbitration {
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR");

    YNXOrgRegistry public immutable orgRegistry;

    struct Dispute {
        address arbitrable;
        uint256 courtOrgId;
        uint16 quorum;
        bool resolved;
        bool callbackExecuted;
        uint8 ruling;
        bytes data;
    }

    uint256 public disputeCount;
    mapping(uint256 disputeId => Dispute) public disputes;

    mapping(uint256 courtOrgId => uint16 quorum) public courtQuorum;

    mapping(uint256 disputeId => mapping(address arbitrator => bool)) public hasVoted;
    mapping(uint256 disputeId => mapping(uint8 ruling => uint256 votes)) public rulingVotes;

    event CourtQuorumUpdated(uint256 indexed courtOrgId, uint16 quorum);
    event DisputeOpened(uint256 indexed disputeId, address indexed arbitrable, uint256 indexed courtOrgId, uint16 quorum);
    event DisputeVoted(uint256 indexed disputeId, address indexed arbitrator, uint8 ruling);
    event DisputeResolved(uint256 indexed disputeId, uint8 ruling);
    event DisputeCallbackExecuted(uint256 indexed disputeId, bool success);

    error CourtNotFound();
    error OnlyOrgAdmin();
    error InvalidQuorum();

    error DisputeNotFound();
    error NotArbitrator();
    error AlreadyVoted();
    error AlreadyResolved();
    error NotResolved();
    error CallbackAlreadyExecuted();

    constructor(YNXOrgRegistry orgRegistry_) {
        orgRegistry = orgRegistry_;
    }

    function setCourtQuorum(uint256 courtOrgId, uint16 quorum) external {
        (address admin,) = orgRegistry.orgs(courtOrgId);
        if (admin == address(0)) revert CourtNotFound();
        if (msg.sender != admin) revert OnlyOrgAdmin();
        if (quorum == 0) revert InvalidQuorum();

        courtQuorum[courtOrgId] = quorum;
        emit CourtQuorumUpdated(courtOrgId, quorum);
    }

    function openDispute(address arbitrable, uint256 courtOrgId, bytes calldata data) external returns (uint256 disputeId) {
        (address admin,) = orgRegistry.orgs(courtOrgId);
        if (admin == address(0)) revert CourtNotFound();

        uint16 quorum = courtQuorum[courtOrgId];
        if (quorum == 0) revert InvalidQuorum();

        disputeId = ++disputeCount;
        disputes[disputeId] = Dispute({
            arbitrable: arbitrable,
            courtOrgId: courtOrgId,
            quorum: quorum,
            resolved: false,
            callbackExecuted: false,
            ruling: 0,
            data: data
        });

        emit DisputeOpened(disputeId, arbitrable, courtOrgId, quorum);
    }

    function vote(uint256 disputeId, uint8 ruling) external {
        Dispute storage dispute = disputes[disputeId];
        if (dispute.arbitrable == address(0)) revert DisputeNotFound();
        if (dispute.resolved) revert AlreadyResolved();

        if (!orgRegistry.hasRole(dispute.courtOrgId, ARBITRATOR_ROLE, msg.sender)) revert NotArbitrator();
        if (hasVoted[disputeId][msg.sender]) revert AlreadyVoted();

        hasVoted[disputeId][msg.sender] = true;
        uint256 votes = ++rulingVotes[disputeId][ruling];

        emit DisputeVoted(disputeId, msg.sender, ruling);

        if (votes >= dispute.quorum) {
            dispute.resolved = true;
            dispute.ruling = ruling;
            emit DisputeResolved(disputeId, ruling);
        }
    }

    function executeCallback(uint256 disputeId) external {
        Dispute storage dispute = disputes[disputeId];
        if (dispute.arbitrable == address(0)) revert DisputeNotFound();
        if (!dispute.resolved) revert NotResolved();
        if (dispute.callbackExecuted) revert CallbackAlreadyExecuted();

        dispute.callbackExecuted = true;

        bool ok;
        try IYNXArbitrable(dispute.arbitrable).onDisputeResolved(disputeId, dispute.ruling, dispute.data) {
            ok = true;
        } catch {
            ok = false;
        }

        emit DisputeCallbackExecuted(disputeId, ok);
    }
}

