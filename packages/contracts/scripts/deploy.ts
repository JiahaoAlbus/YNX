import fs from "node:fs";
import path from "node:path";

import { network } from "hardhat";

const { ethers } = await network.connect();

const DEVNET = {
  chainId: 31337,
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
  const [deployer, teamBeneficiary, communityRecipient] = await ethers.getSigners();

  const NYXT = await ethers.getContractFactory("NYXT", deployer);
  const token = await NYXT.deploy(
    deployer.address,
    deployer.address,
    DEVNET.genesisSupply,
  );

  const Timelock = await ethers.getContractFactory("YNXTimelock", deployer);
  const timelock = await Timelock.deploy(
    BigInt(DEVNET.governance.timelockDelaySeconds),
    [],
    [],
    deployer.address,
  );

  const Treasury = await ethers.getContractFactory("YNXTreasury", deployer);
  const treasury = await Treasury.deploy(await timelock.getAddress());

  const Governor = await ethers.getContractFactory("YNXGovernor", deployer);
  const governor = await Governor.deploy(
    await token.getAddress(),
    await token.getAddress(),
    await timelock.getAddress(),
    await treasury.getAddress(),
    DEVNET.governance.votingDelayBlocks,
    DEVNET.governance.votingPeriodBlocks,
    DEVNET.governance.proposalThreshold,
    DEVNET.governance.proposalDeposit,
    DEVNET.governance.quorumPercent,
  );

  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
  await timelock.grantRole(PROPOSER_ROLE, await governor.getAddress());
  await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress);

  const OrgRegistry = await ethers.getContractFactory("YNXOrgRegistry", deployer);
  const orgRegistry = await OrgRegistry.deploy();

  const SubjectRegistry = await ethers.getContractFactory("YNXSubjectRegistry", deployer);
  const subjectRegistry = await SubjectRegistry.deploy(await orgRegistry.getAddress());

  const Arbitration = await ethers.getContractFactory("YNXArbitration", deployer);
  const arbitration = await Arbitration.deploy(await orgRegistry.getAddress());

  const latest = await ethers.provider.getBlock("latest");
  const now = latest?.timestamp ?? Math.floor(Date.now() / 1000);
  const startTimestamp = BigInt(now + DEVNET.vesting.cliffSeconds);

  const TeamVesting = await ethers.getContractFactory("NYXTTeamVesting", deployer);
  const teamVesting = await TeamVesting.deploy(
    teamBeneficiary.address,
    startTimestamp,
    BigInt(DEVNET.vesting.vestingSeconds),
  );

  const teamAllocation = percentOf(DEVNET.genesisSupply, DEVNET.allocations.teamPercent);
  const treasuryAllocation = percentOf(DEVNET.genesisSupply, DEVNET.allocations.treasuryPercent);
  const communityAllocation = percentOf(DEVNET.genesisSupply, DEVNET.allocations.communityPercent);
  const checkSum = teamAllocation + treasuryAllocation + communityAllocation;
  if (checkSum !== DEVNET.genesisSupply) {
    throw new Error(`Allocation mismatch: got ${checkSum} expected ${DEVNET.genesisSupply}`);
  }

  await token.transfer(await treasury.getAddress(), treasuryAllocation);
  await token.transfer(await teamVesting.getAddress(), teamAllocation);
  await token.transfer(communityRecipient.address, communityAllocation);

  const summary = {
    chainId: DEVNET.chainId,
    contracts: {
      nyxt: await token.getAddress(),
      timelock: await timelock.getAddress(),
      treasury: await treasury.getAddress(),
      governor: await governor.getAddress(),
      teamVesting: await teamVesting.getAddress(),
      orgRegistry: await orgRegistry.getAddress(),
      subjectRegistry: await subjectRegistry.getAddress(),
      arbitration: await arbitration.getAddress(),
    },
    accounts: {
      deployer: deployer.address,
      teamBeneficiary: teamBeneficiary.address,
      communityRecipient: communityRecipient.address,
    },
    params: DEVNET,
  };

  const outDir = path.join(process.cwd(), "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, `devnet-${DEVNET.chainId}.json`);
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
