// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

interface IERC20Burnable is IERC20 {
    function burn(uint256 amount) external;
}

interface IBridgeMintable {
    function mint(address to, uint256 amount) external;
}

contract YNXBridgeGateway is Ownable2Step, Pausable, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using SafeERC20 for IERC20;

    bytes32 private constant MINT_TYPEHASH =
        keccak256(
            "YNXBridgeMint(uint256 chainId,address gateway,uint64 signerEpoch,bytes32 depositId,address token,address recipient,uint256 amount,uint64 sourceChainId)"
        );
    bytes32 private constant MINT_WITH_ASSET_TYPEHASH =
        keccak256(
            "YNXBridgeMintWithAsset(uint256 chainId,address gateway,uint64 signerEpoch,bytes32 depositId,uint64 sourceChainId,bytes32 sourceAssetId,address token,address recipient,uint256 amount)"
        );

    error EmptySignerSet();
    error InvalidThreshold();
    error DuplicateSigner(address signer);
    error ZeroSigner();
    error UnsupportedWrappedToken(address token);
    error DepositAlreadyProcessed(bytes32 depositId);
    error ZeroRecipient();
    error ZeroAmount();
    error NotEnoughSignatures(uint256 valid, uint256 required);
    error PendingSignerSetMissing();
    error PendingSignerSetNotReady(uint64 applyAfter);
    error SupportedTokenRescueBlocked(address token);
    error UnsupportedRemoteAsset(uint64 sourceChainId, bytes32 sourceAssetId);
    error BridgeRouteMissing(address token, uint64 remoteChainId);
    error InvalidRemoteChainId();
    error InvalidRemoteAssetId();

    event WrappedTokenSupportUpdated(address indexed token, bool supported);
    event BridgeRouteUpdated(
        uint64 indexed remoteChainId,
        bytes32 indexed remoteAssetId,
        address indexed wrappedToken
    );
    event DepositMinted(
        bytes32 indexed depositId,
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint64 sourceChainId,
        uint64 signerEpoch,
        address relayer
    );
    event BurnRequested(
        uint256 indexed nonce,
        address indexed token,
        address indexed from,
        uint256 amount,
        uint64 destinationChainId,
        bytes32 destinationRecipient
    );
    event BurnRequestedMapped(
        uint256 indexed nonce,
        address indexed token,
        address indexed from,
        uint256 amount,
        uint64 destinationChainId,
        bytes32 destinationAssetId,
        bytes32 destinationRecipient
    );
    event SignerSetProposed(
        uint64 indexed nextEpoch,
        uint64 applyAfter,
        address[] signers,
        uint256 threshold
    );
    event SignerSetApplied(
        uint64 indexed epoch,
        address[] signers,
        uint256 threshold
    );
    event SignerSetProposalCanceled(uint64 indexed epoch);

    mapping(address => bool) public isSigner;
    address[] private _signers;
    uint256 public signerThreshold;
    uint64 public signerEpoch;
    uint64 public signerSetDelaySeconds;

    mapping(bytes32 => bool) public processedDeposits;
    mapping(address => bool) public supportedWrappedTokens;
    mapping(uint64 => mapping(bytes32 => address)) public wrappedTokenByRemoteAsset;
    mapping(address => mapping(uint64 => bytes32)) public remoteAssetIdByWrappedToken;

    address[] private _pendingSigners;
    uint256 public pendingThreshold;
    uint64 public pendingApplyAfter;
    bool public pendingSignerSetExists;

    uint256 public outboundNonce;

    constructor(
        address owner_,
        address[] memory initialSigners,
        uint256 initialThreshold,
        uint64 signerSetDelaySeconds_
    ) Ownable(owner_) {
        signerSetDelaySeconds = signerSetDelaySeconds_;
        _applySignerSet(initialSigners, initialThreshold);
        signerEpoch = 1;
    }

    function signers() external view returns (address[] memory) {
        return _signers;
    }

    function setSupportedWrappedToken(address token, bool supported) external onlyOwner {
        if (token == address(0)) revert ZeroRecipient();
        supportedWrappedTokens[token] = supported;
        emit WrappedTokenSupportUpdated(token, supported);
    }

    function setSignerSetDelaySeconds(uint64 delaySeconds) external onlyOwner {
        signerSetDelaySeconds = delaySeconds;
    }

    function setBridgeRoute(
        uint64 remoteChainId,
        bytes32 remoteAssetId,
        address wrappedToken
    ) external onlyOwner {
        if (remoteChainId == 0) revert InvalidRemoteChainId();
        if (remoteAssetId == bytes32(0)) revert InvalidRemoteAssetId();
        if (wrappedToken == address(0)) revert ZeroRecipient();
        if (!supportedWrappedTokens[wrappedToken]) revert UnsupportedWrappedToken(wrappedToken);
        address previous = wrappedTokenByRemoteAsset[remoteChainId][remoteAssetId];
        if (previous != address(0) && previous != wrappedToken) {
            delete remoteAssetIdByWrappedToken[previous][remoteChainId];
        }
        wrappedTokenByRemoteAsset[remoteChainId][remoteAssetId] = wrappedToken;
        remoteAssetIdByWrappedToken[wrappedToken][remoteChainId] = remoteAssetId;
        emit BridgeRouteUpdated(remoteChainId, remoteAssetId, wrappedToken);
    }

    function proposeSignerSet(address[] calldata nextSigners, uint256 nextThreshold) external onlyOwner {
        _validateSignerSet(nextSigners, nextThreshold);
        delete _pendingSigners;
        for (uint256 i = 0; i < nextSigners.length; i++) {
            _pendingSigners.push(nextSigners[i]);
        }
        pendingThreshold = nextThreshold;
        pendingApplyAfter = uint64(block.timestamp) + signerSetDelaySeconds;
        pendingSignerSetExists = true;
        emit SignerSetProposed(signerEpoch + 1, pendingApplyAfter, nextSigners, nextThreshold);
    }

    function applyProposedSignerSet() external onlyOwner {
        if (!pendingSignerSetExists) revert PendingSignerSetMissing();
        if (block.timestamp < pendingApplyAfter) revert PendingSignerSetNotReady(pendingApplyAfter);

        address[] memory nextSigners = _pendingSigners;
        uint256 nextThreshold = pendingThreshold;

        _applySignerSet(nextSigners, nextThreshold);
        signerEpoch += 1;

        delete _pendingSigners;
        pendingThreshold = 0;
        pendingApplyAfter = 0;
        pendingSignerSetExists = false;

        emit SignerSetApplied(signerEpoch, nextSigners, nextThreshold);
    }

    function cancelProposedSignerSet() external onlyOwner {
        if (!pendingSignerSetExists) revert PendingSignerSetMissing();
        delete _pendingSigners;
        pendingThreshold = 0;
        pendingApplyAfter = 0;
        pendingSignerSetExists = false;
        emit SignerSetProposalCanceled(signerEpoch + 1);
    }

    function mintAttestationPayload(
        bytes32 depositId,
        address token,
        address recipient,
        uint256 amount,
        uint64 sourceChainId
    ) public view returns (bytes32) {
        return _mintPayload(depositId, token, recipient, amount, sourceChainId);
    }

    function mintAttestationPayloadWithAsset(
        bytes32 depositId,
        uint64 sourceChainId,
        bytes32 sourceAssetId,
        address token,
        address recipient,
        uint256 amount
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MINT_WITH_ASSET_TYPEHASH,
                    block.chainid,
                    address(this),
                    signerEpoch,
                    depositId,
                    sourceChainId,
                    sourceAssetId,
                    token,
                    recipient,
                    amount
                )
            );
    }

    function mintWithAttestation(
        bytes32 depositId,
        address token,
        address recipient,
        uint256 amount,
        uint64 sourceChainId,
        bytes[] calldata signatures
    ) external whenNotPaused nonReentrant {
        if (!supportedWrappedTokens[token]) revert UnsupportedWrappedToken(token);
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        if (processedDeposits[depositId]) revert DepositAlreadyProcessed(depositId);

        bytes32 payload = _mintPayload(depositId, token, recipient, amount, sourceChainId);
        _requireThresholdSignatures(payload, signatures);

        processedDeposits[depositId] = true;
        IBridgeMintable(token).mint(recipient, amount);

        emit DepositMinted(
            depositId,
            token,
            recipient,
            amount,
            sourceChainId,
            signerEpoch,
            msg.sender
        );
    }

    function mintWithMappedAttestation(
        bytes32 depositId,
        uint64 sourceChainId,
        bytes32 sourceAssetId,
        address recipient,
        uint256 amount,
        bytes[] calldata signatures
    ) external whenNotPaused nonReentrant {
        address token = wrappedTokenByRemoteAsset[sourceChainId][sourceAssetId];
        if (token == address(0)) revert UnsupportedRemoteAsset(sourceChainId, sourceAssetId);
        if (recipient == address(0)) revert ZeroRecipient();
        if (amount == 0) revert ZeroAmount();
        if (processedDeposits[depositId]) revert DepositAlreadyProcessed(depositId);

        bytes32 payload = mintAttestationPayloadWithAsset(
            depositId,
            sourceChainId,
            sourceAssetId,
            token,
            recipient,
            amount
        );
        _requireThresholdSignatures(payload, signatures);

        processedDeposits[depositId] = true;
        IBridgeMintable(token).mint(recipient, amount);

        emit DepositMinted(
            depositId,
            token,
            recipient,
            amount,
            sourceChainId,
            signerEpoch,
            msg.sender
        );
    }

    function burnForBridge(
        address token,
        uint256 amount,
        uint64 destinationChainId,
        bytes32 destinationRecipient
    ) external whenNotPaused nonReentrant {
        if (!supportedWrappedTokens[token]) revert UnsupportedWrappedToken(token);
        if (amount == 0) revert ZeroAmount();
        if (destinationRecipient == bytes32(0)) revert ZeroRecipient();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20Burnable(token).burn(amount);

        outboundNonce += 1;
        emit BurnRequested(
            outboundNonce,
            token,
            msg.sender,
            amount,
            destinationChainId,
            destinationRecipient
        );
    }

    function burnForBridgeMapped(
        address token,
        uint256 amount,
        uint64 destinationChainId,
        bytes32 destinationRecipient
    ) external whenNotPaused nonReentrant {
        if (!supportedWrappedTokens[token]) revert UnsupportedWrappedToken(token);
        if (amount == 0) revert ZeroAmount();
        if (destinationRecipient == bytes32(0)) revert ZeroRecipient();

        bytes32 destinationAssetId = remoteAssetIdByWrappedToken[token][destinationChainId];
        if (destinationAssetId == bytes32(0)) revert BridgeRouteMissing(token, destinationChainId);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20Burnable(token).burn(amount);

        outboundNonce += 1;
        emit BurnRequestedMapped(
            outboundNonce,
            token,
            msg.sender,
            amount,
            destinationChainId,
            destinationAssetId,
            destinationRecipient
        );
    }

    function rescueUnsupportedToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner {
        if (supportedWrappedTokens[token]) revert SupportedTokenRescueBlocked(token);
        IERC20(token).safeTransfer(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _requireThresholdSignatures(
        bytes32 payload,
        bytes[] calldata signatures
    ) internal view {
        bytes32 digest = payload.toEthSignedMessageHash();
        uint256 valid;
        address[] memory seen = new address[](signatures.length);

        for (uint256 i = 0; i < signatures.length; i++) {
            address recovered = digest.recover(signatures[i]);
            if (!isSigner[recovered]) {
                continue;
            }
            bool duplicate;
            for (uint256 j = 0; j < valid; j++) {
                if (seen[j] == recovered) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) {
                continue;
            }
            seen[valid] = recovered;
            valid += 1;
        }

        if (valid < signerThreshold) {
            revert NotEnoughSignatures(valid, signerThreshold);
        }
    }

    function _validateSignerSet(address[] memory nextSigners, uint256 nextThreshold) internal pure {
        uint256 signerCount = nextSigners.length;
        if (signerCount == 0) revert EmptySignerSet();
        if (nextThreshold == 0 || nextThreshold > signerCount) revert InvalidThreshold();

        for (uint256 i = 0; i < signerCount; i++) {
            address signer = nextSigners[i];
            if (signer == address(0)) revert ZeroSigner();
            for (uint256 j = i + 1; j < signerCount; j++) {
                if (signer == nextSigners[j]) revert DuplicateSigner(signer);
            }
        }
    }

    function _applySignerSet(address[] memory nextSigners, uint256 nextThreshold) internal {
        _validateSignerSet(nextSigners, nextThreshold);

        for (uint256 i = 0; i < _signers.length; i++) {
            isSigner[_signers[i]] = false;
        }
        delete _signers;

        for (uint256 i = 0; i < nextSigners.length; i++) {
            address signer = nextSigners[i];
            isSigner[signer] = true;
            _signers.push(signer);
        }

        signerThreshold = nextThreshold;
    }

    function _mintPayload(
        bytes32 depositId,
        address token,
        address recipient,
        uint256 amount,
        uint64 sourceChainId
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MINT_TYPEHASH,
                    block.chainid,
                    address(this),
                    signerEpoch,
                    depositId,
                    token,
                    recipient,
                    amount,
                    sourceChainId
                )
            );
    }
}
