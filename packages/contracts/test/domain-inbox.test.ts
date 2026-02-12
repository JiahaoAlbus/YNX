import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("Execution domains (v0)", () => {
  it("registers domains and posts commitments", async () => {
    const [deployer, owner, submitter, other] = await ethers.getSigners();

    const Inbox = await ethers.getContractFactory("YNXDomainInbox", deployer);
    const inbox = await Inbox.deploy();

    const domainId = ethers.id("domain:example");

    await inbox.connect(owner).registerDomain(domainId, "ipfs://domain-metadata");
    expect(await inbox.domainOwner(domainId)).to.equal(owner.address);
    expect(await inbox.domainMetadata(domainId)).to.equal("ipfs://domain-metadata");
    expect(await inbox.domainSubmitter(domainId, owner.address)).to.equal(true);

    let doubleRegisterFailed = false;
    try {
      await inbox.connect(owner).registerDomain(domainId, "ipfs://domain-metadata-2");
    } catch {
      doubleRegisterFailed = true;
    }
    expect(doubleRegisterFailed).to.equal(true);

    await inbox.connect(owner).setDomainSubmitter(domainId, submitter.address, true);
    expect(await inbox.domainSubmitter(domainId, submitter.address)).to.equal(true);

    const batch = 1;
    const stateRoot = ethers.keccak256(ethers.toUtf8Bytes("stateRoot"));
    const dataHash = ethers.keccak256(ethers.toUtf8Bytes("dataHash"));

    await inbox.connect(submitter).submitCommitment(domainId, batch, stateRoot, dataHash);

    const c = await inbox.commitments(domainId, batch);
    expect(c.exists).to.equal(true);
    expect(c.stateRoot).to.equal(stateRoot);
    expect(c.dataHash).to.equal(dataHash);
    expect(c.submitter).to.equal(submitter.address);

    let doubleSubmitFailed = false;
    try {
      await inbox.connect(submitter).submitCommitment(domainId, batch, stateRoot, dataHash);
    } catch {
      doubleSubmitFailed = true;
    }
    expect(doubleSubmitFailed).to.equal(true);

    let unauthorizedSubmitFailed = false;
    try {
      await inbox.connect(other).submitCommitment(domainId, 2, stateRoot, dataHash);
    } catch {
      unauthorizedSubmitFailed = true;
    }
    expect(unauthorizedSubmitFailed).to.equal(true);
  });
});

