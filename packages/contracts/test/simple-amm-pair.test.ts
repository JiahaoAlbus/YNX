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

describe("YNXSimpleAMMPair", function () {
  async function deployFixture() {
    const [owner, trader] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("YUSDTestToken", owner);
    const tokenA = await Token.deploy(owner.address, owner.address, ethers.parseUnits("10000", 6));
    const tokenB = await Token.deploy(owner.address, owner.address, ethers.parseUnits("10000", 6));
    await tokenA.waitForDeployment();
    await tokenB.waitForDeployment();

    const Pair = await ethers.getContractFactory("YNXSimpleAMMPair", owner);
    const pair = await Pair.deploy(await tokenA.getAddress(), await tokenB.getAddress(), "YNX LP A-B", "ynxLP-A-B");
    await pair.waitForDeployment();
    const pairAddress = await pair.getAddress();
    await tokenA.approve(pairAddress, ethers.parseUnits("1000", 6));
    await tokenB.approve(pairAddress, ethers.parseUnits("1000", 6));
    await pair.addLiquidity(ethers.parseUnits("1000", 6), ethers.parseUnits("1000", 6), owner.address);
    await tokenA.transfer(trader.address, ethers.parseUnits("10", 6));
    return { tokenA, tokenB, pair, owner, trader };
  }

  it("adds liquidity and issues LP shares", async function () {
    const { pair, owner } = await deployFixture();
    expect(await pair.balanceOf(owner.address)).to.be.greaterThan(0n);
    expect(await pair.reserve0()).to.equal(ethers.parseUnits("1000", 6));
    expect(await pair.reserve1()).to.equal(ethers.parseUnits("1000", 6));
  });

  it("swaps with a fee and updates reserves", async function () {
    const { tokenA, tokenB, pair, trader } = await deployFixture();
    const tokenAAddress = await tokenA.getAddress();
    await tokenA.connect(trader).approve(await pair.getAddress(), ethers.parseUnits("1", 6));
    const before = await tokenB.balanceOf(trader.address);
    const quote = await pair.quote(tokenAAddress, ethers.parseUnits("1", 6));
    await pair.connect(trader).swap(tokenAAddress, ethers.parseUnits("1", 6), quote, trader.address);
    const after = await tokenB.balanceOf(trader.address);
    expect(after - before).to.equal(quote);
  });

  it("enforces min output", async function () {
    const { tokenA, pair, trader } = await deployFixture();
    const tokenAAddress = await tokenA.getAddress();
    await tokenA.connect(trader).approve(await pair.getAddress(), ethers.parseUnits("1", 6));
    await expectRevert(
      pair.connect(trader).swap(tokenAAddress, ethers.parseUnits("1", 6), ethers.parseUnits("2", 6), trader.address),
      "InsufficientOutputAmount",
    );
  });
});
