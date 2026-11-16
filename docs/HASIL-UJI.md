# Hasil Uji LegacyVault

Ringkasan ini hanya memakai angka dari empat file output asli:

| File | Perintah |
|---|---|
| [test-output.txt](test-output.txt) | `forge test -vv` |
| [security-output.txt](security-output.txt) | `forge test --match-path "test/security/*" -vv` |
| [gas-report.txt](gas-report.txt) | `forge test --gas-report` |
| [MUTATION.md](MUTATION.md) | Uji perusakan manual, dengan output per mutasi di `docs/mutation/` |

Tiga file `.txt` dijalankan ulang di tahap 6, dengan kode kontrak yang sama, supaya mencakup seluruh test saat ini. Versi tahap 2 masih bisa dilihat di riwayat git. MUTATION.md berasal dari tahap 3; lihat catatan di bagian 3.

Lingkungan: Solidity 0.8.28, Foundry 1.9.0, dan 1000 run untuk setiap fuzz test (`foundry.toml`).

## 1. Seluruh test (`test-output.txt`)

| Suite | File | Lolos | Gagal | Dilewati |
|---|---|---|---|---|
| `ScriptsTest` | `test/script/Scripts.t.sol` | 7 | 0 | 0 |
| `LegacyVaultTest` | `test/LegacyVault.t.sol` | 59 | 0 | 0 |
| `LegacyVaultSecurityTest` | `test/security/LegacyVault.security.t.sol` | 34 | 0 | 0 |
| **Total** | 3 suite | **100** | **0** | **0** |

Baris penutup dari output:

```
Ran 3 test suites in 373.20ms (397.39ms CPU time): 100 tests passed, 0 failed, 0 skipped (100 total tests)
```

Fuzz test (keduanya ada di suite keamanan):

| Test | Run | Gas rata-rata (μ) | Gas median (~) |
|---|---|---|---|
| `testFuzz_RevertWhen_NonOwnerCallsOwnerFunctions(address)` | 1000 | 121207 | 121207 |
| `testFuzz_SharesAlwaysAddUpToSnapshot(uint256,uint256,uint256)` | 1000 | 4046088 | 4090269 |

Gas fuzz test adalah biaya seluruh skenario test, termasuk deploy vault baru di setiap run. Angka ini bukan biaya satu transaksi pengguna.

## 2. Test keamanan (`security-output.txt`)

```
Ran 1 test suite in 334.15ms (331.15ms CPU time): 34 tests passed, 0 failed, 0 skipped (34 total tests)
```

34 test ini dikelompokkan per baris tabel model ancaman SPEC.md bagian 7:

| Ancaman | Jumlah test |
|---|---|
| 1. Reentrancy saat penarikan | 1 |
| 2. Satu heir memblokir pembagian (DoS) | 2 |
| 3. Akses tanpa izin | 10 |
| 4. Klaim keliru saat pemilik masih hidup | 10 |
| 5. Persetujuan ganda / persetujuan lama dipakai ulang | 2 |
| 6. Manipulasi `block.timestamp` | 2 |
| 7. Pembulatan porsi | 2 |
| 8. Gas DoS karena daftar terlalu panjang | 3 |
| 9. ETH dikirim setelah `Distributed` | 2 |
| **Total** | **34** |

Pemetaan setiap test ke mitigasinya ada di [KEAMANAN.md](KEAMANAN.md).

Di file ini, nilai μ dan ~ untuk `testFuzz_SharesAlwaysAddUpToSnapshot` (4026204 dan 4090257) sedikit berbeda dari `test-output.txt`. Penyebabnya, input fuzz diacak ulang setiap kali test dijalankan.

## 3. Uji perusakan (`MUTATION.md`)

| | Jumlah |
|---|---|
| Mutasi dijalankan | 22 |
| Tertangkap test keamanan | 19 |
| Hanya tertangkap test utama | 1 (M16) |
| Tidak tertangkap test mana pun | 2 (M02, M03) |

- **M02** (membalik urutan Checks-Effects-Interactions) dan **M03** (menghapus `nonReentrant`) tidak tertangkap. Saat uji ini, test yang ada lolos semua (93/93). Penyebabnya, proyek ini tidak memuat kontrak penerima yang memanggil ulang kontrak. Kedua perlindungan ini saling menutupi, tetapi kerusakan keduanya sekaligus tidak akan ketahuan dari test.
- **M16** (`cancelClaim` tidak me-reset hitungan persetujuan) hanya mengubah tampilan `getStatus()` dan tidak membuka celah, karena `startClaim` juga me-reset hitungan.

Uji perusakan dijalankan di tahap 3, saat ada 93 test. Tujuh test skrip deploy ditambahkan di tahap 4 dan tidak menguji kontrak `LegacyVault`, sehingga hasil mutasi di atas tidak berubah karenanya. Uji perusakan belum dijalankan ulang di tahap 6.

## 4. Laporan gas (`gas-report.txt`)

Angka di bawah adalah gas yang diukur Foundry selama test berjalan, untuk kontrak `src/LegacyVault.sol`.

### Deploy

| Biaya deploy (gas) | Ukuran kontrak (byte) |
|---|---|
| 2961888 | 15591 |

### Fungsi yang mengubah state

| Fungsi | Min | Rata-rata | Median | Max | Jumlah panggilan |
|---|---|---|---|---|---|
| `receive` | 23888 | 24391 | 24391 | 24895 | 4 |
| `deposit` | 24118 | 26869 | 25136 | 31354 | 6 |
| `withdraw` | 27034 | 27255 | 27034 | 44433 | 261 |
| `checkIn` | 21367 | 21442 | 21367 | 29770 | 258 |
| `updateHeirs` | 26460 | 28052 | 26460 | 119781 | 265 |
| `startClaim` | 25803 | 77234 | 78865 | 78865 | 300 |
| `approveClaim` | 23526 | 78069 | 75136 | 82094 | 557 |
| `cancelClaim` | 21322 | 21618 | 21322 | 46104 | 260 |
| `finalizeClaim` | 24121 | 206406 | 195616 | 333016 | 276 |
| `withdrawInheritance` | 28819 | 45066 | 45118 | 45118 | 1442 |

### Fungsi baca

| Fungsi | Gas (min = max) | Jumlah panggilan |
|---|---|---|
| `getStatus` | 12529 | 4 |

Getter otomatis lain (misalnya `owner`, `heirs`, `inheritanceOf`) juga tercatat di `gas-report.txt`. Fungsi baca gratis jika dipanggil dari luar lewat `eth_call`, seperti yang dilakukan UI. Angka gasnya hanya berlaku jika fungsi itu dipanggil dari dalam transaksi.

### Cara membaca angka ini

- **Min yang jauh di bawah median** umumnya berasal dari panggilan yang ditolak di awal fungsi (revert). Gas report Foundry ikut mencatat panggilan yang ditolak. Contohnya `finalizeClaim` (24121) dan `startClaim` (25803).
- **Gas `finalizeClaim` bergantung pada jumlah heir**, karena fungsi ini mencatat bagian setiap heir dalam loop. Test memakai 1 sampai 10 heir, dan batas 10 heir menjaga angka maksimalnya tetap terbatas. Laporan gas tidak memecah angka per jumlah heir.
- **Rata-rata dan median** ikut dipengaruhi fuzz test yang memakai input acak, jadi bisa sedikit berbeda setiap kali dijalankan.
- Angka ini adalah jumlah gas, bukan biaya dalam ETH. Biaya ETH = gas × harga gas jaringan saat itu.
