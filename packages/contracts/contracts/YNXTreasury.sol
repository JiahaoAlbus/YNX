// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YNXTreasury {
    address public immutable timelock;

    error OnlyTimelock();
    error CallFailed();

    constructor(address timelock_) {
        timelock = timelock_;
    }

    modifier onlyTimelock() {
        if (msg.sender != timelock) revert OnlyTimelock();
        _;
    }

    receive() external payable {}

    function transferERC20(IERC20 token, address to, uint256 amount) external onlyTimelock {
        token.transfer(to, amount);
    }

    function execute(address target, uint256 value, bytes calldata data) external onlyTimelock returns (bytes memory) {
        (bool ok, bytes memory ret) = target.call{ value: value }(data);
        if (!ok) revert CallFailed();
        return ret;
    }
}

