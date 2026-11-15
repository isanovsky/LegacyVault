// Fungsi bantu untuk menampilkan angka, tanggal, dan alamat dalam format Indonesia.
import { formatEther, parseEther } from "ethers";

export const STATE_NAMES = ["Active", "Claiming", "Distributed"];
export const STATE_DESCRIPTIONS = [
  "Pemilik dianggap aktif dan menguasai dana.",
  "Klaim warisan berjalan. Pemilik masih bisa membatalkan.",
  "Final. Setiap ahli waris menarik bagiannya sendiri.",
];

/** 10500000000000000000n -> "10,5 ETH". Tidak dibulatkan, supaya sisa pembulatan wei tetap terlihat. */
export function formatEth(wei) {
  const [whole, fraction = ""] = formatEther(wei).split(".");
  const trimmed = fraction.replace(/0+$/, "");
  const grouped = BigInt(whole).toLocaleString("id-ID");
  return `${grouped}${trimmed ? "," + trimmed : ""} ETH`;
}

/**
 * Versi dibulatkan ke bawah 4 desimal, untuk saldo dompet yang ikut berkurang karena biaya gas
 * (misalnya 9.988,997026099801506561 ETH menjadi "± 9.988,997 ETH"). Saldo vault dan bagian
 * warisan tetap memakai formatEth supaya tepat sampai wei.
 */
export function formatEthApprox(wei) {
  const [whole, fraction = ""] = formatEther(wei).split(".");
  const trimmed = fraction.slice(0, 4).replace(/0+$/, "");
  const exact = fraction.replace(/0+$/, "").length <= 4;
  const grouped = BigInt(whole).toLocaleString("id-ID");
  return `${exact ? "" : "± "}${grouped}${trimmed ? "," + trimmed : ""} ETH`;
}

/** "1,5" atau "1.5" -> wei. Melempar error jika bukan angka positif yang valid. */
export function parseEthInput(text) {
  const normalized = String(text).trim().replace(",", ".");
  if (!/^\d+(\.\d{1,18})?$/.test(normalized)) {
    throw new Error("Jumlah ETH tidak valid. Contoh yang benar: 1 atau 0,5.");
  }
  return parseEther(normalized);
}

/** 6000 bps -> "60%", 3333 bps -> "33,33%". */
export function formatPercent(bps) {
  const value = Number(bps) / 100;
  return `${value.toLocaleString("id-ID", { maximumFractionDigits: 2 })}%`;
}

const longDate = new Intl.DateTimeFormat("id-ID", { dateStyle: "long", timeStyle: "short" });
const shortDate = new Intl.DateTimeFormat("id-ID", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

/** Detik Unix (bigint) -> "12 Mei 2027 pukul 10.30". */
export function formatDate(seconds) {
  return longDate.format(new Date(Number(seconds) * 1000));
}

/** Versi ringkas untuk buku catatan event. */
export function formatDateShort(seconds) {
  return shortDate.format(new Date(Number(seconds) * 1000));
}

/** Selisih detik -> "120 hari 3 jam", "5 jam 10 menit", atau "kurang dari 1 menit". */
export function formatDuration(seconds) {
  let rest = Number(seconds);
  const days = Math.floor(rest / 86400);
  rest -= days * 86400;
  const hours = Math.floor(rest / 3600);
  rest -= hours * 3600;
  const minutes = Math.floor(rest / 60);
  if (days > 0) return hours > 0 ? `${days} hari ${hours} jam` : `${days} hari`;
  if (hours > 0) return minutes > 0 ? `${hours} jam ${minutes} menit` : `${hours} jam`;
  if (minutes > 0) return `${minutes} menit`;
  return "kurang dari 1 menit";
}

export function shortHash(hash) {
  return `${hash.slice(0, 8)}…${hash.slice(-6)}`;
}

export function shortAddress(address) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}
