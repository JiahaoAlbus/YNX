import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

async function expectRevert(promise: Promise<unknown>) {
  let reverted = false;
  try {
    await promise;
  } catch {
    reverted = true;
  }
  expect(reverted).to.equal(true);
}

describe("YNXBridgeGateway", () => {
  it("mints wrapped assets with threshold signatures and blocks replay", async () => {
    const [owner, signerA, signerB, signerC, user, relayer] = await ethers.getSigners();

    const Gateway = await ethers.getContractFactory("YNXBridgeGateway");
    const gateway = await Gateway.deploy(
      owner.address,
      [signerA.address, signerB.address, signerC.address],
      2,
      3600,
    );

    const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken");
    const wrapped = await Wrapped.deploy(
      "Wrapped BTC on YNX",
      "wBTC.y",
      8,
      owner.address,
      await gateway.getAddress(),
    );

    await gateway.setSupportedWrappedToken(await wrapped.getAddress(), true);

    const depositId = ethers.keccak256(ethers.toUtf8Bytes("btc:tx:1:0"));
    const amount = ethers.parseUnits("0.5", 8);
    const sourceChainId = 1;

    const payload = await gateway.mintAttestationPayload(
      depositId,
      await wrapped.getAddress(),
      user.address,
      amount,
      sourceChainId,
    );

    const sigA = await signerA.signMessage(ethers.getBytes(payload));
    const sigB = await signerB.signMessage(ethers.getBytes(payload));

    await gateway
      .connect(relayer)
      .mintWithAttestation(
        depositId,
        await wrapped.getAddress(),
        user.address,
        amount,
        sourceChainId,
        [sigA, sigB],
      );

    expect(await wrapped.balanceOf(user.address)).to.equal(amount);
    expect(await wrapped.decimals()).to.equal(8n);
    expect(await gateway.processedDeposits(depositId)).to.equal(true);

    await expectRevert(
      gateway.connect(relayer).mintWithAttestation(
        depositId,
        await wrapped.getAddress(),
        user.address,
        amount,
        sourceChainId,
        [sigA, sigB],
      ),
    );
  });

  it("burns wrapped assets for outbound bridge flow", async () => {
    const [owner, signerA, signerB, signerC, user, relayer] = await ethers.getSigners();

    const Gateway = await ethers.getContractFactory("YNXBridgeGateway");
    const gateway = await Gateway.deploy(
      owner.address,
      [signerA.address, signerB.address, signerC.address],
      2,
      3600,
    );

    const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken");
    const wrapped = await Wrapped.deploy(
      "Wrapped BNB on YNX",
      "wBNB.y",
      18,
      owner.address,
      await gateway.getAddress(),
    );

    await gateway.setSupportedWrappedToken(await wrapped.getAddress(), true);

    const depositId = ethers.keccak256(ethers.toUtf8Bytes("bnb:tx:2:1"));
    const amount = ethers.parseUnits("3", 18);
    const sourceChainId = 56;

    const payload = await gateway.mintAttestationPayload(
      depositId,
      await wrapped.getAddress(),
      user.address,
      amount,
      sourceChainId,
    );
    const sigA = await signerA.signMessage(ethers.getBytes(payload));
    const sigB = await signerB.signMessage(ethers.getBytes(payload));

    await gateway
      .connect(relayer)
      .mintWithAttestation(
        depositId,
        await wrapped.getAddress(),
        user.address,
        amount,
        sourceChainId,
        [sigA, sigB],
      );

    expect(await wrapped.totalSupply()).to.equal(amount);

    await wrapped.connect(user).approve(await gateway.getAddress(), amount);

    const recipient = ethers.zeroPadValue("0x1234", 32);
    await gateway.connect(user).burnForBridge(await wrapped.getAddress(), amount, 56, recipient);

    expect(await wrapped.totalSupply()).to.equal(0n);
    expect(await wrapped.balanceOf(user.address)).to.equal(0n);
    expect(await wrapped.balanceOf(await gateway.getAddress())).to.equal(0n);
    expect(await gateway.outboundNonce()).to.equal(1n);
  });

  it("supports generic route mapping for tron-style multi-asset onboarding", async () => {
    const [owner, signerA, signerB, signerC, user, relayer] = await ethers.getSigners();

    const Gateway = await ethers.getContractFactory("YNXBridgeGateway");
    const gateway = await Gateway.deploy(
      owner.address,
      [signerA.address, signerB.address, signerC.address],
      2,
      3600,
    );

    const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken");
    const wrappedUsdt = await Wrapped.deploy(
      "Wrapped USDT on YNX",
      "wUSDT.y",
      6,
      owner.address,
      await gateway.getAddress(),
    );

    await gateway.setSupportedWrappedToken(await wrappedUsdt.getAddress(), true);

    const tronChainId = 728126428;
    const tronUsdtAsset = ethers.keccak256(ethers.toUtf8Bytes("tron:trc20:TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"));
    await gateway.setBridgeRoute(tronChainId, tronUsdtAsset, await wrappedUsdt.getAddress());

    const depositId = ethers.keccak256(ethers.toUtf8Bytes("tron:block-1:tx-7:log-0"));
    const amount = ethers.parseUnits("1250", 6);

    const payload = await gateway.mintAttestationPayloadWithAsset(
      depositId,
      tronChainId,
      tronUsdtAsset,
      await wrappedUsdt.getAddress(),
      user.address,
      amount,
    );
    const sigA = await signerA.signMessage(ethers.getBytes(payload));
    const sigB = await signerB.signMessage(ethers.getBytes(payload));

    await gateway
      .connect(relayer)
      .mintWithMappedAttestation(
        depositId,
        tronChainId,
        tronUsdtAsset,
        user.address,
        amount,
        [sigA, sigB],
      );

    expect(await wrappedUsdt.balanceOf(user.address)).to.equal(amount);
    expect(await wrappedUsdt.decimals()).to.equal(6n);

    await wrappedUsdt.connect(user).approve(await gateway.getAddress(), amount);

    const tronRecipient = ethers.keccak256(ethers.toUtf8Bytes("tron:TXXXdestination"));
    await gateway
      .connect(user)
      .burnForBridgeMapped(await wrappedUsdt.getAddress(), amount, tronChainId, tronRecipient);
  });

  it("enforces signer-set timelock before taking effect", async () => {
    const [owner, signerA, signerB, signerC, signerD, user, relayer] = await ethers.getSigners();

    const Gateway = await ethers.getContractFactory("YNXBridgeGateway");
    const gateway = await Gateway.deploy(
      owner.address,
      [signerA.address, signerB.address, signerC.address],
      2,
      3600,
    );

    const Wrapped = await ethers.getContractFactory("YNXBridgeWrappedToken");
    const wrapped = await Wrapped.deploy(
      "Wrapped BTC on YNX",
      "wBTC.y",
      18,
      owner.address,
      await gateway.getAddress(),
    );
    await gateway.setSupportedWrappedToken(await wrapped.getAddress(), true);

    await gateway.proposeSignerSet([signerD.address], 1);
    await expectRevert(gateway.applyProposedSignerSet());

    await ethers.provider.send("evm_increaseTime", [3600]);
    await ethers.provider.send("evm_mine", []);
    await gateway.applyProposedSignerSet();
    expect(await gateway.signerEpoch()).to.equal(2n);

    const depositId = ethers.keccak256(ethers.toUtf8Bytes("btc:tx:new-epoch"));
    const amount = ethers.parseUnits("1", 18);
    const sourceChainId = 1;
    const payload = await gateway.mintAttestationPayload(
      depositId,
      await wrapped.getAddress(),
      user.address,
      amount,
      sourceChainId,
    );

    const oldSig = await signerA.signMessage(ethers.getBytes(payload));
    await expectRevert(
      gateway.connect(relayer).mintWithAttestation(
        depositId,
        await wrapped.getAddress(),
        user.address,
        amount,
        sourceChainId,
        [oldSig],
      ),
    );

    const newSig = await signerD.signMessage(ethers.getBytes(payload));
    await gateway
      .connect(relayer)
      .mintWithAttestation(
        depositId,
        await wrapped.getAddress(),
        user.address,
        amount,
        sourceChainId,
        [newSig],
      );

    expect(await wrapped.balanceOf(user.address)).to.equal(amount);
  });
});
