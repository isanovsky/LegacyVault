# Uji Perusakan (Mutation Check)

Test yang selalu hijau belum tentu test yang baik. Untuk membuktikan test keamanan benar-benar menjaga setiap mitigasi di SPEC.md bagian 7, kontrak sengaja dirusak di satu tempat, lalu test dijalankan ulang. Mutasi dianggap **tertangkap** jika ada test yang gagal. Kalau semua test tetap hijau, berarti ada celah di test.

## Cara pengujian

1. Membuat branch sementara `mutation-check` dari commit `7d3531e`.
2. Untuk setiap mutasi:
   - ubah `src/LegacyVault.sol` di satu tempat;
   - jalankan `forge test --match-path "test/security/*"`;
   - jika test keamanan tetap hijau, jalankan juga `forge test` penuh untuk melihat apakah test lain menangkapnya;
   - kembalikan file ke isi semula, byte per byte.
3. Kembali ke `main`, lalu hapus branch `mutation-check`.

Tidak ada kode rusak yang di-commit, baik di branch sementara maupun di `main`. Setelah semua mutasi, `git diff` untuk isi `src/LegacyVault.sol` kosong.

Untuk setiap mutasi, output asli (diff mutasi dan output test) disimpan di `docs/mutation/Mxx.txt`.

Nomor baris di tabel merujuk ke `src/LegacyVault.sol` versi commit tahap 3.

## Ringkasan

| | Jumlah |
|---|---|
| Mutasi dijalankan | 22 |
| Tertangkap test keamanan | 19 |
| Hanya tertangkap test utama | 1 (M16) |
| Tidak tertangkap test mana pun | 2 (M02, M03) |

## Hasil per mitigasi

### Ancaman 1: Reentrancy saat penarikan

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M01 | 356 | Hapus `inheritanceOf[msg.sender] = 0;` | Tertangkap | `test_RevertWhen_HeirWithdrawsInheritanceTwice` |
| M02 | 356 dipindah ke setelah 361 | Balik urutan CEI: nol-kan bagian **sesudah** ETH dikirim | **Tidak tertangkap** (93/93 lolos) | - |
| M03 | 352 | Hapus `nonReentrant` dari `withdrawInheritance` | **Tidak tertangkap** (93/93 lolos) | - |

**Kenapa M02 dan M03 tidak tertangkap.** Kedua perlindungan ini hanya berpengaruh jika penerima ETH memanggil `withdrawInheritance` lagi sebelum panggilan pertama selesai (*reentrancy*). Di test, penerima ETH adalah alamat biasa yang tidak menjalankan kode apa pun saat menerima ETH, sehingga urutan baris dan ada atau tidaknya `nonReentrant` tidak mengubah hasil.

Ini batasan yang disengaja: proyek ini tidak memuat kontrak penerima yang memanggil ulang. Akibatnya:

- Test membuktikan bahwa bagian heir **di-nol-kan** (M01 tertangkap), tetapi tidak membuktikan **kapan** bagian itu di-nol-kan, sebelum atau sesudah ETH dikirim.
- Kedua lapisan saling menutupi:
  - jika hanya M02 terjadi, `nonReentrant` masih menolak panggilan ulang;
  - jika hanya M03 terjadi, urutan CEI masih membuat panggilan ulang menemukan bagian yang sudah 0.

  Kontrak baru benar-benar rentan jika **keduanya** rusak sekaligus, dan kombinasi itu tidak akan ketahuan dari test yang ada.
- Pengaman untuk dua baris ini adalah tinjauan kode (code review), bukan test otomatis. Komentar NatSpec di atas `withdrawInheritance` menjelaskan kenapa urutannya tidak boleh diubah.

### Ancaman 2: Satu heir memblokir pembagian (DoS) dan hasil `call` dicek

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M04 | 361 | Hapus `if (!success) revert TransferFailed();` di `withdrawInheritance` | Tertangkap | `test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected` |
| M05 | 244 | Hapus `if (!success) revert TransferFailed();` di `withdraw` | Tertangkap | `test_RevertWhen_OwnerRejectsEth` |

Jika M04 lolos ke produksi, heir yang alamatnya menolak ETH akan kehilangan bagiannya: catatan bagiannya sudah di-nol-kan, tetapi ETH tidak pernah sampai.

Pull payment sendiri adalah keputusan desain (`finalizeClaim` tidak berisi loop pengiriman), bukan satu baris yang bisa dihapus, jadi tidak diuji lewat mutasi. Buktinya ada di test `test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected`: heir yang menolak ETH hanya menggagalkan penarikannya sendiri.

### Ancaman 3: Akses tanpa izin

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M06 | 234 | Hapus `onlyOwner` dari `withdraw` | Tertangkap | `testFuzz_RevertWhen_NonOwnerCallsOwnerFunctions` |
| M07 | 308 | Hapus `onlyGuardian` dari `approveClaim` | Tertangkap | `test_RevertWhen_HeirApproves`, `test_RevertWhen_OwnerApproves`, `test_RevertWhen_StrangerApproves` |
| M08 | 352 | Hapus `onlyHeir` dari `withdrawInheritance` | Tertangkap | `test_RevertWhen_GuardianWithdrawsInheritance`, `test_RevertWhen_OwnerWithdrawsInheritance`, `test_RevertWhen_StrangerWithdrawsInheritance` |

### Ancaman 4: Klaim keliru saat pemilik masih hidup

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M09 | 295 | Hapus pemeriksaan masa tidak aktif (`OwnerStillActive`) | Tertangkap | `test_RevertWhen_StartClaimBeforeInactivityEnds`, `test_RevertWhen_StartClaimAfterOwnerCheckedIn`, `test_CancelClaim_DuringTimelockBlocksFinalize` |
| M10 | 326 | Hapus pemeriksaan threshold (`NotEnoughApprovals`) | Tertangkap | `test_RevertWhen_FinalizeWithoutApprovals`, `test_RevertWhen_FinalizeBeforeThreshold`, `test_CancelClaim_OldApprovalsDoNotCarryOver` |
| M11 | 329 | Hapus pemeriksaan timelock (`TimelockNotExpired`) | Tertangkap | `test_RevertWhen_FinalizeBeforeTimelock` |
| M12 | 329 | Ubah `<` menjadi `<=` pada batas timelock | Tertangkap | `test_FinalizeClaim_ByAnyoneAtUnlockTime` dan 9 test lain yang menutup klaim tepat di `unlockTime` |
| M13 | 275 | Hapus `onlyOwner` dari `cancelClaim` | Tertangkap | `test_RevertWhen_HeirCancelsClaim`, `test_RevertWhen_GuardianCancelsClaim` |

### Ancaman 5: Persetujuan ganda atau persetujuan lama dipakai ulang

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M14 | 309 | Hapus pemeriksaan `AlreadyApproved` | Tertangkap | `test_RevertWhen_GuardianApprovesTwice` |
| M15 | 309, 311 | Persetujuan tidak terikat `claimId` (`hasApproved[0][...]`) | Tertangkap | `test_CancelClaim_OldApprovalsDoNotCarryOver` |
| M16 | 279 | `cancelClaim` tidak me-reset `approvalCount` | Hanya tertangkap test utama | `test_CancelClaim_ReturnsToActiveAndChecksIn` (di `test/LegacyVault.t.sol`) |

**Catatan M16.** Hitungan persetujuan juga di-reset di `startClaim` (baris 298), dan satu-satunya jalan untuk memakai hitungan itu lagi adalah lewat klaim baru. Jadi M16 hanya membuat `getStatus()` menampilkan angka lama selama vault kembali ke Active, dan tidak membuka celah keamanan. Karena itu test keamanan memang tidak menangkapnya, tetapi test fungsional menangkapnya. Reset di `cancelClaim` dipertahankan supaya tampilan UI tetap jujur.

### Ancaman 6: Manipulasi `block.timestamp`

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M17 | 195 | Hapus batas minimal 1 hari untuk `inactivityPeriod` | Tertangkap | `test_RevertWhen_InactivityPeriodBelowOneDay` |

### Ancaman 7: Pembulatan porsi

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M18 | 344 | Heir terakhir hanya mendapat porsi bps, tanpa sisa pembulatan | Tertangkap | `test_WithdrawInheritance_RoundingRemainderGoesToLastHeir`, `testFuzz_SharesAlwaysAddUpToSnapshot` |

### Ancaman 8: Gas DoS karena daftar terlalu panjang

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M19 | 423 | Hapus batas maksimal 10 heir | Tertangkap | `test_RevertWhen_MoreThanTenHeirs`, `test_RevertWhen_UpdateHeirsWithMoreThanTenHeirs` |
| M20 | 403 | Hapus batas maksimal 10 guardian | Tertangkap | `test_RevertWhen_MoreThanTenGuardians` |

### Ancaman 9: ETH dikirim setelah Distributed

| ID | Baris | Mutasi | Hasil | Test yang gagal |
|---|---|---|---|---|
| M21 | 220 | Hapus `inState(State.Active)` dari `receive` | Tertangkap | `test_RevertWhen_PlainTransferAfterDistributed` |
| M22 | 225 | Hapus `inState(State.Active)` dari `deposit` | Tertangkap | `test_RevertWhen_DepositAfterDistributed` |

## Mengulang uji ini secara manual

Contoh untuk M01:

```bash
git switch -c mutation-check
```

Hapus baris `inheritanceOf[msg.sender] = 0;` di `withdrawInheritance`, lalu jalankan:

```bash
forge test --match-path "test/security/*"
```

`test_RevertWhen_HeirWithdrawsInheritanceTwice` harus gagal. Setelah itu kembalikan dan hapus branch:

```bash
git restore src/LegacyVault.sol
```

```bash
git switch main
```

```bash
git branch -D mutation-check
```
