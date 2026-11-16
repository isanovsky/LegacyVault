# Review Keamanan LegacyVault (Tahap 7)

Review manual terhadap `src/LegacyVault.sol`, dengan sudut pandang auditor yang skeptis. Tiga pertanyaan utamanya:

1. Adakah jalur di mana dana bisa **terkunci selamanya**?
2. Adakah jalur di mana dana bisa **keluar tanpa syarat lengkap**?
3. Adakah jalur di mana dana bisa **dihitung ganda**?

Setiap fungsi juga dicocokkan dengan SPEC.md: peran, state, dan efeknya.

Review ini dilakukan oleh pengembang proyek sendiri (dibantu Claude Code), bukan audit independen.

## Alat analisis otomatis

**Slither tidak dijalankan**, karena tidak terpasang di komputer pengembangan. Python 3.12 dan pip tersedia, tetapi paket `slither-analyzer` belum dipasang. Tidak ada hasil Slither di dokumen ini.

Alat yang dipakai:
- pembacaan kode baris per baris;
- `forge test` untuk membuktikan temuan;
- uji perusakan (mutation) untuk membuktikan test regresinya.

## Ringkasan

| ID | Tingkat | Judul | Status |
|---|---|---|---|
| L-1 | Rendah | Periode tanpa batas atas membuat penjumlahan waktu meluap, sehingga dana bisa terkunci | **Diperbaiki** |
| L-2 | Rendah | Heir yang tidak bisa menerima ETH kehilangan bagiannya selamanya | **Didokumentasikan** sebagai risiko yang diterima |
| I-1 | Informasi | Heir yang kehilangan kunci kehilangan bagiannya | Didokumentasikan sebagai risiko yang diterima |
| I-2 | Informasi | Transaksi bernilai nol | Tidak diubah |
| I-3 | Informasi | `threshold = 1` berarti satu guardian sudah cukup | Tidak diubah (pilihan konfigurasi) |
| I-4 | Informasi | Risiko yang diterima di SPEC terkonfirmasi | Tidak diubah |

Tidak ditemukan jalur bagi pihak tanpa wewenang untuk mengambil dana, jalur dana keluar tanpa semua syarat, atau jalur hitungan ganda.

## L-1. Periode tanpa batas atas (diperbaiki)

**Masalah.** Sebelum perbaikan, constructor hanya memeriksa batas bawah (`>= 1 days`). Jika deployer salah mengisi periode dengan angka raksasa, penjumlahan waktu meluap dan transaksi gagal dengan *panic* `0x11`:

| Periode raksasa | Akibat |
|---|---|
| `inactivityPeriod` | `getStatus()` selalu gagal, jadi UI tidak bisa membaca status. `startClaim()` juga selalu gagal, sehingga warisan tidak pernah bisa dimulai. |
| `timelockPeriod` | `approveClaim()` yang mencapai threshold selalu gagal. Klaim tertahan di `Claiming`. Jika pemilik sudah tiada, tidak ada yang bisa membatalkan klaim, dan **dana terkunci selamanya**. |

**Bukti sebelum perbaikan.** Dua test sementara dijalankan dengan `type(uint256).max`, dan keduanya lolos. Artinya panic memang terjadi:

```
[PASS] test_Probe_HugeInactivityBreaksGetStatusAndStartClaim() (gas: 3066573)
[PASS] test_Probe_HugeTimelockBlocksApprovalAtThreshold() (gas: 3235561)
```

File test sementara itu dihapus setelah dijalankan dan tidak di-commit.

**Perbaikan.**
- Konstanta `MAX_PERIOD = 3650 days` (10 tahun) dan error `PeriodTooLong(period)`, dicek di constructor untuk kedua periode.
- Aturan ini ditambahkan ke SPEC.md bagian 2.

Dengan batas ini, semua penjumlahan waktu aman. `block.timestamp` dan `lastCheckIn` berada di kisaran 10^9 detik, dan 10 tahun hanya sekitar 3,2 × 10^8 detik, jauh dari batas `uint256`.

**Test regresi** (`test/security/LegacyVault.security.t.sol`, kelompok "Temuan L-1"):

| Test | Membuktikan |
|---|---|
| `test_RevertWhen_InactivityPeriodAboveTenYears` | 3650 hari + 1 detik ditolak |
| `test_RevertWhen_TimelockPeriodAboveTenYears` | 3650 hari + 1 detik ditolak |
| `test_RevertWhen_PeriodsAreUint256Max` | Nilai yang dipakai saat membuktikan temuan ini sekarang ditolak saat deploy |
| `test_MaxPeriods_ClaimFlowCompletesWithoutOverflow` | Dengan periode terpanjang yang diizinkan, `getStatus` bekerja dan klaim berjalan sampai `Distributed` |

Ditambah `test_Constructor_AcceptsPeriodsOfExactlyTenYears` di `test/LegacyVault.t.sol`.

**Bukti test regresinya berguna.** Uji perusakan M23 menghapus kembali kedua pemeriksaan `PeriodTooLong`. Hasilnya, 3 test gagal (lihat [MUTATION.md](MUTATION.md) dan `docs/mutation/M23.txt`).

## L-2. Heir yang tidak bisa menerima ETH (didokumentasikan)

`withdrawInheritance` hanya mengirim ETH ke alamat pemanggil (`msg.sender`). Jika heir adalah kontrak yang menolak ETH (misalnya tidak punya `receive`), bagiannya tetap tercatat tetapi tidak pernah bisa keluar.

Test `test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected` sudah memperlihatkan ini:
- bagian 3 ETH milik heir itu tetap tercatat;
- heir lain tetap bisa menarik bagiannya.

**Keputusan pemilik proyek:** didokumentasikan sebagai risiko yang diterima di SPEC.md bagian 7, tanpa perubahan kode. Alasannya:
- Wallet biasa dan multisig umum bisa menerima ETH.
- Pemilik sendiri yang memilih alamat heir.

Alternatif yang ditolak: fungsi `withdrawInheritanceTo(address payable to)`, yang membiarkan heir memilih alamat penerima. Fungsi ini menambah fitur di luar SPEC dan menambah permukaan serangan.

## Catatan informasi

**I-1. Heir kehilangan kunci.** Bagiannya terkunci selamanya. Desain apa pun tidak bisa mencegahnya tanpa pihak ketiga yang dipercaya. Sekarang tercantum di SPEC.md bagian 7.

**I-2. Transaksi bernilai nol.**
- `withdraw(0)` dan setoran 0 wei dari owner tetap dihitung sebagai check-in. Tidak berbahaya, karena owner memang boleh check-in kapan saja.
- Orang asing bisa menyetor 0 wei berulang kali sehingga muncul banyak event `Deposited`. Ini hanya mengotori buku catatan UI dan tidak menunda klaim. Bahwa setoran orang asing tidak dihitung sebagai check-in sudah diuji oleh `test_Deposit_ByStrangerDoesNotCheckIn`.

**I-3. `threshold = 1`.** Diizinkan SPEC. Artinya satu guardian, ditambah timelock, sudah cukup untuk mencairkan dana. Ini pilihan konfigurasi pemilik, bukan bug. Contoh demo memakai 2 dari 3.

**I-4. Risiko yang diterima di SPEC terkonfirmasi.**
- Klaim tertahan jika guardian tidak responsif.
- ETH yang dipaksa masuk setelah `Distributed` terkunci.
- ETH yang dipaksa masuk saat `Active` bisa ditarik owner, dan saat `Claiming` ikut masuk snapshot. Keduanya tidak bermasalah.

## Yang diperiksa dan dinyatakan aman

| Pertanyaan | Hasil |
|---|---|
| Jalan keluar ETH | Hanya dua: `withdraw` (owner, `Active`) dan `withdrawInheritance` (heir, `Distributed`, sebesar bagian yang tercatat). Tidak ada fungsi lain yang mengirim ETH. |
| Syarat klaim lengkap | `unlockTime` dipasang tepat saat `approvalCount == threshold`. Hitungan naik satu per satu, jadi titik itu pasti terlewati. `finalizeClaim` memeriksa persetujuan dan timelock sekaligus. Persetujuan terikat `claimId`. `cancelClaim` dihitung sebagai check-in, sehingga klaim baru harus menunggu masa tidak aktif lagi. |
| Hitungan ganda | `inheritanceOf` diisi dengan `=`, bukan `+=`, dan `finalizeClaim` hanya bisa jalan sekali. Duplikat heir ditolak saat validasi. Jumlah bagian tepat sama dengan snapshot (fuzz test). Bagian di-nol-kan sebelum ETH dikirim. |
| Reentrancy lintas fungsi | Saat `withdrawInheritance` mengirim ETH, state sudah `Distributed`. Heir yang memanggil ulang hanya bisa masuk ke fungsi yang ditolak `nonReentrant`, pemeriksaan state, atau pemeriksaan peran. Saat `withdraw` mengirim ETH ke owner, owner yang memanggil ulang bisa masuk ke `deposit`, `checkIn`, atau `updateHeirs`, tetapi semua itu memang hak owner kapan saja. Saldo yang dipakai `withdraw` sudah diperiksa, dan `withdraw` kedua ditolak `nonReentrant`. |
| Penggantian heir | `updateHeirs` menghapus tanda `isHeir` lama sebelum memasang yang baru, dan seluruh perubahan dibatalkan jika satu aturan dilanggar. Bagian warisan baru dihitung saat `finalizeClaim`, jadi tidak ada sisa dari daftar lama. |

### Kesesuaian dengan SPEC.md bagian 4

| Fungsi | Peran | State | Efek | Catatan |
|---|---|---|---|---|
| `constructor` | deployer | - | Sesuai | Juga memancarkan `Deposited` jika di-deploy sambil membawa ETH; konsisten dengan SPEC |
| `receive` / `deposit` | siapa saja | `Active` | Sesuai (check-in jika owner) | |
| `withdraw` | owner | `Active` | Sesuai | Tambahan `nonReentrant` |
| `checkIn` | owner | `Active` | Sesuai | |
| `updateHeirs` | owner | `Active` | Sesuai | |
| `startClaim` | heir / guardian | `Active` | Sesuai | |
| `approveClaim` | guardian | `Claiming` | Sesuai | |
| `cancelClaim` | owner | `Claiming` | Sesuai | Juga me-reset `unlockTime` |
| `finalizeClaim` | siapa saja | `Claiming` | Sesuai | |
| `withdrawInheritance` | heir | `Distributed` | Sesuai | |
| `getStatus` | siapa saja | semua | Sesuai | |

Tidak ada penyimpangan dari SPEC.
