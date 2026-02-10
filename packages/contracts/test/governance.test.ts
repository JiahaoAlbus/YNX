import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

function nyxt(amount: number): bigint {
  return ethers.parseUnits(String(amount), 18);
}

describe("YNX Governor (v0)", () => {
  it("enforces proposal threshold, deposit, timelock, and veto", async () => {
    const [deployer, alice, bob] = await ethers.getSigners();

    const NYXT = await ethers.getContractFactory("NYXT");
    // Use a small total supply for tests so quorum thresholds are reachable.
    const token = await NYXT.deploy(deployer.address, deployer.address, nyxt(10_000_000));

    // Distribute voting power
    await token.transfer(alice.address, nyxt(2_000_000));
    await token.transfer(bob.address, nyxt(2_000_000));
    await token.connect(alice).delegate(alice.address);
    await token.connect(bob).delegate(bob.address);

    // Timelock (7 days)
    const Timelock = await ethers.getContractFactory("YNXTimelock");
    const timelock = await Timelock.deploy(7n * 24n * 60n * 60n, [], [], deployer.address);

    const Treasury = await ethers.getContractFactory("YNXTreasury");
    const treasury = await Treasury.deploy(await timelock.getAddress());

    // Governor: votingDelay=1 block, votingPeriod=20 blocks (test speed), threshold=1,000,000, deposit=100,000
    const Governor = await ethers.getContractFactory("YNXGovernor");
    const governor = await Governor.deploy(
      await token.getAddress(),
      await token.getAddress(),
      await timelock.getAddress(),
      await treasury.getAddress(),
      1,
      20,
      nyxt(1_000_000),
      nyxt(100_000),
      10,
    );

    // Wire timelock roles: governor proposes, anyone executes.
    const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
    const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
    await timelock.grantRole(PROPOSER_ROLE, await governor.getAddress());
    await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress);

    // Fund treasury
    await deployer.sendTransaction({ to: await treasury.getAddress(), value: ethers.parseEther("1") });

    // Bob can't propose (below threshold) after moving most tokens away
    await token.connect(bob).transfer(deployer.address, nyxt(1_100_001));
    await token.connect(bob).delegate(bob.address);
    let bobProposeFailed = false;
    try {
      await governor.connect(bob).propose([await treasury.getAddress()], [0], ["0x"], "nope");
    } catch {
      bobProposeFailed = true;
    }
    expect(bobProposeFailed).to.equal(true);

    // Alice proposes a treasury spend: send 0.1 ETH to Alice.
    const callData = treasury.interface.encodeFunctionData("execute", [
      alice.address,
      ethers.parseEther("0.1"),
      "0x",
    ]);
    await token.connect(alice).approve(await governor.getAddress(), nyxt(100_000));
    const targets = [await treasury.getAddress()];
    const values = [0];
    const calldatas = [callData];
    const description = "pay alice";
    const descriptionHash = ethers.id(description);

    const proposalId = await governor.connect(alice).propose.staticCall(targets, values, calldatas, description);
    await governor.connect(alice).propose(targets, values, calldatas, description);

    // Deposit is locked in governor
    expect(await token.balanceOf(await governor.getAddress())).to.equal(nyxt(100_000));

    // Move to Active and vote
    for (let i = 0; i < 2; i++) {
      await ethers.provider.send("evm_mine", []);
    }
    await governor.connect(alice).castVote(proposalId, 1); // For
    await governor.connect(bob).castVote(proposalId, 0); // Against

    // Let it pass with Alice's votes by reducing Bob's weight (already reduced)
    for (let i = 0; i < 25; i++) {
      await ethers.provider.send("evm_mine", []);
    }
    expect(await governor.state(proposalId)).to.equal(4n); // Succeeded

    // Queue and ensure timelock delay
    await governor.queue(targets, values, calldatas, descriptionHash);
    let earlyExecuteFailed = false;
    try {
      await governor.execute(targets, values, calldatas, descriptionHash);
    } catch {
      earlyExecuteFailed = true;
    }
    expect(earlyExecuteFailed).to.equal(true);

    await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine", []);
    await governor.execute(targets, values, calldatas, descriptionHash);

    // Deposit can be finalized and returned (not vetoed)
    await governor.finalizeProposalDeposit(proposalId);
    expect(await token.balanceOf(alice.address)).to.be.greaterThan(0n);

    // Veto test: new proposal where veto reaches threshold
    await token.connect(alice).approve(await governor.getAddress(), nyxt(100_000));
    const proposalId2 = await governor
      .connect(alice)
      .propose.staticCall(targets, values, calldatas, "vetoed");
    await governor.connect(alice).propose(targets, values, calldatas, "vetoed");

    for (let i = 0; i < 2; i++) {
      await ethers.provider.send("evm_mine", []);
    }
    // Bob casts veto vote type=3
    await governor.connect(bob).castVote(proposalId2, 3);
    for (let i = 0; i < 25; i++) {
      await ethers.provider.send("evm_mine", []);
    }

    // Deposit slashed to treasury on finalize if vetoed
    await governor.finalizeProposalDeposit(proposalId2);
    expect(await token.balanceOf(await treasury.getAddress())).to.equal(nyxt(100_000));
  });
});
