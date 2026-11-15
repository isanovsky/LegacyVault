// Semua komunikasi dengan blockchain ada di file ini.
//
// UI tidak memakai MetaMask dan tidak menyimpan private key. Anvil membuka akun-akun
// bawaannya, sehingga transaksi bisa dikirim atas nama akun itu lewat eth_sendTransaction.
// Karena cara ini hanya aman di jaringan lokal, setiap transaksi dan setiap perintah
// "majukan waktu" memeriksa chainId lebih dulu dan menolak jika bukan 31337.
import { Contract, JsonRpcProvider } from "ethers";
import contractInfo from "./contract.json";

export const ANVIL_CHAIN_ID = 31337n;
export const RPC_URL = "http://127.0.0.1:8545";
export const VAULT_ADDRESS = contractInfo.address;
const DEPLOY_BLOCK = contractInfo.deployBlock;

// staticNetwork: jangan mendeteksi ulang jaringan terus-menerus; chainId diperiksa sendiri di bawah.
export const provider = new JsonRpcProvider(RPC_URL, Number(ANVIL_CHAIN_ID), {
  staticNetwork: true,
  pollingInterval: 1000,
});

export const vault = new Contract(VAULT_ADDRESS, contractInfo.abi, provider);

export class WrongNetworkError extends Error {}

export async function getChainId() {
  return BigInt(await provider.send("eth_chainId", []));
}

async function requireAnvil() {
  const chainId = await getChainId();
  if (chainId !== ANVIL_CHAIN_ID) {
    throw new WrongNetworkError(
      `Ditolak: fitur ini hanya untuk Anvil (chainId 31337), sedangkan jaringan ini chainId ${chainId}.`,
    );
  }
}

export async function isVaultDeployed() {
  return (await provider.getCode(VAULT_ADDRESS)) !== "0x";
}

/** Baca elemen array publik satu per satu sampai habis (kontrak tidak punya getter panjang array). */
async function readArray(getter, max) {
  const items = [];
  for (let i = 0; i < max; i++) {
    try {
      items.push(await getter(i));
    } catch {
      break;
    }
  }
  return items;
}

const blockTimes = new Map();
async function blockTimestamp(blockNumber) {
  if (!blockTimes.has(blockNumber)) {
    const block = await provider.getBlock(blockNumber);
    blockTimes.set(blockNumber, BigInt(block.timestamp));
  }
  return blockTimes.get(blockNumber);
}

/** Ambil seluruh keadaan vault yang dibutuhkan UI dalam satu kali baca. */
export async function readVault(accounts) {
  const latest = await provider.getBlock("latest");
  const [rawStatus, owner, snapshot] = await Promise.all([vault.getStatus(), vault.owner(), vault.snapshot()]);
  const status = {
    state: Number(rawStatus.state),
    balance: rawStatus.balance,
    lastCheckIn: rawStatus.lastCheckIn,
    activeUntil: rawStatus.activeUntil,
    claimId: rawStatus.claimId,
    approvals: rawStatus.approvals,
    threshold: rawStatus.threshold,
    unlockTime: rawStatus.unlockTime,
  };

  const heirAddresses = await readArray((i) => vault.heirs(i), 10);
  const heirs = await Promise.all(
    heirAddresses.map(async (address, i) => ({
      address,
      bps: await vault.sharesBps(i),
      inheritance: await vault.inheritanceOf(address),
    })),
  );

  const guardianAddresses = await readArray((i) => vault.guardians(i), 10);
  const guardians = await Promise.all(
    guardianAddresses.map(async (address) => ({
      address,
      approved: status.claimId > 0n ? await vault.hasApproved(status.claimId, address) : false,
    })),
  );

  // Peran setiap tokoh dibaca dari kontrak, bukan ditulis tetap di UI.
  const roles = new Map();
  const balances = new Map();
  await Promise.all(
    accounts.map(async ({ address }) => {
      const [isHeir, isGuardian, balance] = await Promise.all([
        vault.isHeir(address),
        vault.isGuardian(address),
        provider.getBalance(address),
      ]);
      let role = "other";
      if (address.toLowerCase() === owner.toLowerCase()) role = "owner";
      else if (isHeir) role = "heir";
      else if (isGuardian) role = "guardian";
      roles.set(address, role);
      balances.set(address, balance);
    }),
  );

  const logs = await vault.queryFilter("*", DEPLOY_BLOCK, latest.number);
  const events = await Promise.all(
    logs
      .filter((log) => log.fragment)
      .map(async (log) => ({
        name: log.fragment.name,
        args: log.args,
        blockNumber: log.blockNumber,
        logIndex: log.index,
        txHash: log.transactionHash,
        timestamp: await blockTimestamp(log.blockNumber),
      })),
  );

  return {
    blockNumber: latest.number,
    now: BigInt(latest.timestamp),
    status,
    owner,
    snapshot,
    heirs,
    guardians,
    roles,
    balances,
    events,
  };
}

/**
 * Kirim transaksi atas nama salah satu akun Anvil.
 * Transaksi disimulasikan dulu (staticCall). Jika kontrak akan menolak, error-nya muncul di sini
 * lengkap dengan nama custom error, dan tidak ada transaksi gagal yang dikirim.
 */
export async function sendAction(fromAddress, method, args = [], value = 0n) {
  await requireAnvil();
  const signer = await provider.getSigner(fromAddress);
  const connected = vault.connect(signer);
  const overrides = value > 0n ? { value } : {};

  await connected[method].staticCall(...args, overrides);
  const tx = await connected[method](...args, overrides);
  return tx.wait();
}

/** Majukan jam blockchain Anvil, lalu buat satu blok baru supaya waktu baru berlaku. */
export async function advanceTime(seconds) {
  await requireAnvil();
  await provider.send("evm_increaseTime", [seconds]);
  await provider.send("evm_mine", []);
}
