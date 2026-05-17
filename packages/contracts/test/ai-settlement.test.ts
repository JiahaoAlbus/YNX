import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

function id(value: string) {
  return ethers.id(value);
}

async function expectRevert(promise: Promise<unknown>, errorName: string) {
  try {
    await promise;
  } catch (error) {
    expect(String(error)).to.include(errorName);
    return;
  }
  expect.fail(`Expected revert ${errorName}`);
}

describe("YNXAISettlement", function () {
  it("settles an AI job reward from a policy-bound vault", async function () {
    const [owner, worker] = await ethers.getSigners();
    const Settlement = await ethers.getContractFactory("YNXAISettlement");
    const settlement = await Settlement.deploy();
    await settlement.waitForDeployment();

    const vaultId = id("vault/main");
    const policyHash = id("owner > policy > session > ai.job");
    const reward = ethers.parseEther("4");

    await settlement
      .connect(owner)
      .createVault(vaultId, policyHash, ethers.parseEther("5"), { value: ethers.parseEther("10") });

    const jobId = id("job/market-summary/1");
    await settlement
      .connect(owner)
      .createJob(jobId, vaultId, reward, 0, id("input/ipfs-cid"), policyHash, 0);

    await settlement.connect(worker).commitResult(jobId, id("result/hash"), "ipfs://attestation");

    const before = await ethers.provider.getBalance(worker.address);
    const tx = await settlement.connect(owner).finalize(jobId);
    await tx.wait();
    const after = await ethers.provider.getBalance(worker.address);

    const job = await settlement.jobs(jobId);
    const vault = await settlement.vaults(vaultId);
    expect(job.status).to.equal(4n);
    expect(job.worker).to.equal(worker.address);
    expect(vault.balance).to.equal(ethers.parseEther("6"));
    expect(after - before).to.equal(reward);
  });

  it("enforces policy hash and max per payment", async function () {
    const [owner] = await ethers.getSigners();
    const Settlement = await ethers.getContractFactory("YNXAISettlement");
    const settlement = await Settlement.deploy();
    await settlement.waitForDeployment();

    const vaultId = id("vault/limits");
    const policyHash = id("policy/a");
    await settlement
      .connect(owner)
      .createVault(vaultId, policyHash, ethers.parseEther("1"), { value: ethers.parseEther("10") });

    await expectRevert(
      settlement
        .connect(owner)
        .createJob(id("job/wrong-policy"), vaultId, ethers.parseEther("1"), 0, id("input"), id("policy/b"), 0),
      "PolicyMismatch",
    );

    await expectRevert(
      settlement
        .connect(owner)
        .createJob(id("job/too-large"), vaultId, ethers.parseEther("2"), 0, id("input"), policyHash, 0),
      "InvalidAmount",
    );
  });

  it("allows owner to slash a bad committed result instead of paying it", async function () {
    const [owner, worker] = await ethers.getSigners();
    const Settlement = await ethers.getContractFactory("YNXAISettlement");
    const settlement = await Settlement.deploy();
    await settlement.waitForDeployment();

    const vaultId = id("vault/slash");
    const policyHash = id("policy/slash");
    await settlement
      .connect(owner)
      .createVault(vaultId, policyHash, 0, { value: ethers.parseEther("3") });

    const jobId = id("job/slash");
    await settlement.connect(owner).createJob(jobId, vaultId, ethers.parseEther("1"), 0, id("input"), policyHash, 10);
    await settlement.connect(worker).commitResult(jobId, id("bad-result"), "ipfs://bad-attestation");
    await settlement.connect(owner).slash(jobId);

    const job = await settlement.jobs(jobId);
    const vault = await settlement.vaults(vaultId);
    expect(job.status).to.equal(5n);
    expect(vault.balance).to.equal(ethers.parseEther("3"));
  });
});
