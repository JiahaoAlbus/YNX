import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("YNXSourceLockbox", function () {
  it("locks native deposits with deterministic event fields", async function () {
    const [owner, depositor, recipient] = await ethers.getSigners();
    const assetId = ethers.id("eip155:11155111:native:ETH");
    const Lockbox = await ethers.getContractFactory("YNXSourceLockbox", owner);
    const lockbox = await Lockbox.deploy(owner.address, 11155111);

    await lockbox.setRoute(assetId, true, true, ethers.ZeroAddress, 1n);

    const tx = await lockbox.connect(depositor).depositNative(assetId, recipient.address, { value: 123n });
    const receipt = await tx.wait();
    const event = receipt?.logs
      .map((log) => {
        try {
          return lockbox.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((log) => log?.name === "DepositLocked");

    expect(event?.args.depositor).to.equal(depositor.address);
    expect(event?.args.recipient).to.equal(recipient.address);
    expect(event?.args.sourceAssetId).to.equal(assetId);
    expect(event?.args.asset).to.equal(ethers.ZeroAddress);
    expect(event?.args.amount).to.equal(123n);
    expect(event?.args.sourceChainId).to.equal(11155111n);
  });

  it("locks ERC20 deposits and supports one-time release", async function () {
    const [owner, depositor, recipient] = await ethers.getSigners();
    const assetId = ethers.id("eip155:11155111:erc20:0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238");
    const Token = await ethers.getContractFactory("YNXBridgeWrappedToken", owner);
    const token = await Token.deploy("Mock USDC", "USDC", 6, owner.address, owner.address);
    const Lockbox = await ethers.getContractFactory("YNXSourceLockbox", owner);
    const lockbox = await Lockbox.deploy(owner.address, 11155111);

    await token.mint(depositor.address, 1_000_000n);
    await lockbox.setRoute(assetId, true, false, await token.getAddress(), 100n);
    await token.connect(depositor).approve(await lockbox.getAddress(), 250_000n);

    const tx = await lockbox.connect(depositor).depositERC20(assetId, 250_000n, recipient.address);
    const receipt = await tx.wait();
    const event = receipt?.logs
      .map((log) => {
        try {
          return lockbox.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((log) => log?.name === "DepositLocked");

    expect(event?.args.depositor).to.equal(depositor.address);
    expect(event?.args.recipient).to.equal(recipient.address);
    expect(event?.args.sourceAssetId).to.equal(assetId);
    expect(event?.args.asset).to.equal(await token.getAddress());
    expect(event?.args.amount).to.equal(250_000n);
    expect(event?.args.sourceChainId).to.equal(11155111n);

    const releaseId = ethers.id("release-1");
    const releaseTx = await lockbox.releaseERC20(releaseId, assetId, recipient.address, 50_000n);
    const releaseReceipt = await releaseTx.wait();
    const releaseEvent = releaseReceipt?.logs
      .map((log) => {
        try {
          return lockbox.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .find((log) => log?.name === "ReleaseExecuted");
    expect(releaseEvent?.args.releaseId).to.equal(releaseId);
    let reverted = false;
    try {
      await lockbox.releaseERC20(releaseId, assetId, recipient.address, 1n);
    } catch (error) {
      reverted = String(error).includes("ReleaseAlreadyProcessed");
    }
    expect(reverted).to.equal(true);
  });
});
