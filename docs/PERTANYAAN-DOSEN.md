# 15 Pertanyaan Sulit dan Jawabannya

Jawaban di bawah sengaja singkat dan jujur, termasuk tentang kelemahan proyek. Kalau dosen menggali lebih dalam, rujukan dokumennya ada di akhir tiap jawaban.

Saran umum: jika tidak tahu jawabannya, katakan "itu belum kami uji" atau "itu di luar cakupan", lalu sebut batasannya. Lebih baik jujur daripada menebak.

---

## A. Pertanyaan tentang konsep

### 1. Kenapa tidak memakai database biasa saja?

Karena asetnya sendiri ada di blockchain. Database hanya bisa **mencatat** siapa berhak atas ETH, tetapi tidak bisa **memindahkan** ETH. Untuk memindahkannya, tetap harus ada orang yang memegang private key pemilik, dan orang itu harus dipercaya penuh.

Dengan smart contract, ETH-nya disimpan oleh program itu sendiri. Aturannya terbuka dan tidak bisa diubah diam-diam oleh admin mana pun, termasuk kami.

Jujurnya, blockchain juga punya harga:
- setiap transaksi butuh biaya gas;
- data terlihat publik;
- kesalahan tidak bisa dibatalkan.

Untuk harta biasa seperti rumah atau rekening bank, database atau notaris jauh lebih cocok.

### 2. Bagaimana kontrak tahu pemiliknya sudah meninggal?

**Tidak tahu.** Kontrak hanya tahu bahwa pemilik **tidak memberi kabar** (tidak check-in) selama 180 hari.

Blockchain tidak bisa membaca akta kematian atau data kependudukan. Karena itu ada dua pengaman tambahan:
- persetujuan 2 dari 3 guardian, yaitu manusia yang bisa memastikan keadaan di dunia nyata;
- masa tunggu 7 hari, di mana pemilik yang ternyata masih hidup bisa membatalkan klaim.

Batasan ini tertulis di SPEC.md bagian 1.

### 3. Apa bedanya dengan surat wasiat?

| | Surat wasiat | LegacyVault |
|---|---|---|
| Dasar | Hukum waris yang berlaku | Kode program |
| Pemicu | Kematian yang dibuktikan dokumen resmi | Pemilik tidak check-in dalam jangka waktu tertentu |
| Pembagian | Mengikuti aturan hukum | Mengikuti porsi yang ditulis pemilik, tanpa diperiksa terhadap hukum |
| Sengketa | Bisa digugat di pengadilan | Transaksi yang sudah final tidak bisa dibatalkan |

Kontrak ini mengatur **pemindahan teknis**, bukan **hak hukum**. Kontrak ini sebaiknya dipakai **bersama** wasiat yang sah, bukan sebagai penggantinya. Rinciannya ada di README bagian Keterbatasan.

### 4. Kenapa hanya ETH? Bagaimana dengan token, NFT, atau uang di exchange?

Itu batasan cakupan yang disengaja (SPEC.md bagian 1):
- **Uang di exchange terpusat** (misalnya Indodax atau Binance) tidak dipegang oleh pemiliknya sendiri, jadi kontrak mana pun tidak bisa menyentuhnya.
- **Token ERC-20** bisa ditambahkan dengan pustaka `SafeERC20`, tetapi belum dibuat. Arah pengembangannya ditulis di README.

---

## B. Pertanyaan tentang keamanan

### 5. Bagaimana jika guardian berkolusi dengan ahli waris?

Ini **risiko yang kami terima**, dan tertulis di SPEC.md bagian 7. Kalau cukup banyak guardian bersekongkol, mereka bisa menyetujui klaim palsu.

Yang mengurangi risikonya:
- Klaim baru bisa dimulai setelah pemilik tidak check-in selama 180 hari. Guardian tidak bisa memulainya lebih awal; ini dibuktikan oleh `test_RevertWhen_StartClaimBeforeInactivityEnds`.
- Butuh 2 dari 3 guardian, bukan satu.
- Guardian tidak boleh sekaligus menjadi ahli waris, sehingga penyetuju tidak bisa menyetujui untuk dirinya sendiri (`test_RevertWhen_GuardianIsAlsoHeir`).
- Selama masa tunggu 7 hari, pemilik yang masih hidup bisa membatalkan (`test_CancelClaim_DuringTimelockBlocksFinalize`).

Yang **tidak** bisa dicegah: jika pemilik benar-benar sudah tiada dan guardian bersekongkol dengan sebagian ahli waris. Namun pembagiannya tetap mengikuti porsi yang ditulis pemilik. Guardian tidak bisa mengubah siapa yang menerima atau berapa bagiannya.

### 6. Kenapa `block.timestamp` aman di sini, padahal di slide disebut rentan?

`block.timestamp` memang bisa digeser sedikit oleh pembuat blok. Sejak Ethereum memakai proof of stake, geserannya hanya dalam hitungan slot 12 detik.

Ini berbahaya kalau **hasilnya bergantung pada detik tertentu**, misalnya undian acak, lelang yang ditutup pada detik tertentu, atau permainan untung-untungan.

Di LegacyVault, periode terpendek yang diizinkan adalah 1 hari, dan demo memakai 180 hari dan 7 hari. Geser 12 detik dari 1 hari hanya sekitar 0,014%, dan tidak ada yang bisa dimenangkan dari selisih itu.

Yang dibuktikan test hanyalah batas minimal 1 hari (`test_RevertWhen_InactivityPeriodBelowOneDay`). Alasan bahwa batas itu cukup adalah **analisis**, bukan hasil test. Pembahasannya ada di KEAMANAN.md bagian 2.

### 7. Apakah kontrak ini sudah aman? Sudah diaudit?

Belum diaudit oleh pihak independen. Yang sudah kami lakukan:
- 105 test otomatis, semuanya lolos, termasuk 38 test yang khusus mencoba cara-cara curang;
- 23 uji perusakan untuk membuktikan test-nya benar-benar menjaga kode. Hasilnya: 20 tertangkap test keamanan, 1 tertangkap test biasa, dan **2 tidak tertangkap**;
- review keamanan internal. Review itu menemukan satu masalah (periode raksasa yang bisa membuat dana terkunci), yang sudah diperbaiki.

Alat analisis otomatis Slither **belum dijalankan** karena tidak terpasang.

Jadi jawaban jujurnya: aman untuk ancaman yang kami daftar dan uji, tetapi belum siap untuk uang sungguhan.

### 8. Apa itu reentrancy, dan kenapa dua uji perusakan tidak tertangkap?

Reentrancy adalah serangan "menarik lagi sebelum transaksi pertama selesai", mirip menarik uang di ATM yang belum sempat mengurangi saldo. Kontrak ini punya dua pengaman:
- saldo bagian di-nol-kan **sebelum** ETH dikirim (pola Checks-Effects-Interactions);
- kunci `nonReentrant` dari OpenZeppelin.

Mutasi M02 membalik urutan pertama, dan M03 menghapus kunci kedua. Keduanya tidak tertangkap, karena test kami tidak memuat kontrak penyerang yang benar-benar menarik ulang. Kedua pengaman ini saling menutupi, tetapi kerusakan pada keduanya sekaligus tidak akan ketahuan dari test. Hal ini kami tulis terus terang di MUTATION.md.

### 9. Kenapa ahli waris harus menarik sendiri? Kenapa tidak dikirim otomatis?

Kalau dikirim otomatis dalam satu transaksi, satu ahli waris yang alamatnya menolak ETH akan menggagalkan pengiriman untuk **semua** ahli waris. Itu celah DoS (denial of service).

Dengan cara "tarik sendiri" (pull payment), masalah satu orang hanya berdampak pada dirinya sendiri. Ini dibuktikan oleh `test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected`.

---

## C. Pertanyaan tentang kasus tepi

### 10. Bagaimana jika guardian tidak responsif, meninggal, atau kehilangan kuncinya?

Jika guardian yang aktif kurang dari 2, klaim akan **tertahan selamanya** di tahap Claiming. Dananya tidak hilang, tetapi juga tidak bisa dibagikan.

Ini risiko yang diterima di SPEC.md, dan guardian tidak bisa diganti setelah deploy. Arah pengembangannya ditulis di README:
- fungsi untuk mengganti guardian;
- batas waktu persetujuan;
- jalur cadangan setelah masa tidak aktif yang sangat panjang.

Semuanya belum dibuat.

### 11. Bagaimana jika pemilik kehilangan private key-nya, tetapi masih hidup?

Kontrak tidak bisa membedakan pemilik yang kehilangan kunci dengan pemilik yang meninggal. Setelah 180 hari, dana akan menjadi warisan dan dibagikan ke ahli waris. Ini disebut terang-terangan di SPEC.md bagian 1.

Dalam praktiknya, dana tetap jatuh ke orang yang dipilih pemilik sendiri, bukan hilang.

### 12. Bagaimana jika ahli waris tidak bisa menerima ETH, atau kehilangan kuncinya?

Bagian orang itu **terkunci selamanya**, sedangkan ahli waris lain tetap bisa menarik bagiannya. Ini temuan L-2 dari review tahap 7, yang kami putuskan untuk dicatat sebagai risiko yang diterima.

Alternatif perbaikannya, yaitu ahli waris boleh menarik ke alamat lain, kami tolak karena menambah fitur di luar spesifikasi dan menambah celah baru. Wallet biasa selalu bisa menerima ETH.

### 13. Bagaimana kalau ada bug setelah kontrak di-deploy?

Kode kontrak **tidak bisa diubah** setelah di-deploy. Kami sengaja tidak memakai pola upgrade (proxy), karena pola itu memberi seseorang kuasa untuk mengganti aturan, dan itu justru bertentangan dengan tujuan proyek.

Jika ada bug dan pemilik masih hidup, pemilik bisa menarik semua dana (selama tahap Active), lalu men-deploy kontrak baru yang sudah diperbaiki. Karena itulah pengujian sebelum deploy sangat penting.

---

## D. Pertanyaan tentang biaya dan privasi

### 14. Berapa biayanya kalau dipakai sungguhan?

Kami hanya mengukur **gas**, yaitu jumlah "kerja" komputasi, di lingkungan test. Biaya ETH-nya bergantung pada harga gas jaringan saat transaksi dikirim, jadi tidak kami tulis sebagai angka pasti.

Angka gas dari `docs/gas-report.txt`:
- deploy: 2.976.783 gas;
- `checkIn`: median 21.367 gas;
- `finalizeClaim`: maksimal 332.994 gas.

Rumusnya: biaya = gas × harga gas. Kontrak ini belum pernah di-deploy ke jaringan publik, jadi kami tidak punya angka biaya nyata.

### 15. Bukankah semua orang bisa melihat siapa ahli waris dan berapa bagiannya?

Ya. Alamat ahli waris, guardian, porsi, dan saldo vault terlihat oleh siapa pun di blockchain publik. Ini risiko yang diterima di SPEC.md bagian 7.

Yang terlihat adalah **alamat**, bukan nama. Namun begitu alamat dikaitkan dengan seseorang, misalnya lewat exchange, kerahasiaannya hilang. Surat wasiat bisa dirahasiakan sampai dibuka, sedangkan kontrak ini tidak bisa. Ini salah satu alasan kontrak ini bukan pengganti wasiat.
