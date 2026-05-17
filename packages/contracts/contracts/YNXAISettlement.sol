// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract YNXAISettlement {
    enum JobStatus {
        None,
        Created,
        Committed,
        Challenged,
        Finalized,
        Slashed,
        Cancelled
    }

    struct Vault {
        address owner;
        uint256 balance;
        uint256 maxPerPayment;
        bool active;
        bytes32 policyHash;
    }

    struct Job {
        bytes32 vaultId;
        address creator;
        address worker;
        uint256 reward;
        uint256 stake;
        uint64 challengeDeadline;
        bytes32 inputHash;
        bytes32 resultHash;
        string attestationURI;
        JobStatus status;
        bytes32 policyHash;
    }

    mapping(bytes32 => Vault) public vaults;
    mapping(bytes32 => Job) public jobs;

    event VaultCreated(bytes32 indexed vaultId, address indexed owner, bytes32 indexed policyHash);
    event VaultDeposited(bytes32 indexed vaultId, address indexed from, uint256 amount);
    event VaultWithdrawn(bytes32 indexed vaultId, address indexed to, uint256 amount);
    event JobCreated(bytes32 indexed jobId, bytes32 indexed vaultId, address indexed creator, uint256 reward);
    event JobCommitted(bytes32 indexed jobId, address indexed worker, bytes32 resultHash);
    event JobChallenged(bytes32 indexed jobId, address indexed challenger);
    event JobFinalized(bytes32 indexed jobId, address indexed worker, uint256 reward);
    event JobSlashed(bytes32 indexed jobId, address indexed worker);
    event JobCancelled(bytes32 indexed jobId);

    error VaultExists();
    error VaultNotFound();
    error VaultInactive();
    error NotVaultOwner();
    error JobExists();
    error JobNotFound();
    error InvalidStatus();
    error InvalidAmount();
    error InvalidWorker();
    error PolicyMismatch();
    error ChallengeWindowOpen();
    error TransferFailed();

    modifier onlyVaultOwner(bytes32 vaultId) {
        Vault storage vault = vaults[vaultId];
        if (vault.owner == address(0)) revert VaultNotFound();
        if (vault.owner != msg.sender) revert NotVaultOwner();
        _;
    }

    function createVault(bytes32 vaultId, bytes32 policyHash, uint256 maxPerPayment) external payable {
        if (vaultId == bytes32(0)) revert VaultNotFound();
        if (vaults[vaultId].owner != address(0)) revert VaultExists();
        vaults[vaultId] = Vault({
            owner: msg.sender,
            balance: msg.value,
            maxPerPayment: maxPerPayment,
            active: true,
            policyHash: policyHash
        });
        emit VaultCreated(vaultId, msg.sender, policyHash);
        if (msg.value > 0) emit VaultDeposited(vaultId, msg.sender, msg.value);
    }

    function deposit(bytes32 vaultId) external payable {
        Vault storage vault = vaults[vaultId];
        if (vault.owner == address(0)) revert VaultNotFound();
        if (!vault.active) revert VaultInactive();
        if (msg.value == 0) revert InvalidAmount();
        vault.balance += msg.value;
        emit VaultDeposited(vaultId, msg.sender, msg.value);
    }

    function withdraw(bytes32 vaultId, uint256 amount, address payable to) external onlyVaultOwner(vaultId) {
        if (amount == 0) revert InvalidAmount();
        Vault storage vault = vaults[vaultId];
        if (vault.balance < amount) revert InvalidAmount();
        vault.balance -= amount;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit VaultWithdrawn(vaultId, to, amount);
    }

    function setVaultActive(bytes32 vaultId, bool active) external onlyVaultOwner(vaultId) {
        vaults[vaultId].active = active;
    }

    function createJob(
        bytes32 jobId,
        bytes32 vaultId,
        uint256 reward,
        uint256 stake,
        bytes32 inputHash,
        bytes32 policyHash,
        uint64 challengeBlocks
    ) external {
        if (jobs[jobId].status != JobStatus.None) revert JobExists();
        Vault storage vault = vaults[vaultId];
        if (vault.owner == address(0)) revert VaultNotFound();
        if (!vault.active) revert VaultInactive();
        if (vault.owner != msg.sender) revert NotVaultOwner();
        if (vault.policyHash != policyHash) revert PolicyMismatch();
        if (reward == 0 || vault.balance < reward) revert InvalidAmount();
        if (vault.maxPerPayment > 0 && reward > vault.maxPerPayment) revert InvalidAmount();

        jobs[jobId] = Job({
            vaultId: vaultId,
            creator: msg.sender,
            worker: address(0),
            reward: reward,
            stake: stake,
            challengeDeadline: uint64(block.number) + challengeBlocks,
            inputHash: inputHash,
            resultHash: bytes32(0),
            attestationURI: "",
            status: JobStatus.Created,
            policyHash: policyHash
        });
        emit JobCreated(jobId, vaultId, msg.sender, reward);
    }

    function commitResult(bytes32 jobId, bytes32 resultHash, string calldata attestationURI) external {
        Job storage job = jobs[jobId];
        if (job.status == JobStatus.None) revert JobNotFound();
        if (job.status != JobStatus.Created) revert InvalidStatus();
        if (resultHash == bytes32(0)) revert InvalidAmount();
        job.worker = msg.sender;
        job.resultHash = resultHash;
        job.attestationURI = attestationURI;
        job.status = JobStatus.Committed;
        emit JobCommitted(jobId, msg.sender, resultHash);
    }

    function challenge(bytes32 jobId) external {
        Job storage job = jobs[jobId];
        if (job.status == JobStatus.None) revert JobNotFound();
        if (job.status != JobStatus.Committed) revert InvalidStatus();
        job.status = JobStatus.Challenged;
        emit JobChallenged(jobId, msg.sender);
    }

    function finalize(bytes32 jobId) external {
        Job storage job = jobs[jobId];
        if (job.status == JobStatus.None) revert JobNotFound();
        if (job.status != JobStatus.Committed) revert InvalidStatus();
        if (block.number <= job.challengeDeadline) revert ChallengeWindowOpen();
        Vault storage vault = vaults[job.vaultId];
        if (msg.sender != vault.owner) revert NotVaultOwner();
        if (job.worker == address(0)) revert InvalidWorker();
        if (vault.balance < job.reward) revert InvalidAmount();

        job.status = JobStatus.Finalized;
        vault.balance -= job.reward;
        (bool ok, ) = payable(job.worker).call{value: job.reward}("");
        if (!ok) revert TransferFailed();
        emit JobFinalized(jobId, job.worker, job.reward);
    }

    function slash(bytes32 jobId) external {
        Job storage job = jobs[jobId];
        if (job.status == JobStatus.None) revert JobNotFound();
        if (job.status != JobStatus.Committed && job.status != JobStatus.Challenged) revert InvalidStatus();
        Vault storage vault = vaults[job.vaultId];
        if (msg.sender != vault.owner) revert NotVaultOwner();
        job.status = JobStatus.Slashed;
        emit JobSlashed(jobId, job.worker);
    }

    function cancel(bytes32 jobId) external {
        Job storage job = jobs[jobId];
        if (job.status == JobStatus.None) revert JobNotFound();
        if (job.status != JobStatus.Created) revert InvalidStatus();
        Vault storage vault = vaults[job.vaultId];
        if (msg.sender != vault.owner) revert NotVaultOwner();
        job.status = JobStatus.Cancelled;
        emit JobCancelled(jobId);
    }
}
