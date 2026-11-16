// Halaman "Cara kerja": empat bagian penjelasan dengan animasi bertahap.
//
// Cara kerjanya sederhana. Setiap bagian punya satu adegan SVG dan daftar langkah. Setiap
// langkah menyebutkan:
//   focus  : bagian adegan yang disorot (sisanya dibuat pudar)
//   show   : bagian opsional yang muncul (misalnya cap, amplop, blok baru)
//   tokens : posisi benda yang berpindah (pesan, koin, amplop), dengan transisi CSS
//   texts  : teks di adegan yang diganti (misalnya saldo atau tanggal)
//   faces  : ekspresi tokoh di adegan
// Animasi tidak berjalan sendiri: penyaji menekan "Berikutnya" sesuai tempo bicaranya.
import "./style.css";
import { characterSvg } from "./characters.js";
import {
  ACCENT,
  INK,
  MUTED,
  SHADE,
  anvilIcon,
  arrow,
  arrowMarker,
  blocks,
  box,
  browserWindow,
  bubble,
  card,
  character,
  coin,
  documentIcon,
  envelope,
  hourglass,
  label,
  message,
  part,
  singleBlock,
  stampMark,
  token,
  vault,
} from "./scene-art.js";

const M = "panah";

// ===========================================================================
// Bagian 1: Peta arsitektur
// ===========================================================================

const architecture = {
  id: "arsitektur",
  title: "Peta arsitektur",
  intro: "Bagian-bagian yang bekerja saat Anda menekan tombol di halaman simulasi, dari layar sampai ke kontrak.",
  scene: `
    ${part("ui", `
      ${browserWindow(20, 90, 210, 210, "127.0.0.1:5173")}
      ${character("icanov", 65, 130, 120, "face-icanov")}
      ${label(125, 325, "UI di browser", { size: 17, kind: "title" })}
      ${label(125, 344, "Vite + JavaScript", { size: 12, color: MUTED, id: "ui-sub" })}`)}
    ${part("ethers", `
      ${arrow(232, 195, 270, 195, M)}
      ${box(272, 150, 140, 90, { title: "ethers.js", sub: "penerjemah" })}`)}
    ${part("rpc", `
      ${arrow(414, 195, 504, 195, M)}
      ${label(459, 182, "JSON-RPC", { size: 13 })}
      ${label(459, 216, "127.0.0.1:8545", { size: 10, kind: "mono", color: MUTED })}`)}
    ${part("anvil", `
      <rect x="508" y="28" width="432" height="384" rx="6" fill="none" stroke="${INK}" stroke-width="1.6" stroke-dasharray="7 5" />
      ${anvilIcon(526, 44, 0.8)}
      ${label(590, 66, "Anvil: blockchain lokal", { size: 18, kind: "title", anchor: "start", id: "anvil-title" })}
      ${label(590, 86, "berjalan di komputer Anda sendiri", { size: 12, color: MUTED, anchor: "start", id: "anvil-sub" })}`)}
    ${part("evm", `${box(540, 104, 370, 222, { title: "EVM", sub: "mesin yang menjalankan kontrak", fill: SHADE, titleTop: true })}`)}
    ${part("vault", `
      ${vault(660, 160, 0.95)}
      ${label(722, 305, "LegacyVault", { size: 15, kind: "title" })}`)}
    ${part("blocks", `
      ${blocks(560, 352, 6)}
      ${label(560, 400, "Rantai blok: catatan semua transaksi", { size: 12, color: MUTED, anchor: "start" })}`)}
    ${token("tok-msg", message())}
  `,
  steps: [
    {
      title: "Lima lapis, satu arah",
      text: "Saat Pak Icanov menekan tombol, perintahnya berjalan dari kiri ke kanan: tampilan di browser, penerjemah ethers.js, jalur pesan JSON-RPC, lalu blockchain Anvil tempat kontrak LegacyVault dijalankan.",
    },
    {
      title: "UI: jendela, bukan brankas",
      text: "Halaman yang Anda lihat hanya jendela untuk membaca dan memanggil kontrak. Halaman ini tidak menyimpan uang dan tidak menyimpan aturan. Jika halaman dihapus, kontrak dan isinya tetap ada.",
      focus: ["ui"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [190, 270] },
    },
    {
      title: "ethers.js: penerjemah",
      text: "Pustaka JavaScript yang mengubah klik menjadi pesan berformat Ethereum, dan mengubah jawaban blockchain kembali menjadi data yang bisa ditampilkan. Ia memakai ABI dari contract.json agar tahu nama fungsi dan error kontrak.",
      focus: ["ethers"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [342, 195] },
    },
    {
      title: "JSON-RPC: jalur pesan",
      text: "Bahasa standar untuk berbicara dengan node Ethereum, dikirim lewat HTTP ke alamat 127.0.0.1:8545. Contoh pesannya: eth_call untuk membaca, eth_sendTransaction untuk mengirim transaksi.",
      focus: ["rpc"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [459, 195] },
    },
    {
      title: "Anvil: blockchain di komputer sendiri",
      text: "Anvil adalah tiruan jaringan Ethereum yang berjalan lokal. Ia menyiapkan 10 akun berisi ETH palsu, membuat blok baru setiap ada transaksi, dan bisa memajukan waktu. Cocok untuk berlatih tanpa biaya.",
      focus: ["anvil", "blocks"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [526, 195] },
    },
    {
      title: "EVM: mesin penjalan kontrak",
      text: "Ethereum Virtual Machine menjalankan bytecode kontrak. Mesin yang sama dipakai di Anvil, Sepolia, dan Ethereum asli, sehingga kontrak yang lolos di sini berperilaku sama di sana.",
      focus: ["evm"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [600, 140] },
    },
    {
      title: "LegacyVault: brankas beraturan",
      text: "Kontrak inilah yang menyimpan ETH dan menegakkan aturan: siapa boleh apa, kapan, dan berapa bagiannya. Setiap perubahan dicatat di blok dan tidak bisa dihapus.",
      focus: ["vault", "blocks"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [722, 218] },
    },
    {
      title: "Di dunia nyata",
      text: "Susunannya tetap sama. Bedanya, Anvil diganti jaringan publik seperti Sepolia atau Ethereum, dan transaksi ditandatangani dompet milik setiap orang (misalnya MetaMask), bukan oleh Anvil.",
      texts: {
        "anvil-title": "Sepolia / Ethereum: jaringan publik",
        "anvil-sub": "ribuan komputer di seluruh dunia",
        "ui-sub": "ditandatangani dompet, misalnya MetaMask",
      },
    },
  ],
};

// ===========================================================================
// Bagian 2: Dari kode ke blockchain
// ===========================================================================

const codeToChain = {
  id: "kode-ke-blockchain",
  title: "Dari kode ke blockchain",
  intro: "Perjalanan file LegacyVault.sol sampai menjadi kontrak yang hidup di Anvil dan dikenali oleh UI.",
  scene: `
    ${part("code", `${documentIcon(24, 120, "LegacyVault.sol")}`)}
    ${part("compiler", `
      ${arrow(132, 190, 180, 190, M)}
      ${box(182, 140, 140, 100, { title: "forge build", sub: "compiler solc 0.8.28" })}`)}
    ${part("bytecode", `
      ${arrow(324, 170, 366, 120, M)}
      ${card(368, 78, 150, 82, "Bytecode", "kode mesin untuk EVM")}`, { optional: true })}
    ${part("abi", `
      ${arrow(324, 212, 366, 290, M)}
      ${card(368, 260, 150, 82, "ABI", "daftar fungsi untuk UI")}`, { optional: true })}
    ${part("script", `
      ${arrow(520, 119, 556, 119, M)}
      <rect x="558" y="40" width="160" height="160" rx="3" fill="#fbf9f4" stroke="${INK}" stroke-width="1.6" />
      ${label(638, 64, "npm run seed", { size: 15, kind: "mono" })}
      ${label(638, 84, "skrip deploy", { size: 12, color: MUTED })}
      ${character("icanov", 603, 96, 72, "face-icanov2")}
      ${label(638, 188, "dikirim oleh Pak Icanov", { size: 11, color: MUTED })}`)}
    ${part("chain", `
      ${arrow(720, 119, 752, 119, M)}
      <rect x="754" y="30" width="190" height="196" rx="5" fill="none" stroke="${INK}" stroke-width="1.6" stroke-dasharray="7 5" />
      ${anvilIcon(766, 42, 0.55)}
      ${label(808, 58, "Anvil", { size: 15, kind: "title", anchor: "start" })}
      ${vault(800, 80, 0.72)}`)}
    ${part("address", `${label(849, 204, "0x5FbD…0aa3", { size: 12, kind: "mono", color: ACCENT, weight: "700" })}`, { optional: true })}
    ${part("json", `
      ${arrow(520, 300, 556, 300, M)}
      ${arrow(836, 228, 722, 286, M, { dashed: true })}
      ${card(558, 260, 160, 82, "contract.json", "alamat + ABI")}`, { optional: true })}
    ${part("ui", `
      ${arrow(720, 300, 768, 318, M)}
      ${browserWindow(770, 262, 170, 150, "127.0.0.1:5173")}
      ${label(855, 340, "UI", { size: 18, kind: "title" })}
      ${label(855, 360, "siap memanggil kontrak", { size: 11, color: MUTED })}`)}
    ${token("tok-doc", `<rect x="-14" y="-17" width="28" height="34" rx="2" fill="#fff" stroke="${INK}" stroke-width="1.6" />
      <path d="M-8 -7 L8 -7 M-8 0 L8 0 M-8 7 L4 7" stroke="${ACCENT}" stroke-width="1.6" />`)}
  `,
  steps: [
    {
      title: "Kode Solidity",
      text: "Aturan warisan ditulis dalam bahasa Solidity di file LegacyVault.sol. File ini bisa dibaca manusia, tetapi belum bisa dijalankan oleh blockchain.",
      focus: ["code"],
      show: ["tok-doc"],
      tokens: { "tok-doc": [76, 188] },
    },
    {
      title: "Kompilasi dengan forge build",
      text: "Compiler Solidity versi 0.8.28 (dikunci di foundry.toml) menerjemahkan kode menjadi bentuk yang dimengerti mesin. Sebelum ini, 100 test dijalankan dengan forge test.",
      focus: ["compiler"],
      show: ["tok-doc"],
      tokens: { "tok-doc": [252, 190] },
    },
    {
      title: "Dua hasil: bytecode dan ABI",
      text: "Bytecode adalah kode mesin yang akan disimpan di blockchain. ABI adalah daftar fungsi, event, dan error, semacam buku menu agar program lain tahu cara memanggil kontrak.",
      focus: ["bytecode", "abi"],
      show: ["bytecode", "abi"],
    },
    {
      title: "Deploy: kontrak dipasang",
      text: "Skrip npm run seed mengirim transaksi khusus berisi bytecode atas nama Pak Icanov. Karena ia pengirimnya, ia otomatis menjadi pemilik vault.",
      focus: ["script", "bytecode"],
      show: ["bytecode", "abi", "tok-doc"],
      tokens: { "tok-doc": [638, 119] },
    },
    {
      title: "Kontrak hidup di blockchain",
      text: "Setelah transaksi masuk blok, kontrak punya alamat sendiri dan kodenya tidak bisa diubah lagi. Di Anvil yang baru dinyalakan, alamatnya selalu 0x5FbD…0aa3.",
      focus: ["chain", "address"],
      show: ["bytecode", "abi", "tok-doc", "address"],
      tokens: { "tok-doc": [850, 140] },
    },
    {
      title: "contract.json: alamat dan menu",
      text: "Skrip export-contract.mjs menggabungkan alamat kontrak dan ABI ke ui/src/contract.json. Tanpa file ini, UI tidak tahu kontrak mana yang harus dihubungi.",
      focus: ["json", "abi"],
      show: ["bytecode", "abi", "address", "json", "tok-doc"],
      tokens: { "tok-doc": [638, 300] },
    },
    {
      title: "UI siap dipakai",
      text: "UI membaca contract.json, lalu dengan bantuan ethers.js bisa memanggil fungsi kontrak dan menerjemahkan error-nya. Jika Anvil dinyalakan ulang, ulangi npm run seed.",
      focus: ["ui", "json"],
      show: ["bytecode", "abi", "address", "json", "tok-doc"],
      tokens: { "tok-doc": [855, 300] },
    },
  ],
};

// ===========================================================================
// Bagian 3: Perjalanan satu transaksi
// ===========================================================================

const transaction = {
  id: "transaksi",
  title: "Perjalanan satu transaksi",
  intro: "Apa yang terjadi saat Mas Kevin menekan Mulai klaim warisan: sekali ditolak, sekali berhasil.",
  scene: `
    ${part("kevin", `
      ${character("kevin", 24, 70, 124, "face-kevin")}
      ${label(86, 216, "Mas Kevin", { size: 16, kind: "title" })}`)}
    ${part("button", `
      <rect x="164" y="118" width="126" height="34" rx="2" fill="#fbf9f4" stroke="${INK}" stroke-width="1.8" />
      ${label(227, 140, "Mulai klaim", { size: 14 })}`)}
    ${part("sim", `
      ${arrow(292, 135, 316, 135, M)}
      ${box(318, 92, 150, 86, { title: "Simulasi", sub: "staticCall, tanpa blok" })}`)}
    ${part("wire", `
      ${arrow(470, 135, 512, 135, M)}
      ${label(491, 122, "kirim", { size: 11, color: MUTED, id: "wire-label" })}`)}
    ${part("anvil", `
      <rect x="514" y="28" width="428" height="384" rx="6" fill="none" stroke="${INK}" stroke-width="1.6" stroke-dasharray="7 5" />
      ${anvilIcon(530, 42, 0.7)}
      ${label(588, 62, "Anvil", { size: 18, kind: "title", anchor: "start" })}
      ${label(926, 62, "15 Nov 2026", { size: 13, kind: "mono", anchor: "end", id: "clock" })}
      ${label(926, 80, "waktu blockchain", { size: 11, anchor: "end", color: MUTED })}`)}
    ${part("vault", `
      ${vault(640, 104, 1)}
      ${label(705, 262, "LegacyVault", { size: 15, kind: "title" })}
      <rect x="652" y="272" width="106" height="26" rx="2" fill="none" stroke="${ACCENT}" stroke-width="2" />
      ${label(705, 290, "Active", { size: 14, color: ACCENT, weight: "700", id: "vault-state" })}`)}
    ${part("blocks", `${blocks(548, 340, 5)}`)}
    ${part("newblock", `${singleBlock(808, 340, 6)}`, { optional: true })}
    ${part("reject", `${bubble(16, 250, 286, 70, ["Ditolak: pemilik masih aktif", "sampai 14 Mei 2027."], { tone: "tolak" })}`, {
      optional: true,
    })}
    ${part("log", `
      <rect x="16" y="252" width="290" height="96" rx="2" fill="#fbf9f4" stroke="${INK}" stroke-width="1.6" />
      ${label(30, 276, "Buku catatan", { size: 14, kind: "title", anchor: "start" })}
      ${label(30, 300, "blok #6", { size: 11, kind: "mono", anchor: "start", color: MUTED })}
      ${label(30, 322, "Klaim #1 dimulai oleh Mas Kevin.", { size: 13, anchor: "start" })}`, { optional: true })}
    ${token("tok-msg", message())}
  `,
  steps: [
    {
      title: "Mas Kevin menekan tombol",
      text: "Tanggal blockchain 15 November 2026. Pak Icanov baru saja check-in, tetapi Mas Kevin tetap mencoba memulai klaim warisan.",
      focus: ["kevin", "button"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [227, 135] },
      faces: { "face-kevin": "netral" },
    },
    {
      title: "Simulasi dulu",
      text: "Sebelum benar-benar mengirim, UI menjalankan transaksi secara pura-pura (staticCall). Kontrak dijalankan, tetapi hasilnya tidak disimpan dan tidak ada blok baru.",
      focus: ["sim", "wire", "vault"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [705, 165] },
      texts: { "wire-label": "simulasi" },
    },
    {
      title: "Ditolak oleh kontrak",
      text: "Kontrak menolak dengan error OwnerStillActive. UI menerjemahkannya menjadi kalimat. Karena hanya simulasi, tidak ada blok baru dan tidak ada biaya gas.",
      focus: ["kevin", "reject"],
      show: ["reject", "tok-msg"],
      tokens: { "tok-msg": [176, 196] },
      faces: { "face-kevin": "cemas" },
      texts: { "wire-label": "simulasi" },
    },
    {
      title: "Waktu dimajukan 180 hari",
      text: "Pak Icanov tidak check-in lagi. Di Anvil, waktu bisa dimajukan dengan evm_increaseTime. Sekarang 14 Mei 2027, masa tidak aktif sudah lewat.",
      focus: ["anvil"],
      texts: { clock: "14 Mei 2027" },
      faces: { "face-kevin": "netral" },
    },
    {
      title: "Simulasi lolos",
      text: "Mas Kevin menekan tombol lagi. Kali ini simulasi tidak menemukan masalah, jadi UI boleh mengirim transaksi sungguhan.",
      focus: ["button", "sim", "vault"],
      show: ["tok-msg"],
      tokens: { "tok-msg": [393, 135] },
      texts: { clock: "14 Mei 2027", "wire-label": "simulasi" },
    },
    {
      title: "Transaksi dikirim, blok baru dibuat",
      text: "Pesan eth_sendTransaction dikirim ke Anvil atas nama Mas Kevin. Anvil memasukkannya ke blok baru, blok #6, dan Mas Kevin membayar sedikit biaya gas.",
      focus: ["wire", "anvil", "blocks", "newblock"],
      show: ["tok-msg", "newblock"],
      tokens: { "tok-msg": [825, 357] },
      texts: { clock: "14 Mei 2027", "wire-label": "kirim" },
    },
    {
      title: "Kontrak berubah tahap",
      text: "EVM menjalankan startClaim. Semua syarat diperiksa ulang di dalam kontrak, lalu tahap vault berubah dari Active menjadi Claiming.",
      focus: ["vault", "newblock"],
      show: ["newblock"],
      texts: { clock: "14 Mei 2027", "vault-state": "Claiming", "wire-label": "kirim" },
    },
    {
      title: "Event tercatat, UI membaca",
      text: "Kontrak memancarkan event ClaimStarted yang tersimpan permanen di blok. UI membaca event itu dan menuliskannya di buku catatan.",
      focus: ["kevin", "log", "newblock"],
      show: ["newblock", "log", "tok-msg"],
      tokens: { "tok-msg": [290, 270] },
      faces: { "face-kevin": "senang" },
      texts: { clock: "14 Mei 2027", "vault-state": "Claiming", "wire-label": "kirim" },
    },
  ],
};

// ===========================================================================
// Bagian 4: Perjalanan uang warisan
// ===========================================================================

const coins = `${coin(-16, 4)}${coin(16, 4)}${coin(0, -14)}`;

const money = {
  id: "uang-warisan",
  title: "Perjalanan uang warisan",
  intro: "Dari setoran Pak Icanov sampai Mas Kevin dan Mas Murni menarik bagiannya sendiri.",
  scene: `
    ${part("owner", `
      ${character("icanov", 30, 40, 112, "face-icanov")}
      ${label(86, 172, "Pak Icanov", { size: 16, kind: "title" })}
      ${label(86, 190, "pemilik", { size: 12, color: MUTED })}`)}
    ${part("silence", `${label(86, 214, "180 hari tanpa check-in", { size: 13, color: ACCENT, weight: "700" })}`, {
      optional: true,
    })}
    ${part("vault", `
      ${vault(300, 120, 1.25)}
      ${label(381, 306, "LegacyVault", { size: 16, kind: "title" })}
      ${label(381, 332, "0 ETH", { size: 20, kind: "mono", weight: "700", id: "balance" })}
      ${label(381, 354, "Active", { size: 13, color: ACCENT, weight: "700", id: "vault-state" })}`)}
    ${part("guardians", `
      ${character("barrok", 560, 18, 82, "face-barrok")}
      ${character("budi", 670, 18, 82, "face-budi")}
      ${character("wowo", 780, 18, 82, "face-wowo")}
      ${label(601, 116, "Mas Barrok", { size: 13 })}
      ${label(711, 116, "Notaris Budi", { size: 13 })}
      ${label(821, 116, "Pak RT Wowo", { size: 13 })}
      ${label(711, 136, "guardian, perlu 2 dari 3", { size: 12, color: MUTED })}`)}
    ${part("stamp-barrok", stampMark(601, 92, "SETUJU"), { optional: true })}
    ${part("stamp-budi", stampMark(711, 92, "SETUJU"), { optional: true })}
    ${part("timelock", `
      ${hourglass(546, 176)}
      ${label(612, 206, "Timelock 7 hari", { size: 14, anchor: "start", kind: "title" })}
      ${label(612, 226, "pemilik masih bisa membatalkan", { size: 12, anchor: "start", color: MUTED })}`, { optional: true })}
    ${part("heirs", `
      ${character("kevin", 600, 284, 100, "face-kevin")}
      ${character("murni", 790, 284, 100, "face-murni")}
      ${label(650, 400, "Mas Kevin, 60%", { size: 14 })}
      ${label(840, 400, "Mas Murni, 40%", { size: 14 })}`)}
    ${part("claim", `${stampMark(650, 270, "MULAI KLAIM", { rotate: -4 })}`, { optional: true })}
    ${token("tok-coins", coins)}
    ${token("tok-env-kevin", envelope("6 ETH"))}
    ${token("tok-env-murni", envelope("4 ETH"))}
  `,
  steps: [
    {
      title: "Pak Icanov menyetor 10 ETH",
      text: "Pemilik memasukkan ETH ke vault. Selama ia aktif, hanya ia yang bisa menarik dana. Setiap setoran dari pemilik juga dihitung sebagai check-in.",
      focus: ["owner", "vault"],
      show: ["tok-coins"],
      tokens: { "tok-coins": [381, 210] },
      texts: { balance: "10 ETH" },
      faces: { "face-icanov": "senang" },
    },
    {
      title: "Pemilik tidak memberi kabar",
      text: "Tidak ada check-in, setoran, atau penarikan selama 180 hari. Kontrak tidak tahu pemilik meninggal; kontrak hanya tahu pemilik diam terlalu lama.",
      focus: ["owner", "silence"],
      show: ["silence"],
      texts: { balance: "10 ETH" },
      faces: { "face-icanov": "netral" },
    },
    {
      title: "Mas Kevin memulai klaim",
      text: "Karena masa tidak aktif sudah lewat, ahli waris (atau guardian) boleh memulai klaim. Vault masuk tahap Claiming, tetapi uang belum bergerak sedikit pun.",
      focus: ["heirs", "claim", "vault"],
      show: ["silence", "claim"],
      texts: { balance: "10 ETH", "vault-state": "Claiming" },
    },
    {
      title: "Dua guardian menyetujui",
      text: "Mas Barrok dan Notaris Budi memeriksa keadaan, lalu menyetujui. Dua dari tiga sudah cukup. Persetujuan ini hanya berlaku untuk klaim yang sedang berjalan.",
      focus: ["guardians", "stamp-barrok", "stamp-budi"],
      show: ["silence", "claim", "stamp-barrok", "stamp-budi"],
      texts: { balance: "10 ETH", "vault-state": "Claiming" },
      faces: { "face-barrok": "senang", "face-budi": "senang" },
    },
    {
      title: "Masa tunggu 7 hari",
      text: "Setelah persetujuan cukup, kontrak menunggu 7 hari. Jika Pak Icanov ternyata masih hidup, ia bisa membatalkan klaim dan semuanya kembali seperti semula.",
      focus: ["timelock", "owner"],
      show: ["silence", "claim", "stamp-barrok", "stamp-budi", "timelock"],
      texts: { balance: "10 ETH", "vault-state": "Claiming" },
    },
    {
      title: "Finalisasi: saldo dibagi",
      text: "Siapa saja boleh menekan finalisasi. Kontrak memotret saldo (10 ETH) lalu mencatat bagian sesuai porsi: 6 ETH dan 4 ETH. Sisa pembulatan, jika ada, diberikan ke ahli waris terakhir.",
      focus: ["vault"],
      show: ["stamp-barrok", "stamp-budi", "timelock", "tok-env-kevin", "tok-env-murni"],
      tokens: { "tok-env-kevin": [340, 395], "tok-env-murni": [422, 395] },
      texts: { balance: "10 ETH", "vault-state": "Distributed" },
    },
    {
      title: "Setiap ahli waris menarik sendiri",
      text: "Kontrak tidak mengirim ke semua orang sekaligus. Mas Kevin dan Mas Murni masing-masing datang dan menarik bagiannya (pull payment). Saldo vault menjadi 0.",
      focus: ["heirs", "vault"],
      show: ["tok-env-kevin", "tok-env-murni"],
      tokens: { "tok-env-kevin": [548, 330], "tok-env-murni": [740, 330] },
      texts: { balance: "0 ETH", "vault-state": "Distributed" },
      faces: { "face-kevin": "senang", "face-murni": "senang" },
    },
    {
      title: "Kenapa ditarik sendiri?",
      text: "Jika satu dompet ahli waris menolak ETH, hanya penarikan orang itu yang gagal; bagian ahli waris lain tetap aman dan bisa diambil. Bagian yang gagal juga tidak hilang, tetap tercatat di kontrak.",
      focus: ["heirs"],
      show: ["tok-env-kevin", "tok-env-murni"],
      tokens: { "tok-env-kevin": [548, 330], "tok-env-murni": [740, 330] },
      texts: { balance: "0 ETH", "vault-state": "Distributed" },
      faces: { "face-kevin": "senang", "face-murni": "lega" },
    },
  ],
};

const SECTIONS = [architecture, codeToChain, transaction, money];

// ===========================================================================
// Mesin langkah
// ===========================================================================

const $ = (id) => document.getElementById(id);
let current = { section: 0, step: 0 };
let originalTexts = new Map();

function buildNav() {
  const nav = $("chapters");
  SECTIONS.forEach((section, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "chapter";
    button.dataset.index = String(index);
    button.innerHTML = `<span class="chapter-number">${index + 1}</span> ${section.title}`;
    button.addEventListener("click", () => openSection(index, 0));
    nav.append(button);
  });
}

function openSection(index, step) {
  const section = SECTIONS[index];
  current = { section: index, step };

  $("scene").innerHTML = `
    <svg viewBox="0 0 960 440" class="scene-svg" role="img" aria-labelledby="scene-title">
      <title id="scene-title">Adegan: ${section.title}</title>
      <defs>${arrowMarker(M)}</defs>
      <rect x="0" y="0" width="960" height="440" fill="none" />
      ${section.scene}
    </svg>`;

  // Simpan teks asli supaya langkah yang tidak mengganti teks memakai teks semula.
  originalTexts = new Map();
  for (const text of $("scene").querySelectorAll("text[id]")) originalTexts.set(text.id, text.textContent);

  for (const button of document.querySelectorAll(".chapter")) {
    const active = Number(button.dataset.index) === index;
    button.setAttribute("aria-current", active ? "step" : "false");
  }
  $("chapter-title").textContent = `${index + 1}. ${section.title}`;
  $("chapter-intro").textContent = section.intro;
  history.replaceState(null, "", `#${section.id}`);

  // Posisi awal benda yang berpindah: langsung, tanpa transisi.
  $("scene").classList.add("no-transition");
  applyStep();
  requestAnimationFrame(() => requestAnimationFrame(() => $("scene").classList.remove("no-transition")));
}

function applyStep() {
  const section = SECTIONS[current.section];
  const step = section.steps[current.step];
  const svg = $("scene").querySelector("svg");
  const focus = step.focus ?? [];
  const show = step.show ?? [];

  for (const element of svg.querySelectorAll("[data-part]")) {
    const name = element.dataset.part;
    const optional = element.hasAttribute("data-optional");
    element.classList.toggle("is-hidden", optional && !show.includes(name));
    const isToken = element.classList.contains("token");
    element.classList.toggle("is-dim", !isToken && focus.length > 0 && !focus.includes(name));
  }

  for (const [id, [x, y]] of Object.entries(step.tokens ?? {})) {
    const moving = svg.querySelector(`#${id}`);
    if (moving) moving.style.transform = `translate(${x}px, ${y}px)`;
  }

  for (const [id, original] of originalTexts) {
    const text = svg.querySelector(`#${id}`);
    text.textContent = step.texts?.[id] ?? original;
  }

  for (const slot of svg.querySelectorAll("[data-character]")) {
    const expression = step.faces?.[slot.id] ?? "netral";
    if (slot.dataset.expression !== expression) {
      slot.innerHTML = characterSvg(slot.dataset.character, {
        size: Number(slot.dataset.size),
        expression,
        decorative: true,
      });
      slot.dataset.expression = expression;
    }
  }

  $("step-counter").textContent = `Langkah ${current.step + 1} dari ${section.steps.length}`;
  $("step-title").textContent = step.title;
  $("step-text").textContent = step.text;
  $("prev").disabled = current.section === 0 && current.step === 0;
  const lastSection = current.section === SECTIONS.length - 1;
  const lastStep = current.step === section.steps.length - 1;
  $("next").disabled = lastSection && lastStep;
  $("next").textContent = lastStep && !lastSection ? "Bagian berikutnya" : "Berikutnya";
}

function next() {
  const section = SECTIONS[current.section];
  if (current.step < section.steps.length - 1) {
    current.step += 1;
    applyStep();
  } else if (current.section < SECTIONS.length - 1) {
    openSection(current.section + 1, 0);
  }
}

function previous() {
  if (current.step > 0) {
    current.step -= 1;
    applyStep();
  } else if (current.section > 0) {
    const previousSection = current.section - 1;
    openSection(previousSection, SECTIONS[previousSection].steps.length - 1);
  }
}

buildNav();
$("next").addEventListener("click", next);
$("prev").addEventListener("click", previous);

// Panah kanan/kiri berpindah langkah, kecuali saat fokus berada di kolom isian.
document.addEventListener("keydown", (event) => {
  if (event.target.closest("input, textarea, select")) return;
  if (event.key === "ArrowRight") next();
  if (event.key === "ArrowLeft") previous();
});

const sectionFromHash = () => Math.max(0, SECTIONS.findIndex((s) => `#${s.id}` === location.hash));
openSection(sectionFromHash(), 0);
// Tautan langsung ke bagian tertentu, misalnya penjelasan.html#transaksi.
window.addEventListener("hashchange", () => {
  const index = sectionFromHash();
  if (index !== current.section) openSection(index, 0);
});

// Ekspor untuk pemeriksaan otomatis (jumlah langkah per bagian).
export { SECTIONS };
