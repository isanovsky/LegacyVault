# Penjelasan Proyek LegacyVault

Dokumen ini ditulis untuk pemilik proyek yang baru mengenal Web3. Setiap tahap pengerjaan menambah satu bagian baru di sini.

---

## Tahap 0: Persiapan proyek

### 1. Apa yang dibuat di tahap ini

Belum ada smart contract yang ditulis. Tahap ini hanya menyiapkan alat kerja:

- **Foundry** dipasang di komputer (versi 1.9.0). Isinya `forge`, `anvil`, `cast`, dan `chisel`.
- Folder ini dijadikan proyek Foundry. Strukturnya:
  - `src/`: tempat kode smart contract (`.sol`) nanti.
  - `test/`: tempat kode pengujian.
  - `script/`: tempat skrip deploy.
  - `lib/`: pustaka dari pihak lain. Isinya `forge-std` (alat bantu test bawaan Foundry) dan `openzeppelin-contracts` versi 5.7.0.
  - `foundry.toml`: file pengaturan proyek.
- Versi compiler Solidity dikunci ke **0.8.28** di `foundry.toml`.
- Proyek dijadikan repositori Git, dan `.gitignore` disiapkan supaya file rahasia (`.env`) dan file hasil build tidak ikut tersimpan.
- File contoh `Counter` bawaan Foundry dihapus karena tidak dipakai.

### 2. Konsep yang dipakai

**Smart contract.** Program kecil yang disimpan dan dijalankan di blockchain. Begitu dipasang, kodenya tidak bisa diubah diam-diam, dan siapa pun bisa melihat apa yang dikerjakannya. Analoginya mesin penjual otomatis: aturannya sudah tertanam di mesin, tidak perlu penjaga toko.

**Solidity.** Bahasa pemrograman untuk menulis smart contract di Ethereum. Kode Solidity harus di-*compile* (diterjemahkan) dulu menjadi *bytecode* yang dimengerti blockchain.

**Foundry.** Satu paket alat untuk membuat, menguji, dan memasang smart contract. Analoginya kotak perkakas tukang: satu kotak berisi beberapa alat dengan fungsi berbeda.

- **forge**: alat utama. `forge build` meng-compile kode Solidity, `forge test` menjalankan pengujian. Test di Foundry juga ditulis dalam Solidity, jadi tidak perlu belajar bahasa kedua.
- **anvil**: blockchain Ethereum tiruan yang berjalan di komputer sendiri. Saat dinyalakan, anvil langsung menyediakan 10 akun yang masing-masing berisi 10.000 ETH palsu.
- **cast**: alat baris perintah untuk "mengobrol" dengan blockchain, misalnya mengecek saldo atau memanggil fungsi kontrak tanpa membuat UI.
- **chisel**: tempat mencoba potongan kode Solidity secara cepat. Jarang dipakai di proyek ini.

**OpenZeppelin Contracts.** Kumpulan kode smart contract yang sudah diaudit dan dipakai luas. Proyek ini hanya mengambil satu bagian, `ReentrancyGuard`, yaitu pengaman terhadap serangan *reentrancy*. Serangan itu akan dijelaskan di tahap berikutnya. Analoginya membeli kunci pintu bersertifikat daripada membuat kunci sendiri.

**Mengunci versi compiler.** Versi Solidity yang berbeda bisa menghasilkan bytecode yang sedikit berbeda, dan kadang ada perbaikan bug di antara versi. Dengan mengunci ke 0.8.28, siapa pun yang menjalankan `forge build` (dosen, teman, atau server) mendapat hasil yang sama.

**Kenapa menguji di blockchain lokal dulu?**

1. **Gratis.** Setiap transaksi di jaringan Ethereum asli membayar biaya (*gas*) dengan ETH sungguhan. Di anvil, ETH-nya palsu.
2. **Cepat.** Di jaringan asli, transaksi menunggu belasan detik untuk masuk blok. Di anvil, langsung.
3. **Bisa memutar waktu.** Kontrak ini bergantung pada waktu ("pemilik tidak aktif selama periode tertentu", misalnya 180 hari). Di jaringan asli kita harus benar-benar menunggu. Di Foundry, `vm.warp` bisa melompatkan waktu dalam sekejap.
4. **Kesalahan tidak permanen.** Kontrak yang sudah terpasang di jaringan asli tidak bisa diperbaiki. Jika ada bug yang membuat ETH terkunci, ETH itu hilang selamanya. Di lokal, cukup matikan anvil dan mulai lagi.

Analoginya simulator mengemudi: berlatih menabrak di simulator jauh lebih murah daripada di jalan raya.

### 3. Pertanyaan yang mungkin diajukan dosen

**T: Kenapa memakai Foundry, bukan Hardhat atau Remix?**
J: Remix berjalan di browser dan cocok untuk mencoba, tetapi kurang cocok untuk proyek dengan banyak test. Hardhat menulis test dalam JavaScript, sedangkan Foundry menulis test dalam Solidity, bahasa yang sama dengan kontraknya. Foundry juga menyediakan fuzz testing (menguji dengan ribuan input acak) secara bawaan, dan itu dipakai untuk memeriksa perhitungan pembagian warisan.

**T: Apa bedanya anvil dengan testnet seperti Sepolia?**
J: Anvil hanya berjalan di komputer sendiri dan hilang saat dimatikan. Sepolia adalah jaringan publik yang mirip Ethereum asli, tetapi ETH-nya tidak bernilai. Anvil dipakai untuk pengembangan dan pengujian sehari-hari karena cepat dan bisa dikendalikan penuh, termasuk waktunya.

**T: Kenapa hanya memakai `ReentrancyGuard` dari OpenZeppelin, tidak lebih?**
J: Supaya kode tetap sederhana dan bisa dipahami sendiri. Bagian lain, seperti aturan peran pemilik, ahli waris, dan guardian, ditulis langsung karena kebutuhannya spesifik dan lebih mudah dijelaskan. `ReentrancyGuard` diambil karena ini pengaman keamanan yang sudah teruji, dan membuatnya sendiri justru berisiko.

**T: Kenapa file `.env` tidak di-commit?**
J: File `.env` biasanya berisi private key. Siapa pun yang memegang private key bisa memindahkan seluruh isi akun tersebut. Jika file itu masuk Git dan diunggah ke GitHub, kunci itu bisa dibaca orang lain.

**T: Kenapa versi Solidity 0.8.x?**
J: Mulai versi 0.8.0, Solidity otomatis menolak operasi aritmetika yang meluap (*overflow*), misalnya angka yang melewati batas maksimum lalu berputar menjadi kecil. Di versi lama, ini sumber banyak bug dan pencurian dana. 0.8.28 dipilih karena stabil dan didukung OpenZeppelin 5.7.0 (yang membutuhkan minimal 0.8.20).
