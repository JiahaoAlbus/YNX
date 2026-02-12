import { network } from "hardhat";

const { ethers } = await network.connect();

const PROTOCOL_PRECOMPILE = "0x0000000000000000000000000000000000000810";

function pick<T>(res: any, name: string, index: number): T {
  if (res && typeof res === "object" && name in res) return res[name] as T;
  if (Array.isArray(res) && res.length > index) return res[index] as T;
  throw new Error(`Missing field ${name} (index ${index})`);
}

async function main() {
  const net = await ethers.provider.getNetwork();
  console.log(`Connected: chainId=${Number(net.chainId)}`);

  const [signer] = await ethers.getSigners();
  console.log(`Signer: ${signer.address}`);

  const protocol = await ethers.getContractAt("IYNXProtocol", PROTOCOL_PRECOMPILE, signer);
  const sys = await protocol.getSystemContracts();
  const domainInbox = pick<string>(sys, "domainInbox", 8);
  console.log(`DomainInbox: ${domainInbox}`);

  const inbox = await ethers.getContractAt("YNXDomainInbox", domainInbox, signer);

  const domainId = ethers.id("domain:demo");
  const owner = await inbox.domainOwner(domainId);
  if (owner === ethers.ZeroAddress) {
    console.log("Registering domain...");
    await (await inbox.registerDomain(domainId, "ipfs://ynx-domain-demo")).wait();
  } else {
    console.log(`Domain already registered: owner=${owner}`);
  }

  let batch = 1n;
  // Find the next unused batch.
  while (true) {
    const c = await inbox.commitments(domainId, batch);
    if (!c.exists) break;
    batch++;
  }

  const stateRoot = ethers.keccak256(ethers.toUtf8Bytes(`stateRoot:${Date.now()}`));
  const dataHash = ethers.keccak256(ethers.toUtf8Bytes(`dataHash:${Date.now()}`));

  console.log(`Submitting commitment: batch=${batch.toString()}`);
  await (await inbox.submitCommitment(domainId, batch, stateRoot, dataHash)).wait();

  const stored = await inbox.commitments(domainId, batch);
  console.log("Stored commitment:", stored);
  console.log("DomainInbox demo OK");
}

await main();
