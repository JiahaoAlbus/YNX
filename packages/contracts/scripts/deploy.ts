import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

const PARAMS = {
  tokenSymbol: "NYXT",
  genesisSupply: ethers.parseUnits("100000000000", 18), // 100B
  allocations: {
    teamPercent: 15n,
    treasuryPercent: 40n,
    communityPercent: 45n,
  },
  governance: {
    votingDelayBlocks: 1, // devnet-friendly (prod TBD)
    votingPeriodBlocks: 7 * 24 * 60 * 60, // 7d @ 1s blocks
    proposalThreshold: ethers.parseUnits("1000000", 18),
    proposalDeposit: ethers.parseUnits("100000", 18),
    quorumPercent: 10,
    timelockDelaySeconds: 7 * 24 * 60 * 60,
  },
  vesting: {
    cliffSeconds: 365 * 24 * 60 * 60,
    vestingSeconds: 4 * 365 * 24 * 60 * 60,
  },
} as const;

function percentOf(total: bigint, percent: bigint): bigint {
  return (total * percent) / 100n;
}

async function main() {
  const chainId = Number((await ethers.provider.getNetwork()).chainId);
  const [deployer, teamBeneficiary, communityRecipient] = await ethers.getSigners();

  const NYXT = await ethers.getContractFactory("NYXT", deployer);
  const token = await NYXT.deploy(
    deployer.address,
    deployer.address,
    PARAMS.genesisSupply,
  );
  await token.waitForDeployment();

  const Timelock = await ethers.getContractFactory("YNXTimelock", deployer);
  const timelock = await Timelock.deploy(
    BigInt(PARAMS.governance.timelockDelaySeconds),
    [],
    [],
    deployer.address,
  );
  await timelock.waitForDeployment();

  const Treasury = await ethers.getContractFactory("YNXTreasury", deployer);
  const treasury = await Treasury.deploy(await timelock.getAddress());
  await treasury.waitForDeployment();

  const Governor = await ethers.getContractFactory("YNXGovernor", deployer);
  const governor = await Governor.deploy(
    await token.getAddress(),
    await token.getAddress(),
    await timelock.getAddress(),
    await treasury.getAddress(),
    PARAMS.governance.votingDelayBlocks,
    PARAMS.governance.votingPeriodBlocks,
    PARAMS.governance.proposalThreshold,
    PARAMS.governance.proposalDeposit,
    PARAMS.governance.quorumPercent,
  );
  await governor.waitForDeployment();

  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
  await (await timelock.grantRole(PROPOSER_ROLE, await governor.getAddress())).wait();
  await (await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress)).wait();

  const OrgRegistry = await ethers.getContractFactory("YNXOrgRegistry", deployer);
  const orgRegistry = await OrgRegistry.deploy();
  await orgRegistry.waitForDeployment();

  const SubjectRegistry = await ethers.getContractFactory("YNXSubjectRegistry", deployer);
  const subjectRegistry = await SubjectRegistry.deploy(await orgRegistry.getAddress());
  await subjectRegistry.waitForDeployment();

  const Arbitration = await ethers.getContractFactory("YNXArbitration", deployer);
  const arbitration = await Arbitration.deploy(await orgRegistry.getAddress());
  await arbitration.waitForDeployment();

  const DomainInbox = await ethers.getContractFactory("YNXDomainInbox", deployer);
  const domainInbox = await DomainInbox.deploy();
  await domainInbox.waitForDeployment();

  const latest = await ethers.provider.getBlock("latest");
  const now = latest?.timestamp ?? Math.floor(Date.now() / 1000);
  const startTimestamp = BigInt(now + PARAMS.vesting.cliffSeconds);

  const TeamVesting = await ethers.getContractFactory("NYXTTeamVesting", deployer);
  const teamVesting = await TeamVesting.deploy(
    teamBeneficiary.address,
    startTimestamp,
    BigInt(PARAMS.vesting.vestingSeconds),
  );
  await teamVesting.waitForDeployment();

  const teamAllocation = percentOf(PARAMS.genesisSupply, PARAMS.allocations.teamPercent);
  const treasuryAllocation = percentOf(PARAMS.genesisSupply, PARAMS.allocations.treasuryPercent);
  const communityAllocation = percentOf(PARAMS.genesisSupply, PARAMS.allocations.communityPercent);
  const checkSum = teamAllocation + treasuryAllocation + communityAllocation;
  if (checkSum !== PARAMS.genesisSupply) {
    throw new Error(`Allocation mismatch: got ${checkSum} expected ${PARAMS.genesisSupply}`);
  }

  await (await token.transfer(await treasury.getAddress(), treasuryAllocation)).wait();
  await (await token.transfer(await teamVesting.getAddress(), teamAllocation)).wait();
  await (await token.transfer(communityRecipient.address, communityAllocation)).wait();

  const summary = {
    chainId,
    contracts: {
      nyxt: await token.getAddress(),
      timelock: await timelock.getAddress(),
      treasury: await treasury.getAddress(),
      governor: await governor.getAddress(),
      teamVesting: await teamVesting.getAddress(),
      orgRegistry: await orgRegistry.getAddress(),
      subjectRegistry: await subjectRegistry.getAddress(),
      arbitration: await arbitration.getAddress(),
      domainInbox: await domainInbox.getAddress(),
    },
    accounts: {
      deployer: deployer.address,
      teamBeneficiary: teamBeneficiary.address,
      communityRecipient: communityRecipient.address,
    },
    params: PARAMS,
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `devnet-${chainId}.json`);
  const json = JSON.stringify(
    summary,
    (_key, value) => (typeof value === "bigint" ? value.toString() : value),
    2,
  );
  fs.writeFileSync(outPath, `${json}\n`, "utf8");

  console.log(`Deployed. Wrote ${outPath}`);
  console.log(summary);
}

await main();
