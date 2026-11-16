# Aturan Proyek LegacyVault

Proyek tugas kuliah: smart contract warisan ETH. Pemilik proyek masih awam Web3, jadi kejelasan lebih penting daripada kecerdikan. Desain lengkap ada di `SPEC.md`; baca sebelum mengerjakan apa pun.

## Stack
- Solidity 0.8.x (pin satu versi di `foundry.toml`), Foundry (forge, anvil, cast).
- OpenZeppelin Contracts hanya untuk `ReentrancyGuard`.
- UI: Vite + JavaScript biasa (tanpa framework) + ethers v6.

## Aturan kode Solidity
- Kode harus bisa dibaca mahasiswa yang baru belajar Solidity. Dilarang: inline assembly, trik optimasi gas yang mengorbankan keterbacaan, pewarisan berlapis, proxy/upgradeable pattern.
- Satu fungsi satu tugas. Pemeriksaan state dan peran memakai modifier yang namanya jelas (`onlyOwner`, `onlyGuardian`, `inState(State.Active)`).
- Gunakan custom error dengan nama deskriptif (`NotGuardian()`, `OwnerStillActive(uint256 activeUntil)`), bukan string panjang.
- Semua fungsi dan state variable memiliki visibilitas eksplisit.
- Selalu urutan Checks-Effects-Interactions. Pengiriman ETH memakai `call` dan hasilnya dicek.
- Komentar NatSpec dan komentar kode dalam Bahasa Indonesia, menjelaskan **kenapa**, bukan mengulang apa yang sudah jelas dari kode.
- Nama identifier dalam bahasa Inggris.
- Jangan menambah fitur di luar `SPEC.md`. Jika menurutmu spesifikasi salah atau kurang, berhenti dan jelaskan, jangan diam-diam mengubah desain.

## Aturan pengujian
- Setiap fungsi publik punya test jalur berhasil dan test jalur gagal (revert dengan error yang tepat).
- Gunakan `vm.warp` untuk waktu, `vm.prank` untuk peran.
- Nama test menjelaskan skenario, contoh `test_RevertWhen_NonGuardianApproves`.
- Jangan pernah menulis hasil test, angka gas, atau coverage yang tidak benar-benar dijalankan. Salin output asli dari terminal.
- Sebelum menyatakan suatu tahap selesai: `forge build` tanpa warning dan `forge test` hijau.

## Aturan UI
- Ikuti panduan desain di `PROMPTS.md` tahap 5. Hindari tampilan template AI: tanpa gradien ungu-biru, tanpa glassmorphism, tanpa emoji, tanpa kalimat promosi.
- Teks antarmuka dalam Bahasa Indonesia yang lugas.
- Karakter tokoh (keputusan pemilik proyek, setelah tahap 5): enam tokoh demo dan benda pendukung (brankas, koin, blok, Anvil) digambar sebagai ilustrasi SVG buatan sendiri bergaya "tinta notaris": garis tinta gelap, sedikit warna lembut yang serasi dengan latar kertas, tanpa gradien. Karakter dipakai untuk mewakili peran dan keadaan (ekspresi berubah sesuai kejadian), bukan hiasan. Tetap tanpa emoji dan tanpa paket ikon luar. Nada tetap sopan karena topiknya warisan. Sumber gambar ada di `ui/src/characters.js`.
- Private key akun default Anvil hanya boleh dipakai untuk jaringan lokal (chainId 31337). UI harus menolak memakai fitur itu di jaringan lain.

## Git
- Commit setelah setiap tahap selesai dan test hijau, dengan pesan yang menjelaskan tahap tersebut.
- `.env`, `node_modules`, `out`, `cache`, `broadcast` masuk `.gitignore`. Jangan pernah commit private key.

## Penjelasan untuk pemilik proyek
Di akhir setiap tahap, tambahkan bagian baru di `PENJELASAN.md` dengan bahasa awam:
1. Apa yang dibuat di tahap ini.
2. Konsep Web3 yang dipakai, dijelaskan dengan analogi sederhana.
3. Pertanyaan yang kemungkinan diajukan dosen dan jawabannya.
