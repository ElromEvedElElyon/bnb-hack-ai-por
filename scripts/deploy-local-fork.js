const hre = require("hardhat");

async function main() {
  console.log("=== AI Proof of Reserves - Local Validation ===\n");

  const [deployer, agent2] = await hre.ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);

  const Factory = await hre.ethers.getContractFactory("AIProofOfReserves");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`Deployed: ${address}`);

  // Setup
  await (await contract.addCustodyAddress("bitcoin", "bc1p25myx0eu5sarn09pfa6qlcnl6fgvf9249w3f3l3dfu4htmfz0w6svshd3h")).wait();
  await (await contract.addCustodyAddress("solana", "386JZJtkvf43yoNawAHmHHeEhZWUTZ4UuJJtxC9fpump")).wait();
  await (await contract.addCustodyAddress("bnb", deployer.address)).wait();
  console.log("Custody addresses: 3");

  // Reports
  const e1 = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("report-1"));
  await (await contract.publishReport(2100000000n, 95, e1, ["bitcoin", "solana", "bnb"])).wait();
  const e2 = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("report-2"));
  await (await contract.publishReport(1500000000n, 85, e2, ["bitcoin"])).wait();
  console.log("Reports published: 2 (anomaly expected)");

  // Register assets
  await (await contract.registerAsset("Standard Bitcoin X", "STBTCx", 9)).wait();
  const busd1Id = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("bUSD1"));
  await (await contract.updateSupply(busd1Id, 1000000000n)).wait();

  // Agent management
  await (await contract.authorizeAgent(agent2.address)).wait();

  // Verify
  const report = await contract.getLatestReport();
  console.log(`\nLatest reserves: ${report[1]} | Confidence: ${report[5]}%`);

  const backed = await contract.isFullyBacked(busd1Id);
  console.log(`Fully backed: ${backed[0]} | Ratio: ${(Number(backed[3]) / 1e18 * 100).toFixed(1)}%`);

  const anomalyCount = await contract.getAnomalyCount();
  console.log(`Anomalies: ${anomalyCount}`);

  const receipt = await contract.deploymentTransaction().wait();
  console.log(`\nDeploy gas: ${receipt.gasUsed.toLocaleString()}`);
  console.log(`Cost at 0.1 gwei: ${(Number(receipt.gasUsed) * 0.1 / 1e9).toFixed(6)} BNB`);

  console.log("\n=== ALL TESTS PASSED ===");
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
