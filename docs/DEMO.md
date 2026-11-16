# Naskah Demo LegacyVault

Durasi target sekitar 4 menit, dengan batas 3–5 menit. Naskah ini ditulis supaya penonton yang belum pernah memakai kripto tetap bisa mengikuti.

Seluruh langkah UI dan perintah terminal di bawah sudah dicoba dari awal sampai akhir pada kode commit tahap 7. Pesan di layar yang dikutip di sini adalah pesan asli dari gladi itu. Tanggal dan nomor blok akan berbeda, karena bergantung pada kapan Anvil dinyalakan.

Pertanyaan sulit dan jawabannya ada di file terpisah: [PERTANYAAN-DOSEN.md](PERTANYAAN-DOSEN.md).

---

## Persiapan (sebelum presentasi dimulai)

Lakukan 10–15 menit sebelum giliran Anda.

1. Buka tiga terminal di VS Code, dari folder proyek. Jalankan satu perintah di masing-masing terminal, lalu biarkan ketiganya tetap terbuka.

   Terminal 1, blockchain lokal:

   ```bash
   npm run anvil
   ```

   Terminal 2, vault demo:

   ```bash
   npm run seed
   ```

   Terminal 3, tampilan:

   ```bash
   npm run ui
   ```

2. Buka http://127.0.0.1:5173 di browser. Pastikan kepala halaman menunjukkan **Jaringan** dan **Blok**, bukan "menghubungkan…".
3. Buka tab browser kedua di http://127.0.0.1:5173/penjelasan.html sebagai cadangan.
4. Buka terminal keempat untuk bagian bukti keamanan, juga di folder proyek. Jalankan sekali `forge build` supaya kompilasi tidak memakan waktu saat demo.
5. Buka `src/LegacyVault.sol` di VS Code. Tekan `Ctrl+F`, lalu cari `inheritanceOf[msg.sender] = 0;` supaya baris itu siap ditampilkan.
6. Periksa `git status`. Hasilnya harus bersih, supaya `git restore` di akhir uji perusakan hanya mengembalikan perubahan demo.
7. Perbesar huruf terminal dan browser (`Ctrl` + `+`) supaya terbaca dari kursi belakang.

Jika vault sudah pernah dipakai latihan, matikan Anvil (`Ctrl+C`), lalu ulangi langkah 1. Setiap Anvil dinyalakan ulang, isinya kembali kosong.

---

## Naskah

Kolom "Yang diucapkan" adalah contoh kalimat. Ubah dengan kata-kata Anda sendiri supaya terdengar wajar.

### Langkah 1. Masalahnya (± 30 detik)

**Di layar:** halaman simulasi, belum diklik apa pun.

**Yang diucapkan:**

> "Uang kripto hanya bisa dipindahkan oleh orang yang memegang kuncinya, semacam kata sandi rahasia. Kalau pemiliknya meninggal dan kuncinya ikut hilang, keluarganya tidak bisa mengambil uang itu. Tidak ada bank yang bisa dimintai tolong.
>
> LegacyVault adalah brankas digital yang bisa diwariskan. Aturannya ditulis sebagai program di blockchain, jadi tidak ada satu orang pun yang bisa mengubahnya diam-diam."

### Langkah 2. Kenalan dengan tokohnya (± 30 detik)

**Di layar:** tunjuk baris "Bertindak sebagai" dan tabel ringkasan.

**Yang diucapkan:**

> "Ini Pak Icanov, pemilik brankas. Ia menyimpan 10 ETH. ETH adalah mata uang di jaringan Ethereum.
>
> Ahli warisnya dua orang: Mas Kevin mendapat 60 persen, Mas Murni 40 persen.
>
> Ada juga tiga saksi, yang kami sebut guardian: Mas Barrok, Notaris Budi, dan Pak RT Wowo. Untuk mencairkan warisan, minimal dua dari tiga saksi harus setuju.
>
> Semua ini berjalan di blockchain latihan di laptop saya, namanya Anvil. Uangnya bukan uang sungguhan, dan waktunya bisa kami percepat."

### Langkah 3. Ahli waris tidak bisa mengambil terlalu cepat (± 30 detik)

**Di layar:**

1. Klik **Mas Kevin**.
2. Klik **Mulai klaim warisan**.

Muncul label **DITOLAK** dengan pesan "Ditolak: pemilik masih aktif sampai …", dan wajah Mas Kevin berubah cemas.

**Yang diucapkan:**

> "Misalkan Mas Kevin tidak sabar dan mencoba mengklaim warisan hari ini. Ditolak.
>
> Yang menolak bukan tampilan web ini, tetapi programnya sendiri di blockchain. Selama Pak Icanov masih memberi kabar dalam 180 hari terakhir, warisan tidak bisa diklaim."

### Langkah 4. Pemilik tidak memberi kabar selama 180 hari (± 30 detik)

**Di layar:**

1. Klik **+180 hari**.
2. Masih sebagai Mas Kevin, klik **Mulai klaim warisan**.

Muncul label **BERHASIL**, dan tahap vault berpindah ke **Claiming**.

**Yang diucapkan:**

> "Sekarang kita majukan waktu 180 hari. Anggap saja Pak Icanov sudah setengah tahun tidak memberi kabar.
>
> Mas Kevin mencoba lagi, dan kali ini klaimnya diterima. Tetapi uangnya belum keluar. Klaim baru dibuka, dan masih harus melewati dua pengaman lagi."

### Langkah 5. Dua saksi menyetujui (± 40 detik)

**Di layar:**

1. Klik **Mas Barrok**, lalu **Setujui klaim**.
2. Klik **Notaris Budi**, lalu **Setujui klaim**.

Tunjuk kolom "Syarat pencairan":
- "Persetujuan 2/2" TERPENUHI;
- "Timelock selesai" BELUM, dengan sisa 7 hari.

**Yang diucapkan:**

> "Pengaman kedua adalah saksi. Mas Barrok setuju, Notaris Budi setuju. Dua dari tiga sudah cukup.
>
> Pengaman ketiga adalah masa tunggu 7 hari. Gunanya: kalau ternyata Pak Icanov masih hidup, misalnya hanya sedang lama di luar negeri, ia masih punya waktu seminggu untuk menekan tombol 'Batalkan klaim', dan semuanya kembali normal."

### Langkah 6. Mencoba mencairkan sebelum masa tunggu selesai (± 20 detik)

**Di layar:**

1. Klik **Pak RT Wowo**.
2. Klik **Finalisasi klaim**.

Muncul **DITOLAK** dengan pesan "masa tunggu belum selesai. Klaim baru bisa difinalisasi pada …".

**Yang diucapkan:**

> "Kalau ada yang mencoba mencairkan sekarang, program menolak, karena masa tunggunya belum habis."

### Langkah 7. Masa tunggu habis, warisan dibagi (± 40 detik)

**Di layar:**

1. Klik **+7 hari**.
2. Masih sebagai Pak RT Wowo, klik **Finalisasi klaim**. Tabel ahli waris menunjukkan 6 ETH dan 4 ETH.
3. Klik **Mas Kevin**, lalu **Tarik bagian warisan**.
4. Klik **Mas Murni**, lalu **Tarik bagian warisan**.

Hasil akhirnya: kedua baris bertanda **SUDAH DITARIK**, dan "Saldo vault" menunjukkan **0 ETH**.

**Yang diucapkan:**

> "Seminggu berlalu. Sekarang siapa pun boleh menekan tombol finalisasi, karena semua syarat sudah diperiksa oleh program. Hasilnya tidak bisa diubah oleh orang yang menekannya.
>
> Program menghitung pembagiannya: 6 ETH untuk Mas Kevin, 4 ETH untuk Mas Murni. Masing-masing menarik bagiannya sendiri. Brankas sekarang kosong, tidak ada satu sen pun yang tertinggal.
>
> Di sebelah kanan ada buku catatan. Setiap kejadian tadi tercatat permanen di blockchain dan tidak bisa dihapus."

### Langkah 8. Bukti keamanan di terminal (± 30 detik)

**Di layar:** pindah ke terminal keempat, lalu jalankan:

```bash
forge test --match-path "test/security/*"
```

Baris terakhir yang muncul:

```
38 tests passed, 0 failed, 0 skipped (38 total tests)
```

**Yang diucapkan:**

> "Tampilan tadi hanya satu skenario. Untuk membuktikan programnya aman, kami menulis 38 uji otomatis khusus keamanan. Setiap uji mencoba satu cara curang: orang asing mencoba menarik uang, saksi menyetujui dua kali, ahli waris menarik dua kali, dan seterusnya. Semuanya lolos, artinya semua kecurangan itu ditolak.
>
> Secara keseluruhan proyek ini punya 105 uji, dan semuanya lolos."

### Langkah 9. Uji perusakan: membuktikan ujinya tidak asal hijau (± 50 detik)

**Di layar:**

1. Di VS Code, buka `src/LegacyVault.sol` pada baris `inheritanceOf[msg.sender] = 0;` di fungsi `withdrawInheritance`.
2. Ubah baris itu menjadi komentar dengan menambahkan `//` di depannya, lalu simpan (`Ctrl+S`).
3. Jalankan di terminal:

   ```bash
   forge test --match-test test_RevertWhen_HeirWithdrawsInheritanceTwice
   ```

   Hasilnya **gagal**:

   ```
   [FAIL: next call did not revert as expected] test_RevertWhen_HeirWithdrawsInheritanceTwice()
   ```

4. Kembalikan kodenya:

   ```bash
   git restore src/LegacyVault.sol
   ```

5. Jalankan perintah test yang sama sekali lagi. Hasilnya `[PASS]`.

**Yang diucapkan:**

> "Uji yang selalu lolos belum tentu uji yang bagus. Bisa saja ujinya tidak memeriksa apa-apa. Jadi kami sengaja merusak programnya.
>
> Baris ini mencatat bahwa ahli waris sudah mengambil bagiannya. Saya matikan baris ini. Sekarang ahli waris bisa menarik warisan berkali-kali.
>
> Ujinya langsung gagal, artinya uji kami menangkap kerusakan itu.
>
> Kami melakukan ini 23 kali di 23 tempat berbeda. 20 tertangkap uji keamanan, 1 tertangkap uji biasa, dan 2 tidak tertangkap. Yang 2 itu kami tulis terus terang di dokumentasi beserta alasannya.
>
> Setelah itu kodenya saya kembalikan, dan ujinya lolos lagi."

### Penutup (± 15 detik)

**Yang diucapkan:**

> "Jadi LegacyVault punya tiga pengaman: 180 hari tanpa kabar, persetujuan dua dari tiga saksi, dan masa tunggu tujuh hari, di mana pemilik masih bisa membatalkan.
>
> Batasannya juga kami akui. Program ini tidak tahu apakah seseorang benar-benar meninggal, dan tidak menggantikan surat wasiat. Terima kasih."

### Perkiraan waktu

| Langkah | Waktu |
|---|---|
| 1–2. Masalah dan tokoh | 1:00 |
| 3–7. Alur warisan di UI | 2:40 |
| 8–9. Bukti keamanan dan uji perusakan | 1:20 |
| Penutup | 0:15 |
| **Total** | **± 5:15** |

Total ini sedikit di atas 5 menit. Jika waktu ketat, pilih salah satu atau keduanya:
- lewati Langkah 6 (hemat ± 20 detik);
- di Langkah 9, cukup jalankan test yang gagal, lalu katakan "kodenya saya kembalikan" sambil menjalankan `git restore` tanpa menjalankan ulang test (hemat ± 15 detik).

Jika keduanya dilewati, durasinya sekitar 4:40. Latih sekali dengan stopwatch; waktu sebenarnya bergantung pada kecepatan bicara.

---

## Rencana cadangan jika UI bermasalah

Prinsipnya: **jangan memperbaiki di depan penonton lebih dari 30 detik.** Kalau langkah A tidak langsung berhasil, pindah ke B atau C.

### A. Pemulihan cepat (maksimal 30 detik)

| Gejala | Penyebab paling mungkin | Tindakan |
|---|---|---|
| Kepala halaman tertulis "menghubungkan…" atau ada kotak merah berisi pesan kesalahan | Anvil mati, atau Anvil dinyalakan ulang tetapi seed belum dijalankan | Di terminal 1 jalankan `npm run anvil` (jika mati), di terminal 2 `npm run seed`, lalu muat ulang browser (`F5`) |
| Halaman tidak terbuka sama sekali | Server UI mati | Di terminal 3 jalankan `npm run ui` |
| Vault sudah di tahap yang salah karena sisa latihan | Anvil tidak dinyalakan ulang | `Ctrl+C` di terminal 1, lalu jalankan ulang `npm run anvil` dan `npm run seed`, lalu `F5` |

**Yang diucapkan saat memulihkan:**

> "Blockchain latihannya saya nyalakan ulang dulu. Karena ini jaringan lokal, isinya kembali bersih setiap kali dinyalakan."

### B. Halaman "Cara kerja" (tidak membutuhkan Anvil)

Buka tab cadangan http://127.0.0.1:5173/penjelasan.html. Pilih bagian **4. Perjalanan uang warisan**, lalu tekan panah kanan untuk berpindah langkah. Bagian ini menceritakan alur yang sama dengan Langkah 3–7: setor, 180 hari, klaim, persetujuan, timelock, pembagian.

Halaman ini hanya butuh server UI (`npm run ui`), tidak butuh blockchain.

### C. Semua lewat terminal (tidak membutuhkan browser maupun Anvil)

Jalankan alur yang sama dalam bentuk uji otomatis:

```bash
forge test --match-test "test_RevertWhen_StartClaimBeforeInactivityEnds|test_EndToEnd_HappyPath|test_CancelClaim_DuringTimelockBlocksFinalize" -vv
```

Hasil saat gladi:

```
[PASS] test_CancelClaim_DuringTimelockBlocksFinalize() (gas: 383041)
[PASS] test_RevertWhen_StartClaimBeforeInactivityEnds() (gas: 48189)
[PASS] test_EndToEnd_HappyPath() (gas: 793541)
Ran 2 test suites in 5.10ms (4.68ms CPU time): 3 tests passed, 0 failed, 0 skipped (3 total tests)
```

**Yang diucapkan:**

> "Tampilannya sedang bermasalah, jadi saya tunjukkan alur yang sama lewat uji otomatis. Ketiga uji ini menjalankan cerita yang tadi akan saya tunjukkan:
> - yang pertama, ahli waris ditolak karena pemilik masih aktif;
> - yang kedua, alur lengkap dari setor sampai warisan ditarik;
> - yang ketiga, pemilik yang ternyata masih hidup membatalkan klaim di tengah masa tunggu.
>
> Ketiganya lolos."

Setelah itu lanjutkan ke Langkah 8 dan 9 seperti biasa, karena keduanya memang memakai terminal.

Untuk menunjukkan jumlah seluruh uji:

```bash
forge test
```

Baris terakhirnya: `105 tests passed, 0 failed, 0 skipped (105 total tests)`.

### D. Jika laptop sama sekali tidak bisa dipakai

Siapkan sebelumnya beberapa tangkapan layar di ponsel atau flashdisk:
- halaman simulasi saat DITOLAK (Langkah 3);
- halaman simulasi saat SUDAH DITARIK (Langkah 7);
- output `forge test`.

Sebagai rujukan, bisa juga dibuka file `docs/test-output.txt` dan `docs/security-output.txt` dari repositori. Isinya output asli yang tersimpan.

---

## Hal yang perlu dihindari saat demo

- **Jangan commit** saat kode sedang dirusak di Langkah 9. Selalu akhiri dengan `git restore src/LegacyVault.sol`, lalu cek `git status`.
- **Jangan menekan tombol waktu lebih dulu** sebelum Langkah 3, karena penolakan pertama tidak akan muncul.
- **Jangan menyebut uang sungguhan.** ETH di Anvil adalah uang mainan, dan setiap akun Anvil memang punya 10.000 ETH.
- Jika ditanya kenapa saldo dompet berkurang sedikit setelah transaksi, jawab: itu biaya gas, ongkos menjalankan program di blockchain. Di Anvil biayanya juga uang mainan.
