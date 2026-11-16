# LegacyVault

Brankas ETH yang dapat diwariskan, ditulis sebagai smart contract Solidity. Ini proyek tugas kuliah: jalan di blockchain lokal (Anvil) untuk demo, dan bisa di-deploy ke testnet Sepolia.

## Masalah

Aset kripto hanya bisa dipindahkan oleh pemegang private key. Jika pemiliknya meninggal dunia, keluarga umumnya tidak bisa mengakses aset itu. Tidak ada bank atau pihak pusat yang bisa "membukakan" akses.

## Solusi

LegacyVault adalah kontrak yang menyimpan ETH dengan tiga peran:

| Peran | Wewenang |
|---|---|
| Owner (pemilik) | Setor, tarik, check-in ("saya masih ada"), ubah ahli waris, batalkan klaim |
| Heir (ahli waris, 1–10 orang) | Memulai klaim, lalu menarik bagian masing-masing setelah klaim final |
| Guardian (pihak tepercaya, 1–10 orang) | Memulai klaim dan menyetujui klaim |

Selama pemilik aktif, hanya pemilik yang menguasai dana. Dana warisan baru bisa cair setelah tiga syarat terpenuhi:

1. Pemilik tidak check-in selama masa tidak aktif (contoh demo: 180 hari).
2. Sejumlah guardian menyetujui klaim (contoh demo: 2 dari 3).
3. Masa tunggu (timelock) terlewati (contoh demo: 7 hari). Selama masa ini pemilik masih bisa membatalkan klaim.

Setelah klaim final, saldo dibagi menurut porsi dalam basis point (10000 = 100%), dan setiap heir menarik bagiannya sendiri.

Kontrak ini hanya tahu bahwa pemilik **tidak aktif**, bukan bahwa pemilik meninggal, dan tidak menggantikan hukum waris. Lihat bagian [Keterbatasan dan pengembangan lanjutan](#keterbatasan-dan-pengembangan-lanjutan).

## Dokumen

| Dokumen | Isi |
|---|---|
| [SPEC.md](SPEC.md) | Spesifikasi desain: peran, fungsi, state machine, invariant, model ancaman |
| [docs/ARSITEKTUR.md](docs/ARSITEKTUR.md) | Diagram komponen, diagram state, flowchart klaim, tabel fungsi dan peran |
| [docs/KEAMANAN.md](docs/KEAMANAN.md) | Ancaman, mitigasi, dan test yang membuktikannya; pembahasan `block.timestamp`; risiko yang diterima |
| [docs/REVIEW.md](docs/REVIEW.md) | Review keamanan tahap 7: temuan, perbaikan, dan test regresi |
| [docs/HASIL-UJI.md](docs/HASIL-UJI.md) | Ringkasan hasil test, test keamanan, uji perusakan, dan laporan gas |
| [docs/DEPLOY.md](docs/DEPLOY.md) | Panduan deploy lengkap ke Anvil dan Sepolia |
| [docs/MUTATION.md](docs/MUTATION.md) | Uji perusakan: 23 mutasi pada kontrak dan test yang menangkapnya |
| [PENJELASAN.md](PENJELASAN.md) | Penjelasan per tahap dalam bahasa awam, beserta contoh pertanyaan dosen |

## Cara menjalankan

### Prasyarat

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `anvil`, `cast`). Proyek ini dikembangkan dengan Foundry 1.9.0.
- Node.js (untuk UI dan perintah `npm run`).
- Git, karena OpenZeppelin dipasang sebagai submodule.

Setelah clone:

```bash
git submodule update --init --recursive
```

```bash
npm run ui:install
```

### Build dan test

```bash
forge build
```

```bash
forge test
```

Hanya test keamanan:

```bash
forge test --match-path "test/security/*" -vv
```

Laporan gas:

```bash
forge test --gas-report
```

### Lokal (Anvil) dengan UI simulasi

Butuh tiga terminal. Di terminal pertama, nyalakan blockchain lokal dan biarkan tetap terbuka:

```bash
npm run anvil
```

Di terminal kedua, deploy vault demo (Pak Icanov sebagai owner, 10 ETH, dua heir, tiga guardian):

```bash
npm run seed
```

Di terminal ketiga, jalankan UI:

```bash
npm run ui
```

Buka http://127.0.0.1:5173. Halaman yang tersedia:

- `/`: simulasi. Pilih tokoh, jalankan aksi, majukan waktu, dan lihat buku catatan event.
- `/penjelasan.html`: cara kerja sistem dalam empat bagian beranimasi. Halaman ini tidak membutuhkan Anvil.
- `/karakter.html`: lembar pratinjau tokoh.

UI memakai akun Anvil yang sudah terbuka, jadi tidak perlu MetaMask dan tidak ada private key di kode UI. UI menolak bekerja jika chainId bukan 31337.

Untuk konfigurasi sendiri (alamat, porsi, periode), salin `.env.example` menjadi `.env`, ubah isinya, lalu jalankan `npm run deploy-local` sebagai ganti `npm run seed`. Setiap kali Anvil dimatikan, isi blockchain-nya hilang dan langkah deploy harus diulang.

### Sepolia (testnet publik)

Langkah lengkapnya ada di [docs/DEPLOY.md](docs/DEPLOY.md) bagian B. Ringkasnya:

1. Siapkan wallet **khusus testnet** dan dapatkan Sepolia ETH dari faucet.
2. Salin `.env.example` menjadi `.env`. Isi `SEPOLIA_RPC_URL`, `PRIVATE_KEY`, `ETHERSCAN_API_KEY`, serta alamat heir dan guardian sungguhan. Akun Anvil ditolak oleh skrip deploy (`AnvilAccountOnPublicChain`).
3. Simulasikan dulu, tanpa mengirim transaksi:

   ```bash
   forge script script/Deploy.s.sol --rpc-url sepolia
   ```

4. Deploy dan verifikasi di Etherscan:

   ```bash
   forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
   ```

Catatan:

- `.env` tidak boleh di-commit; file ini sudah ada di `.gitignore`.
- Deploy Sepolia belum pernah dijalankan di proyek ini.
- UI simulasi hanya untuk Anvil. Kontrak di Sepolia bisa dipakai lewat `cast send` atau tab *Write Contract* di Etherscan setelah kontrak diverifikasi.

## Struktur folder

```
legacyvault/
├── src/
│   └── LegacyVault.sol          Kontrak utama
├── test/
│   ├── LegacyVault.t.sol        Test fungsional: jalur berhasil dan gagal per fungsi (60 test)
│   ├── security/
│   │   └── LegacyVault.security.t.sol   Test per baris model ancaman dan temuan review (38 test)
│   ├── script/
│   │   └── Scripts.t.sol        Test skrip deploy dan seed (7 test)
│   └── utils/
│       └── LegacyVaultFixture.sol       Data bersama dan kontrak bantu yang menolak ETH
├── script/
│   ├── Deploy.s.sol             Deploy dari konfigurasi .env (Anvil atau Sepolia)
│   ├── SeedDemo.s.sol           Deploy data demo (hanya Anvil)
│   ├── AnvilAccounts.sol        Daftar akun bawaan Anvil, untuk penolakan di jaringan publik
│   └── export-contract.mjs      Menulis alamat dan ABI ke ui/src/contract.json
├── ui/
│   ├── index.html               Halaman simulasi
│   ├── penjelasan.html          Halaman cara kerja beranimasi
│   ├── karakter.html            Pratinjau tokoh
│   └── src/                     Logika UI (ethers v6), gambar tokoh SVG, gaya
├── docs/                        Dokumentasi dan output asli test
├── lib/                         forge-std dan OpenZeppelin (submodule)
├── SPEC.md                      Spesifikasi desain
├── PENJELASAN.md                Penjelasan bahasa awam per tahap
├── foundry.toml                 Konfigurasi Foundry (Solidity 0.8.28, fuzz 1000 run)
├── package.json                 Perintah bantu npm run
└── .env.example                 Contoh konfigurasi deploy
```

## Keterbatasan dan pengembangan lanjutan

Bagian ini menjelaskan hal yang sengaja tidak dibuat, dan bagaimana mengembangkannya jika proyek dilanjutkan. Semua butir di bawah berada di luar SPEC.md dan **belum** diimplementasikan.

### 1. Hanya ETH, belum token ERC-20

Vault hanya menyimpan ETH. Banyak aset kripto berbentuk token ERC-20 (misalnya stablecoin), dan token yang dikirim ke alamat vault tidak bisa dikeluarkan oleh kontrak ini.

Arah pengembangan:

- Catat daftar token yang diizinkan, dan simpan snapshot saldo per token saat `finalizeClaim`.
- Pakai `SafeERC20` dari OpenZeppelin untuk `transfer`. Sebagian token tidak mengembalikan `true`/`false` sesuai standar, dan sebagian lain mengembalikan `false` alih-alih revert. `SafeERC20` menyeragamkan perilaku itu sehingga kegagalan selalu terdeteksi, sama seperti `call` yang dicek di kontrak ini.
- Tetap pakai pull payment per token.
- Waspadai token yang memotong biaya saat transfer (*fee-on-transfer*) atau saldonya berubah sendiri (*rebasing*), karena snapshot bisa tidak sama dengan saldo sebenarnya.

### 2. Guardian tidak bisa diganti

Daftar guardian ditetapkan saat deploy dan tidak bisa diubah (SPEC.md bagian 7, risiko yang diterima). Jika guardian meninggal, berselisih, atau kehilangan kunci, satu-satunya jalan adalah pemilik menarik dana dan men-deploy vault baru.

Arah pengembangan: fungsi `updateGuardians` yang hanya bisa dipanggil owner saat `Active`, dengan validasi yang sama seperti constructor (tanpa duplikat, bukan heir, threshold tetap ≤ jumlah guardian). Penggantian ini juga sebaiknya dihitung sebagai check-in, sama seperti `updateHeirs`.

### 3. Guardian tidak responsif

Jika guardian yang aktif kurang dari `threshold`, klaim bisa tertahan selamanya di state `Claiming`. Dana tidak hilang, tetapi juga tidak bisa dibagikan. Skema m-of-n (misalnya 2 dari 3) hanya mengurangi risiko ini, tidak menghilangkannya.

Arah pengembangan yang mungkin, masing-masing dengan kelemahannya:

- **Batas waktu persetujuan:** jika klaim tidak mencapai threshold dalam waktu tertentu, klaim boleh dibatalkan oleh heir atau guardian lalu dimulai ulang. Ini mencegah klaim macet, tetapi tidak menambah suara.
- **Jalur cadangan tanpa guardian:** setelah masa tidak aktif yang jauh lebih panjang (misalnya 3 tahun), klaim boleh final tanpa persetujuan. Ini menurunkan keamanan bagi pemilik yang lama tidak aktif tetapi masih hidup.
- **Guardian cadangan:** daftar guardian kedua yang baru berwenang setelah jangka waktu tertentu.

Pilihan mana yang tepat adalah keputusan desain, dan harus ditulis ke SPEC.md dulu sebelum dibuat.

### 4. Bukan surat wasiat secara hukum

Kontrak ini mengatur **pemindahan teknis** ETH, bukan **hak hukum** atas harta. Perbedaannya:

| | Surat wasiat / pembagian waris secara hukum | LegacyVault |
|---|---|---|
| Dasar | Hukum waris yang berlaku (perdata, Islam, atau adat) dan putusan atau penetapan pengadilan atau notaris | Kode program |
| Pemicu | Kematian yang dibuktikan dengan dokumen resmi | Pemilik tidak check-in dalam jangka waktu tertentu |
| Pembagian | Mengikuti aturan hukum, termasuk bagian yang dilindungi undang-undang | Mengikuti porsi yang ditulis pemilik, tanpa memeriksa aturan hukum apa pun |
| Sengketa | Bisa digugat dan diputus pengadilan | Transaksi final tidak bisa dibatalkan oleh pengadilan; pengadilan hanya bisa memerintahkan orangnya |
| Kerahasiaan | Isi wasiat bisa dirahasiakan sampai dibuka | Alamat dan porsi terlihat publik di blockchain |

Akibatnya, pembagian dari kontrak bisa berbeda dari pembagian yang sah menurut hukum. Kontrak ini sebaiknya dipakai **bersama** wasiat yang sah, misalnya wasiat yang menyebut keberadaan vault dan menyatakan pembagiannya sejalan. Kontrak ini bukan pengganti wasiat.
