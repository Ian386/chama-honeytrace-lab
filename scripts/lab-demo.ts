import { network } from "hardhat";
import { formatEther, parseEther } from "viem";

// Uses --network if given (e.g. localhost), otherwise an in-process chain.
const { viem } = await network.create();
const publicClient = await viem.getPublicClient();
const [treasurer, alice, bob] = await viem.getWalletClients();
const short = (a: string) => `${a.slice(0, 6)}...${a.slice(-4)}`;
const why = (e: any) => {
  const d = e?.cause?.data ?? e?.cause?.cause?.data;
  return d?.errorName ? `${d.errorName}(${(d.args ?? []).join(", ")})` : (e?.cause?.reason ?? e?.shortMessage);
};

// ---------- Part 1: Chama (moving money) ----------
console.log("\n=== PART 1: CHAMA ===");
const chama = await viem.deployContract("Chama");
console.log("Chama deployed at", chama.address, "by treasurer", short(treasurer.account.address));

const asAlice = await viem.getContractAt("Chama", chama.address, { client: { wallet: alice } });
const asBob = await viem.getContractAt("Chama", chama.address, { client: { wallet: bob } });

await publicClient.waitForTransactionReceipt({ hash: await asAlice.write.deposit({ value: parseEther("2") }) });
await publicClient.waitForTransactionReceipt({ hash: await asBob.write.deposit({ value: parseEther("1") }) });
await publicClient.waitForTransactionReceipt({ hash: await asAlice.write.transferTo([bob.account.address, parseEther("0.5")]) });
await publicClient.waitForTransactionReceipt({ hash: await asBob.write.withdraw([parseEther("1")]) });

for (const [name, w] of [["Alice", alice], ["Bob", bob]] as const) {
  console.log(`${name} savings:`, formatEther(await chama.read.balances([w.account.address])), "ETH");
}
console.log("Total savings:", formatEther(await chama.read.totalSavings()), "ETH");
console.log("Contract ETH :", formatEther(await chama.read.contractBalance()), "ETH");

try {
  await asAlice.write.withdraw([parseEther("100")]);
} catch (e: any) {
  console.log("Overdraw blocked ->", why(e));
}

console.log("\nChama event log:");
for (const name of ["Deposited", "Transferred", "Withdrawn"] as const) {
  const logs = await publicClient.getContractEvents({ address: chama.address, abi: chama.abi, eventName: name, fromBlock: 0n });
  for (const l of logs) {
    const a = l.args as Record<string, any>;
    const parts = Object.entries(a).map(([k, v]) => `${k}=${typeof v === "bigint" ? formatEther(v) + " ETH" : short(String(v))}`);
    console.log(`  block ${l.blockNumber} ${name}: ${parts.join(", ")}`);
  }
}

// ---------- Part 2: HoneyTrace (traceability) ----------
console.log("\n=== PART 2: HONEYTRACE ===");
const trace = await viem.deployContract("HoneyTrace");
await publicClient.waitForTransactionReceipt({ hash: await trace.write.addHandler([alice.account.address]) });
await publicClient.waitForTransactionReceipt({ hash: await trace.write.createBatch(["Kitui, beekeeper group A"]) });

const traceAsAlice = await viem.getContractAt("HoneyTrace", trace.address, { client: { wallet: alice } });
await publicClient.waitForTransactionReceipt({ hash: await traceAsAlice.write.advanceStage([1n]) });
await publicClient.waitForTransactionReceipt({ hash: await trace.write.advanceStage([1n]) });

const traceAsBob = await viem.getContractAt("HoneyTrace", trace.address, { client: { wallet: bob } });
try {
  await traceAsBob.write.advanceStage([1n]);
} catch (e: any) {
  console.log("Unapproved handler blocked ->", why(e));
}

const stages = ["Harvested", "Processed", "Packaged", "Shipped", "Delivered"];
const history = await publicClient.getContractEvents({ address: trace.address, abi: trace.abi, eventName: "StageUpdated", args: { id: 1n }, fromBlock: 0n });
console.log("\nBatch #1 audit trail (rebuilt from events):");
for (const h of history) {
  console.log(`  block ${h.blockNumber}: ${stages[Number(h.args.stage)]} by ${short(h.args.by!)}`);
}
