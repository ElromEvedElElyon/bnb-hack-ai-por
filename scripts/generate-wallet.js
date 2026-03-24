const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

const envPath = path.join(__dirname, "..", ".env");
if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, "utf8");
  const key = content.match(/DEPLOYER_PRIVATE_KEY=(0x[a-fA-F0-9]{64})/);
  if (key) {
    const wallet = new ethers.Wallet(key[1]);
    console.log(`Existing wallet: ${wallet.address}`);
    console.log(`Get tBNB: https://www.bnbchain.org/en/testnet-faucet`);
    process.exit(0);
  }
}

const wallet = ethers.Wallet.createRandom();
console.log(`Address: ${wallet.address}`);
console.log(`Key: ${wallet.privateKey}`);

fs.writeFileSync(envPath, `DEPLOYER_PRIVATE_KEY=${wallet.privateKey}\nDEPLOYER_ADDRESS=${wallet.address}\n`);
console.log(`\nSaved to .env. Get tBNB from https://www.bnbchain.org/en/testnet-faucet`);
console.log(`Deploy: npx hardhat run scripts/deploy.js --network bnbTestnet`);
