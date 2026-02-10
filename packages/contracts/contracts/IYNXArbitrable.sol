// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IYNXArbitrable {
    function onDisputeResolved(uint256 disputeId, uint256 ruling, bytes calldata data) external;
}

