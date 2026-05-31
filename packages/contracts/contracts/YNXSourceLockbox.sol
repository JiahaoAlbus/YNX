// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract YNXSourceLockbox is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Route {
        bool enabled;
        bool nativeAsset;
        address token;
        uint256 minAmount;
    }

    event RouteUpdated(bytes32 indexed sourceAssetId, bool enabled, bool nativeAsset, address indexed token, uint256 minAmount);
    event DepositLocked(
        bytes32 indexed depositId,
        address indexed depositor,
        address indexed recipient,
        bytes32 sourceAssetId,
        address asset,
        uint256 amount,
        uint64 sourceChainId,
        uint256 nonce
    );
    event ReleaseExecuted(
        bytes32 indexed releaseId,
        address indexed recipient,
        bytes32 indexed sourceAssetId,
        address asset,
        uint256 amount
    );

    error RouteDisabled(bytes32 sourceAssetId);
    error WrongAssetMode(bytes32 sourceAssetId);
    error AmountTooSmall(uint256 amount, uint256 minAmount);
    error ZeroAmount();
    error ZeroRecipient();
    error ReleaseAlreadyProcessed(bytes32 releaseId);
    error NativeReleaseFailed();

    uint64 public immutable sourceChainId;
    uint256 public depositNonce;
    mapping(bytes32 => Route) public routes;
    mapping(bytes32 => bool) public processedReleases;

    constructor(address owner_, uint64 sourceChainId_) Ownable(owner_) {
        sourceChainId = sourceChainId_;
    }

    receive() external payable {}

    function setRoute(bytes32 sourceAssetId, bool enabled, bool nativeAsset, address token, uint256 minAmount) external onlyOwner {
        if (!nativeAsset && token == address(0)) revert ZeroRecipient();
        routes[sourceAssetId] = Route({
            enabled: enabled,
            nativeAsset: nativeAsset,
            token: token,
            minAmount: minAmount
        });
        emit RouteUpdated(sourceAssetId, enabled, nativeAsset, token, minAmount);
    }

    function depositNative(bytes32 sourceAssetId, address recipient) external payable nonReentrant returns (bytes32 depositId) {
        Route memory route = routes[sourceAssetId];
        if (!route.enabled) revert RouteDisabled(sourceAssetId);
        if (!route.nativeAsset) revert WrongAssetMode(sourceAssetId);
        if (recipient == address(0)) revert ZeroRecipient();
        if (msg.value == 0) revert ZeroAmount();
        if (msg.value < route.minAmount) revert AmountTooSmall(msg.value, route.minAmount);

        depositId = _nextDepositId(sourceAssetId, msg.sender, recipient, msg.value);
        emit DepositLocked(depositId, msg.sender, recipient, sourceAssetId, address(0), msg.value, sourceChainId, depositNonce);
    }

    function depositERC20(bytes32 sourceAssetId, uint256 amount, address recipient) external nonReentrant returns (bytes32 depositId) {
        Route memory route = routes[sourceAssetId];
        if (!route.enabled) revert RouteDisabled(sourceAssetId);
        if (route.nativeAsset) revert WrongAssetMode(sourceAssetId);
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        if (amount < route.minAmount) revert AmountTooSmall(amount, route.minAmount);

        IERC20(route.token).safeTransferFrom(msg.sender, address(this), amount);
        depositId = _nextDepositId(sourceAssetId, msg.sender, recipient, amount);
        emit DepositLocked(depositId, msg.sender, recipient, sourceAssetId, route.token, amount, sourceChainId, depositNonce);
    }

    function releaseNative(bytes32 releaseId, address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        _markRelease(releaseId, recipient, amount);
        (bool ok, ) = recipient.call{value: amount}("");
        if (!ok) revert NativeReleaseFailed();
        emit ReleaseExecuted(releaseId, recipient, bytes32(0), address(0), amount);
    }

    function releaseERC20(bytes32 releaseId, bytes32 sourceAssetId, address recipient, uint256 amount) external onlyOwner nonReentrant {
        Route memory route = routes[sourceAssetId];
        if (!route.enabled || route.nativeAsset) revert WrongAssetMode(sourceAssetId);
        _markRelease(releaseId, recipient, amount);
        IERC20(route.token).safeTransfer(recipient, amount);
        emit ReleaseExecuted(releaseId, recipient, sourceAssetId, route.token, amount);
    }

    function _nextDepositId(bytes32 sourceAssetId, address depositor, address recipient, uint256 amount) internal returns (bytes32) {
        depositNonce += 1;
        return keccak256(abi.encode(block.chainid, address(this), depositNonce, sourceAssetId, depositor, recipient, amount));
    }

    function _markRelease(bytes32 releaseId, address recipient, uint256 amount) internal {
        if (processedReleases[releaseId]) revert ReleaseAlreadyProcessed(releaseId);
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        processedReleases[releaseId] = true;
    }
}
