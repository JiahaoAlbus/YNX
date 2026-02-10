// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IYNXArbitrable } from "./IYNXArbitrable.sol";

contract MockArbitrable is IYNXArbitrable {
    uint256 public lastDisputeId;
    uint256 public lastRuling;
    bytes public lastData;

    function onDisputeResolved(uint256 disputeId, uint256 ruling, bytes calldata data) external override {
        lastDisputeId = disputeId;
        lastRuling = ruling;
        lastData = data;
    }
}

