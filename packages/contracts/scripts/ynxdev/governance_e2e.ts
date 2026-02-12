import { network } from "hardhat";

const { ethers } = await network.connect();

const PROTOCOL_PRECOMPILE = "0x0000000000000000000000000000000000000810";

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForNextBlock(minDelta = 1, timeoutMs = 120_000): Promise<void> {
  const start = await ethers.provider.getBlockNumber();
  const deadline = Date.now() + timeoutMs;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const now = await ethers.provider.getBlockNumber();
    if (now >= start + minDelta) return;
    if (Date.now() > deadline) {
      throw new Error(`Timed out waiting for next block (start=${start}, now=${now})`);
    }
    await sleep(500);
  }
}

async function waitForProposalState(
  governor: { state: (proposalId: bigint) => Promise<bigint> },
  proposalId: bigint,
  expected: number,
  timeoutMs = 10 * 60_000,
): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  // eslint-disable-next-line no-constant-condition
  while (true) {
    const st = Number(await governor.state(proposalId));
    if (st === expected) return;
    if (Date.now() > deadline) {
      throw new Error(`Timed out waiting for proposal state=${expected}; got=${st}`);
    }
    await sleep(1000);
  }
}

function pick<T>(res: any, name: string, index: number): T {
  if (res && typeof res === "object" && name in res) return res[name] as T;
  if (Array.isArray(res) && res.length > index) return res[index] as T;
  throw new Error(`Missing field ${name} (index ${index})`);
}

async function main() {
  const net = await ethers.provider.getNetwork();
  const chainId = Number(net.chainId);
  console.log(`Connected: chainId=${chainId}`);

  const [signer] = await ethers.getSigners();
  console.log(`Signer: ${signer.address}`);

  const protocol = await ethers.getContractAt("IYNXProtocol", PROTOCOL_PRECOMPILE, signer);
  const sys = await protocol.getSystemContracts();

  const nyxt = pick<string>(sys, "nyxt", 0);
  const timelock = pick<string>(sys, "timelock", 1);
  const treasury = pick<string>(sys, "treasury", 2);
  const governorAddr = pick<string>(sys, "governor", 3);

  console.log(`NYXT:     ${nyxt}`);
  console.log(`Timelock: ${timelock}`);
  console.log(`Treasury: ${treasury}`);
  console.log(`Governor: ${governorAddr}`);

  const token = await ethers.getContractAt("NYXT", nyxt, signer);
  const governor = await ethers.getContractAt("YNXGovernor", governorAddr, signer);
  const timelockCtr = await ethers.getContractAt("YNXTimelock", timelock, signer);

  const before = await protocol.getParams();
  console.log("Protocol params (before):", before);

  const bal = await token.balanceOf(signer.address);
  console.log(`NYXT balance: ${bal.toString()}`);
  if (bal === 0n) {
    throw new Error("Signer has zero NYXT; cannot run governance E2E");
  }

  const currentDelegate = await token.delegates(signer.address);
  if (currentDelegate.toLowerCase() !== signer.address.toLowerCase()) {
    console.log("Delegating votes to self...");
    await (await token.delegate(signer.address)).wait();
    await waitForNextBlock(2, 120_000);
  } else {
    await waitForNextBlock(1, 120_000);
  }

  const deposit = await governor.proposalDeposit();
  if (deposit > 0n) {
    const allowance = await token.allowance(signer.address, governorAddr);
    if (allowance < deposit) {
      console.log(`Approving proposal deposit: ${deposit.toString()}`);
      await (await token.approve(governorAddr, deposit)).wait();
    }
  }

  const newFounder = signer.address;
  const newTreasury = treasury;

  const newFeeBurnBps = 3500;
  const newFeeTreasuryBps = 1000;
  const newFeeFounderBps = 1500;
  const newInflationTreasuryBps = Number(pick<bigint>(before, "inflationTreasuryBps", 5));

  const updateCalldata = protocol.interface.encodeFunctionData("updateParams", [
    newFounder,
    newTreasury,
    newFeeBurnBps,
    newFeeTreasuryBps,
    newFeeFounderBps,
    newInflationTreasuryBps,
  ]);

  const targets = [PROTOCOL_PRECOMPILE];
  const values = [0n];
  const calldatas = [updateCalldata];
  const description = "YNX: update protocol params via timelock (e2e)";
  const descriptionHash = ethers.id(description);

  console.log("Submitting proposal...");
  await (await governor.propose(targets, values, calldatas, description)).wait();

  const proposalId = await governor.hashProposal(targets, values, calldatas, descriptionHash);
  console.log(`proposalId: ${proposalId.toString()}`);

  console.log("Waiting for proposal to become Active...");
  await waitForProposalState(governor, proposalId, 1, 5 * 60_000);

  console.log("Casting vote: FOR");
  await (await governor.castVote(proposalId, 1)).wait();

  console.log("Waiting for proposal to Succeed...");
  await waitForProposalState(governor, proposalId, 4, 20 * 60_000);

  console.log("Queueing...");
  await (await governor.queue(targets, values, calldatas, descriptionHash)).wait();
  await waitForProposalState(governor, proposalId, 5, 5 * 60_000);

  const minDelay = Number(await timelockCtr.getMinDelay());
  console.log(`Timelock minDelay: ${minDelay}s`);
  if (minDelay > 0) {
    console.log("Waiting for timelock...");
    await sleep((minDelay + 2) * 1000);
  }

  console.log("Executing...");
  await (await governor.execute(targets, values, calldatas, descriptionHash)).wait();
  await waitForProposalState(governor, proposalId, 7, 5 * 60_000);

  const after = await protocol.getParams();
  console.log("Protocol params (after):", after);

  const afterFeeBurnBps = Number(pick<bigint>(after, "feeBurnBps", 2));
  const afterFeeTreasuryBps = Number(pick<bigint>(after, "feeTreasuryBps", 3));
  const afterFeeFounderBps = Number(pick<bigint>(after, "feeFounderBps", 4));

  if (afterFeeBurnBps !== newFeeBurnBps) throw new Error(`feeBurnBps mismatch: ${afterFeeBurnBps} != ${newFeeBurnBps}`);
  if (afterFeeTreasuryBps !== newFeeTreasuryBps) {
    throw new Error(`feeTreasuryBps mismatch: ${afterFeeTreasuryBps} != ${newFeeTreasuryBps}`);
  }
  if (afterFeeFounderBps !== newFeeFounderBps) {
    throw new Error(`feeFounderBps mismatch: ${afterFeeFounderBps} != ${newFeeFounderBps}`);
  }

  console.log("Governance E2E OK");
}

await main();

