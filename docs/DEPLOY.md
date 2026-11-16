# Panduan Deploy LegacyVault

Ada dua tempat deploy:

| | Anvil (lokal) | Sepolia (testnet publik) |
|---|---|---|
| Untuk | Pengembangan, demo di kelas, UI | Menunjukkan kontrak berjalan di jaringan publik |
| Biaya | Gratis, ETH palsu | Gratis, tetapi butuh Sepolia ETH dari faucet |
| Private key | Tidak perlu (akun Anvil dibuka dari command line) | Wajib, dari wallet khusus testnet |
| Waktu | Bisa dimajukan (`evm_increaseTime`) | Berjalan normal, tidak bisa dimajukan |

Semua perintah di bawah dijalankan dari folder proyek. Di Windows, gunakan terminal baru (PowerShell, Command Prompt, atau Git Bash) setelah Foundry terpasang, supaya `forge` dikenali.

---

## A. Deploy lokal di Anvil

### 1. Nyalakan Anvil

Jalankan di terminal tersendiri, dan biarkan terminal itu tetap terbuka:

```bash
npm run anvil
```

Anvil mencetak 10 akun beserta private key-nya. Itu normal: kunci-kunci itu memang publik dan sama di semua komputer. Jangan pernah mengirim ETH sungguhan ke alamat-alamat ini.

Setiap kali Anvil dimatikan, seluruh isi blockchain-nya hilang. Setelah Anvil dinyalakan lagi, jalankan ulang langkah 2.

### 2a. Data demo (cara paling cepat)

Di terminal lain:

```bash
npm run seed
```

Perintah ini men-deploy vault dengan tokoh demo, lalu menyetor 10 ETH:

| Akun Anvil | Tokoh | Peran |
|---|---|---|
| 0 | Pak Icanov | Owner |
| 1 | Mas Kevin | Heir 60% |
| 2 | Mas Murni | Heir 40% |
| 3 | Mas Barrok | Guardian |
| 4 | Notaris Budi | Guardian |
| 5 | Pak RT Wowo | Guardian |

Konfigurasinya: threshold 2, masa tidak aktif 180 hari, timelock 7 hari.

`script/SeedDemo.s.sol` menolak berjalan jika chainId bukan 31337.

### 2b. Deploy dengan konfigurasi sendiri

```bash
cp .env.example .env
```

`cp` bisa dipakai di PowerShell dan Git Bash. Di Command Prompt, gunakan `copy .env.example .env`.

Ubah nilai di `.env` sesuai kebutuhan. Isi bawaannya sudah memakai akun Anvil 1–5. Lalu jalankan:

```bash
npm run deploy-local
```

### 3. Alamat dan ABI untuk UI

Kedua perintah di atas otomatis menulis `ui/src/contract.json`, yang berisi chainId, alamat kontrak, nomor blok deploy, dan ABI. File ini dibuat oleh `script/export-contract.mjs` dari catatan `broadcast/` dan hasil kompilasi di `out/`.

Pada Anvil yang baru dinyalakan, `npm run seed` selalu menghasilkan alamat `0x5FbDB2315678afecb367f032d93F642f64180aa3`, karena alamat kontrak dihitung dari alamat pengirim dan nomor transaksinya.

### 4. Memajukan waktu (khusus Anvil)

Untuk mencoba alur klaim tanpa menunggu 180 hari sungguhan:

```bash
cast rpc evm_increaseTime 15552000 --rpc-url http://127.0.0.1:8545
```

```bash
cast rpc evm_mine --rpc-url http://127.0.0.1:8545
```

Perintah pertama menambah 180 hari ke jam blockchain. Perintah kedua membuat blok baru supaya waktu barunya berlaku.

Contoh Mas Kevin memulai klaim. Akun Anvil sudah terbuka, jadi tidak perlu private key:

```bash
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "startClaim()" --unlocked --from 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url http://127.0.0.1:8545
```

---

## B. Deploy ke Sepolia

> Deploy Sepolia dijalankan sendiri oleh pemilik proyek. Langkah-langkah di bawah belum pernah dijalankan.

### 1. Siapkan wallet khusus testnet

Buat akun **baru** di MetaMask (atau wallet lain) yang hanya dipakai untuk testnet. Jangan memakai wallet yang menyimpan aset sungguhan. Private key wallet ini akan disimpan di file `.env` di komputer, dan file teks biasa tidak seaman wallet.

Cara mengambil private key di MetaMask: menu akun, lalu *Account details*, lalu *Show private key*. Kuncinya diawali `0x`.

### 2. Dapatkan Sepolia ETH dari faucet

*Faucet* adalah situs yang membagikan ETH testnet secara gratis. Beberapa pilihan:

- Google Cloud Web3 Faucet (Ethereum Sepolia)
- Alchemy Sepolia Faucet
- Sepolia PoW Faucet (menambang di browser beberapa menit)

Syarat tiap faucet bisa berubah. Ada yang meminta login, dan ada yang meminta wallet memiliki sedikit saldo di mainnet. Untuk deploy kontrak ini, 0,05 Sepolia ETH sudah lebih dari cukup: biaya deploy sekitar 3 juta gas, yang pada harga gas testnet umumnya jauh di bawah 0,05 ETH.

### 3. Dapatkan RPC URL dan API key Etherscan

- **RPC URL:** alamat server yang meneruskan transaksi ke jaringan Sepolia. Buat akun gratis di penyedia seperti Alchemy atau Infura, buat aplikasi untuk jaringan Sepolia, lalu salin URL HTTPS-nya.
- **API key Etherscan:** dipakai untuk verifikasi kontrak. Buat akun gratis di etherscan.io, lalu buka menu *API Keys*.

### 4. Isi `.env`

```bash
cp .env.example .env
```

Isi bagian berikut:

```
HEIRS=0xAlamatHeir1,0xAlamatHeir2
SHARES_BPS=6000,4000
GUARDIANS=0xAlamatGuardian1,0xAlamatGuardian2,0xAlamatGuardian3
THRESHOLD=2
INACTIVITY_PERIOD=15552000
TIMELOCK_PERIOD=604800
INITIAL_DEPOSIT_WEI=0

SEPOLIA_RPC_URL=https://...
PRIVATE_KEY=0x...
ETHERSCAN_API_KEY=...
```

Hal yang perlu diperhatikan:

- **Ganti semua alamat bawaan Anvil.** `script/Deploy.s.sol` akan berhenti dengan error `AnvilAccountOnPublicChain` jika owner, heir, atau guardian masih memakai akun Anvil. Private key akun Anvil diketahui semua orang, sehingga siapa pun bisa berperan sebagai heir atau guardian.
- **Akun dari `PRIVATE_KEY` menjadi owner vault.**
- **Jangan commit `.env`.** File ini sudah ada di `.gitignore`. Periksa dengan `git status` bahwa `.env` tidak muncul.
- **`INACTIVITY_PERIOD` dan `TIMELOCK_PERIOD` minimal 86400 (1 hari) dan maksimal 315360000 (3650 hari).** Di Sepolia waktu tidak bisa dimajukan, jadi untuk demo klaim di testnet pakai nilai kecil, misalnya 86400. Artinya Anda harus menunggu satu hari sungguhan untuk setiap periode.

### 5. Simulasi dulu (tanpa mengirim transaksi)

```bash
forge script script/Deploy.s.sol --rpc-url sepolia
```

Tanpa `--broadcast`, forge hanya menjalankan simulasi terhadap keadaan Sepolia. Tidak ada transaksi yang dikirim dan tidak ada ETH yang terpakai. Periksa alamat owner, perkiraan gas, dan pastikan tidak ada error.

`--rpc-url sepolia` merujuk ke `[rpc_endpoints]` di `foundry.toml`, yang mengambil nilai `SEPOLIA_RPC_URL` dari `.env`.

### 6. Deploy dan verifikasi

```bash
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
```

- `--broadcast` mengirim transaksi sungguhan ke Sepolia.
- `--verify` mengunggah kode sumber ke Etherscan, memakai `ETHERSCAN_API_KEY` dari `[etherscan]` di `foundry.toml`.

Setelah selesai, alamat kontrak tercetak di terminal dan tercatat di `broadcast/Deploy.s.sol/11155111/run-latest.json`. Buka `https://sepolia.etherscan.io/address/<alamat>`. Jika verifikasi berhasil, tab *Contract* menampilkan kode Solidity dengan tanda centang hijau.

### 7. Jika verifikasi gagal atau terlewat

Verifikasi bisa diulang tanpa deploy ulang:

```bash
forge verify-contract <ALAMAT_KONTRAK> src/LegacyVault.sol:LegacyVault --chain sepolia --guess-constructor-args --watch
```

`--guess-constructor-args` membaca argumen constructor dari transaksi deploy di jaringan, jadi Anda tidak perlu menyusunnya sendiri.

### 8. Setelah deploy

`ui/src/contract.json` **tidak** diperbarui otomatis untuk Sepolia. `script/export-contract.mjs` sengaja hanya membaca hasil deploy Anvil, supaya alamat lokal tidak tertimpa diam-diam oleh alamat testnet, dan sebaliknya. Cara UI terhubung ke Sepolia dibahas di tahap UI.

---

## Ringkasan perintah

| Perintah | Fungsi |
|---|---|
| `npm run anvil` | Menyalakan blockchain lokal (chainId 31337) |
| `npm run seed` | Deploy vault demo dan setor 10 ETH, lalu tulis `ui/src/contract.json` |
| `npm run deploy-local` | Deploy vault dari konfigurasi `.env` ke Anvil, lalu tulis `ui/src/contract.json` |
| `forge script script/Deploy.s.sol --rpc-url sepolia` | Simulasi deploy Sepolia |
| `forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify` | Deploy dan verifikasi di Sepolia |
