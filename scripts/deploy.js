const hre = require("hardhat");

async function main() {
  console.log("=== AI Proof of Reserves - BNB Chain Deployment ===\n");
  console.log(`Network: ${hre.network.name} | Chain ID: ${hre.network.config.chainId}`);

  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log(`Balance: ${hre.ethers.formatEther(balance)} BNB\n`);

  if (balance === 0n) {
    console.error("ERROR: No BNB balance. Get testnet BNB from https://www.bnbchain.org/en/testnet-faucet");
    process.exit(1);
  }

  console.log("Deploying AIProofOfReserves...");
  const Factory = await hre.ethers.getContractFactory("AIProofOfReserves");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log(`\nContract: ${address}`);
  console.log(`TX: ${contract.deploymentTransaction().hash}`);

  // Setup custody addresses
  console.log("\nSetting up custody addresses...");
  await (await contract.addCustodyAddress("bitcoin", "bc1p25myx0eu5sarn09pfa6qlcnl6fgvf9249w3f3l3dfu4htmfz0w6svshd3h")).wait();
  await (await contract.addCustodyAddress("solana", "386JZJtkvf43yoNawAHmHHeEhZWUTZ4UuJJtxC9fpump")).wait();
  await (await contract.addCustodyAddress("bnb", deployer.address)).wait();

  // Publish initial AI report
  console.log("Publishing initial AI reserve report...");
  const evidence = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("AI-PoR-BNB-Hack-2026"));
  await (await contract.publishReport(hre.ethers.parseUnits("2100000000", 0), 95, evidence, ["bitcoin", "solana", "bnb"])).wait();

  // Register STBTCx
  await (await contract.registerAsset("Standard Bitcoin X", "STBTCx", 9)).wait();

  // Save deployment info
  const fs = require("fs");
  fs.writeFileSync("deployment.json", JSON.stringify({
    network: hre.network.name,
    chainId: hre.network.config.chainId,
    contract: address,
    deployer: deployer.address,
    txHash: contract.deploymentTransaction().hash,
    bscScan: `https://testnet.bscscan.com/address/${address}`,
    timestamp: new Date().toISOString()
  }, null, 2));

  console.log(`\n=== SUCCESS ===`);
  console.log(`Contract: ${address}`);
  console.log(`BscScan: https://testnet.bscscan.com/address/${address}`);
}

main().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
