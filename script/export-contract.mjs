// Menyalin alamat kontrak hasil deploy lokal dan ABI-nya ke ui/src/contract.json,
// supaya UI tahu kontrak mana yang harus dihubungi tanpa disalin manual.
//
// Pemakaian: node script/export-contract.mjs <NamaSkrip.s.sol>
// Contoh   : node script/export-contract.mjs SeedDemo.s.sol
//
// Sumber data:
// - broadcast/<NamaSkrip>/31337/run-latest.json : catatan transaksi yang dibuat `forge script --broadcast`
// - out/LegacyVault.sol/LegacyVault.json         : hasil kompilasi, berisi ABI

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";

const ANVIL_CHAIN_ID = 31337;
const scriptName = process.argv[2];

if (!scriptName) {
  console.error("Pemakaian: node script/export-contract.mjs <NamaSkrip.s.sol>");
  process.exit(1);
}

// Hanya hasil deploy di Anvil yang diekspor otomatis. Alamat dari jaringan lain
// harus dimasukkan dengan sadar, bukan tertimpa diam-diam.
const broadcastPath = `broadcast/${scriptName}/${ANVIL_CHAIN_ID}/run-latest.json`;
const run = JSON.parse(readFileSync(broadcastPath, "utf8"));

const deployTx = run.transactions.find(
  (tx) => tx.transactionType === "CREATE" && tx.contractName === "LegacyVault",
);
if (!deployTx) {
  console.error(`Tidak ada transaksi deploy LegacyVault di ${broadcastPath}`);
  process.exit(1);
}

const receipt = run.receipts.find((r) => r.transactionHash === deployTx.hash);
if (!receipt || receipt.status !== "0x1") {
  console.error("Transaksi deploy tidak ditemukan atau gagal.");
  process.exit(1);
}

const artifact = JSON.parse(readFileSync("out/LegacyVault.sol/LegacyVault.json", "utf8"));

const output = {
  chainId: ANVIL_CHAIN_ID,
  address: deployTx.contractAddress,
  // Blok tempat kontrak dibuat; UI bisa membaca event mulai dari blok ini.
  deployBlock: parseInt(receipt.blockNumber, 16),
  deployedBy: scriptName,
  abi: artifact.abi,
};

mkdirSync("ui/src", { recursive: true });
writeFileSync("ui/src/contract.json", JSON.stringify(output, null, 2) + "\n");
console.log(`ui/src/contract.json diperbarui: ${output.address} (blok ${output.deployBlock})`);
