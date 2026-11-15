// Menerjemahkan custom error dari kontrak menjadi kalimat yang bisa dibaca manusia.
// Kontrak mengembalikan error bernama, misalnya OwnerStillActive(activeUntil).
// ethers mendekode nama dan argumennya memakai ABI; fungsi di sini menyusun kalimatnya.
import { formatDate, formatEth, STATE_NAMES } from "./format.js";

const MESSAGES = {
  NotOwner: () => "hanya pemilik vault yang boleh melakukan ini.",
  NotGuardian: () => "hanya guardian yang dapat menyetujui klaim.",
  NotHeir: () => "hanya ahli waris yang dapat menarik warisan.",
  NotHeirOrGuardian: () => "hanya ahli waris atau guardian yang dapat memulai klaim.",
  InvalidState: ([expected, current]) =>
    `aksi ini hanya bisa dilakukan pada tahap ${STATE_NAMES[Number(expected)]}, ` +
    `sedangkan vault sekarang di tahap ${STATE_NAMES[Number(current)]}.`,
  OwnerStillActive: ([activeUntil]) => `pemilik masih aktif sampai ${formatDate(activeUntil)}.`,
  AlreadyApproved: ([claimId]) => `guardian ini sudah menyetujui klaim #${claimId}.`,
  NotEnoughApprovals: ([approvals, threshold]) =>
    `persetujuan guardian baru ${approvals} dari ${threshold} yang dibutuhkan.`,
  TimelockNotExpired: ([unlockTime]) =>
    unlockTime === 0n
      ? "masa tunggu belum dijadwalkan karena persetujuan belum cukup."
      : `masa tunggu belum selesai. Klaim baru bisa difinalisasi pada ${formatDate(unlockTime)}.`,
  InsufficientBalance: ([requested, available]) =>
    `saldo vault hanya ${formatEth(available)}, sedangkan yang diminta ${formatEth(requested)}.`,
  NothingToWithdraw: () => "tidak ada bagian yang bisa ditarik. Bagian ini mungkin sudah ditarik.",
  TransferFailed: () => "pengiriman ETH ke penerima gagal.",
  ZeroAddress: () => "ada alamat kosong (0x0) di daftar.",
  DuplicateAddress: ([account]) => `alamat ${account} muncul dua kali.`,
  OwnerCannotHaveRole: () => "pemilik tidak boleh menjadi ahli waris atau guardian.",
  GuardianCannotBeHeir: ([account]) => `guardian ${account} tidak boleh sekaligus ahli waris.`,
  InvalidHeirCount: ([count]) => `jumlah ahli waris harus 1 sampai 10, bukan ${count}.`,
  InvalidGuardianCount: ([count]) => `jumlah guardian harus 1 sampai 10, bukan ${count}.`,
  LengthMismatch: () => "jumlah ahli waris dan jumlah porsi tidak sama.",
  ZeroShare: () => "setiap ahli waris harus mendapat porsi lebih dari 0.",
  InvalidSharesTotal: ([total]) => `total porsi harus tepat 10000 bps (100%), bukan ${total}.`,
  InvalidThreshold: ([threshold, count]) => `threshold ${threshold} tidak valid untuk ${count} guardian.`,
  PeriodTooShort: () => "periode minimal 1 hari.",
};

/** Cari data revert (hex) di dalam objek error ethers, yang letaknya bisa berbeda-beda. */
function findRevertData(value, depth = 0) {
  if (depth > 5 || value == null) return null;
  if (typeof value === "string") return /^0x[0-9a-fA-F]{8}/.test(value) ? value : null;
  if (typeof value !== "object") return null;
  for (const key of ["data", "error", "info", "revert"]) {
    const found = findRevertData(value[key], depth + 1);
    if (found) return found;
  }
  return null;
}

/** Ubah error apa pun dari transaksi menjadi satu kalimat berbahasa Indonesia. */
export function describeError(err, contractInterface) {
  let decoded = err?.revert ?? null;
  if (!decoded) {
    const data = findRevertData(err);
    if (data) {
      try {
        decoded = contractInterface.parseError(data);
      } catch {
        decoded = null;
      }
    }
  }

  if (decoded && MESSAGES[decoded.name]) {
    return `Ditolak: ${MESSAGES[decoded.name](decoded.args)}`;
  }
  if (decoded) {
    return `Ditolak oleh kontrak: ${decoded.name}.`;
  }
  if (err?.code === "NETWORK_ERROR" || /fetch|ECONNREFUSED/i.test(String(err?.message))) {
    return "Tidak bisa terhubung ke Anvil di http://127.0.0.1:8545. Jalankan npm run anvil.";
  }
  return `Gagal: ${err?.shortMessage ?? err?.message ?? "alasan tidak diketahui"}`;
}
