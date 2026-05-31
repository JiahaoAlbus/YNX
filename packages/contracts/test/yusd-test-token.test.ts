import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

async function expectRevert(promise: Promise<unknown>, errorName: string) {
  try {
    await promise;
  } catch (error) {
    expect(String(error)).to.include(errorName);
    return;
  }
  expect.fail(`Expected revert ${errorName}`);
}

describe("YUSDTestToken", function () {
  async function deployFixture() {
    const [owner, recipient, other] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("YUSDTestToken", owner);
    const token = await Token.deploy(owner.address, recipient.address, ethers.parseUnits("1000", 6));
    await token.waitForDeployment();
    return { token, owner, recipient, other };
  }

  it("uses stablecoin-style 6 decimals and mints initial test supply", async function () {
    const { token, recipient } = await deployFixture();
    expect(await token.name()).to.equal("YUSD Test Dollar");
    expect(await token.symbol()).to.equal("YUSD.test");
    expect(await token.decimals()).to.equal(6n);
    expect(await token.balanceOf(recipient.address)).to.equal(ethers.parseUnits("1000", 6));
  });

  it("restricts minting to minters", async function () {
    const { token, owner, other } = await deployFixture();
    await expectRevert(token.connect(other).mint(other.address, 1n), "AccessControl");
    await token.connect(owner).mint(other.address, ethers.parseUnits("1", 6));
    expect(await token.balanceOf(other.address)).to.equal(ethers.parseUnits("1", 6));
  });

  it("can pause transfers", async function () {
    const { token, owner, recipient, other } = await deployFixture();
    await token.connect(owner).pause();
    await expectRevert(token.connect(recipient).transfer(other.address, 1n), "EnforcedPause");
    await token.connect(owner).unpause();
    await token.connect(recipient).transfer(other.address, 1n);
    expect(await token.balanceOf(other.address)).to.equal(1n);
  });
});
