// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IYNXProtocol
/// @notice Interface for the YNX protocol precompile at:
///         0x0000000000000000000000000000000000000810
interface IYNXProtocol {
    function getParams()
        external
        view
        returns (
            address founder,
            address treasury,
            uint32 feeBurnBps,
            uint32 feeTreasuryBps,
            uint32 feeFounderBps,
            uint32 inflationTreasuryBps
        );

    function getSystemContracts()
        external
        view
        returns (
            address nyxt,
            address timelock,
            address treasury,
            address governor,
            address teamVesting,
            address orgRegistry,
            address subjectRegistry,
            address arbitration,
            address domainInbox
        );

    function updateParams(
        address founder,
        address treasury,
        uint32 feeBurnBps,
        uint32 feeTreasuryBps,
        uint32 feeFounderBps,
        uint32 inflationTreasuryBps
    ) external returns (bool ok);
}

