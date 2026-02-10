import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("Order modules (v0)", () => {
  it("orgs + subjects + opt-in arbitration", async () => {
    const [deployer, orgAdmin, arb1, arb2] = await ethers.getSigners();

    const Org = await ethers.getContractFactory("YNXOrgRegistry", deployer);
    const orgRegistry = await Org.deploy();

    const orgId = await orgRegistry
      .connect(deployer)
      .createOrg.staticCall(orgAdmin.address, "ipfs://org-metadata");
    await orgRegistry.connect(deployer).createOrg(orgAdmin.address, "ipfs://org-metadata");

    const ARBITRATOR_ROLE = ethers.keccak256(ethers.toUtf8Bytes("ARBITRATOR"));

    await orgRegistry.connect(orgAdmin).setRole(orgId, ARBITRATOR_ROLE, arb1.address, true);
    await orgRegistry.connect(orgAdmin).setRole(orgId, ARBITRATOR_ROLE, arb2.address, true);

    const Subjects = await ethers.getContractFactory("YNXSubjectRegistry", deployer);
    const subjects = await Subjects.deploy(await orgRegistry.getAddress());

    await subjects.connect(arb1).setMyAddressProfileURI("ipfs://arb1");
    expect(await subjects.addressProfileURI(arb1.address)).to.equal("ipfs://arb1");

    await subjects.connect(orgAdmin).setOrgProfileURI(orgId, "ipfs://org-profile");
    expect(await subjects.orgProfileURI(orgId)).to.equal("ipfs://org-profile");

    const Arbitration = await ethers.getContractFactory("YNXArbitration", deployer);
    const arbitration = await Arbitration.deploy(await orgRegistry.getAddress());

    await arbitration.connect(orgAdmin).setCourtQuorum(orgId, 2);

    const Mock = await ethers.getContractFactory("MockArbitrable", deployer);
    const mock = await Mock.deploy();

    const data = ethers.getBytes("0x1234");
    const disputeId = await arbitration
      .connect(deployer)
      .openDispute.staticCall(await mock.getAddress(), orgId, data);
    await arbitration.connect(deployer).openDispute(await mock.getAddress(), orgId, data);

    let executeBeforeResolveFailed = false;
    try {
      await arbitration.connect(deployer).executeCallback(disputeId);
    } catch {
      executeBeforeResolveFailed = true;
    }
    expect(executeBeforeResolveFailed).to.equal(true);

    await arbitration.connect(arb1).vote(disputeId, 1);
    await arbitration.connect(arb2).vote(disputeId, 1);

    const dispute = await arbitration.disputes(disputeId);
    expect(dispute.resolved).to.equal(true);
    expect(dispute.ruling).to.equal(1n);

    await arbitration.connect(deployer).executeCallback(disputeId);
    expect(await mock.lastDisputeId()).to.equal(disputeId);
    expect(await mock.lastRuling()).to.equal(1n);
    expect(await mock.lastData()).to.equal(ethers.hexlify(data));
  });
});
