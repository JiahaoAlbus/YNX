// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title YNXDomainInbox
/// @notice Minimal base-layer inbox for execution-domain / rollup commitments.
///         A domain has an owner who can authorize one or more submitters
///         (sequencers/aggregators) to post commitments.
contract YNXDomainInbox {
    struct Commitment {
        bytes32 stateRoot;
        bytes32 dataHash;
        address submitter;
        uint64 timestamp;
        bool exists;
    }

    mapping(bytes32 => address) public domainOwner;
    mapping(bytes32 => string) public domainMetadata;
    mapping(bytes32 => mapping(address => bool)) public domainSubmitter;
    mapping(bytes32 => mapping(uint64 => Commitment)) public commitments;

    event DomainRegistered(bytes32 indexed domainId, address indexed owner, string metadata);
    event DomainOwnerUpdated(bytes32 indexed domainId, address indexed newOwner);
    event DomainMetadataUpdated(bytes32 indexed domainId, string metadata);
    event DomainSubmitterUpdated(bytes32 indexed domainId, address indexed submitter, bool enabled);
    event CommitmentSubmitted(
        bytes32 indexed domainId,
        uint64 indexed batch,
        bytes32 stateRoot,
        bytes32 dataHash,
        address indexed submitter
    );

    error DomainAlreadyExists();
    error DomainNotFound();
    error NotDomainOwner();
    error NotAuthorizedSubmitter();
    error CommitmentAlreadyExists();

    function registerDomain(bytes32 domainId, string calldata metadata) external {
        if (domainId == bytes32(0)) revert DomainNotFound();
        if (domainOwner[domainId] != address(0)) revert DomainAlreadyExists();

        domainOwner[domainId] = msg.sender;
        domainMetadata[domainId] = metadata;
        domainSubmitter[domainId][msg.sender] = true;

        emit DomainRegistered(domainId, msg.sender, metadata);
        emit DomainSubmitterUpdated(domainId, msg.sender, true);
    }

    function setDomainOwner(bytes32 domainId, address newOwner) external {
        if (domainOwner[domainId] == address(0)) revert DomainNotFound();
        if (msg.sender != domainOwner[domainId]) revert NotDomainOwner();
        if (newOwner == address(0)) revert DomainNotFound();

        domainOwner[domainId] = newOwner;
        domainSubmitter[domainId][newOwner] = true;

        emit DomainOwnerUpdated(domainId, newOwner);
        emit DomainSubmitterUpdated(domainId, newOwner, true);
    }

    function setDomainMetadata(bytes32 domainId, string calldata metadata) external {
        if (domainOwner[domainId] == address(0)) revert DomainNotFound();
        if (msg.sender != domainOwner[domainId]) revert NotDomainOwner();

        domainMetadata[domainId] = metadata;
        emit DomainMetadataUpdated(domainId, metadata);
    }

    function setDomainSubmitter(bytes32 domainId, address submitter, bool enabled) external {
        if (domainOwner[domainId] == address(0)) revert DomainNotFound();
        if (msg.sender != domainOwner[domainId]) revert NotDomainOwner();
        if (submitter == address(0)) revert DomainNotFound();

        domainSubmitter[domainId][submitter] = enabled;
        emit DomainSubmitterUpdated(domainId, submitter, enabled);
    }

    function submitCommitment(bytes32 domainId, uint64 batch, bytes32 stateRoot, bytes32 dataHash) external {
        if (domainOwner[domainId] == address(0)) revert DomainNotFound();
        if (!domainSubmitter[domainId][msg.sender]) revert NotAuthorizedSubmitter();

        Commitment storage c = commitments[domainId][batch];
        if (c.exists) revert CommitmentAlreadyExists();

        commitments[domainId][batch] = Commitment({
            stateRoot: stateRoot,
            dataHash: dataHash,
            submitter: msg.sender,
            timestamp: uint64(block.timestamp),
            exists: true
        });

        emit CommitmentSubmitted(domainId, batch, stateRoot, dataHash, msg.sender);
    }
}

