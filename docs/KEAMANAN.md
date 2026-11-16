# Analisis Keamanan LegacyVault

Dokumen ini memetakan setiap ancaman di [SPEC.md](../SPEC.md) bagian 7 ke mitigasinya di kode dan ke test yang membuktikannya. Semua nama test di bawah adalah test nyata yang lolos di `forge test` (lihat [HASIL-UJI.md](HASIL-UJI.md)).

Lokasi test:

- **[S]** `test/security/LegacyVault.security.t.sol`, dikelompokkan per ancaman.
- **[U]** `test/LegacyVault.t.sol`, test fungsional.
- **[D]** `test/script/Scripts.t.sol`, test skrip deploy.

Kalau sebuah klaim tidak didukung test, hal itu disebut terang-terangan.

## 1. Ancaman, mitigasi, dan bukti

### Ancaman 1: Reentrancy saat penarikan

**Mitigasi.** `withdrawInheritance` dan `withdraw` memakai modifier `nonReentrant` dari OpenZeppelin `ReentrancyGuard`. `withdrawInheritance` juga mengikuti urutan Checks-Effects-Interactions: bagian heir di-nol-kan sebelum ETH dikirim.

**Bukti.**

- [S] `test_RevertWhen_HeirWithdrawsInheritanceTwice`: penarikan kedua ditolak dengan `NothingToWithdraw`, dan saldo heir hanya bertambah satu kali.
- Uji perusakan M01 (menghapus baris yang me-nol-kan bagian) tertangkap oleh test ini.

**Yang tidak dibuktikan test.**

- Proyek ini tidak memuat kontrak penyerang yang memanggil ulang kontrak saat menerima ETH. Akibatnya, mutasi M02 (membalik urutan CEI) dan M03 (menghapus `nonReentrant`) **tidak tertangkap** oleh test mana pun. Rinciannya ada di [MUTATION.md](MUTATION.md).
- Test membuktikan bahwa bagian heir di-nol-kan, tetapi tidak membuktikan *kapan*, sebelum atau sesudah ETH dikirim.
- Perlindungan reentrancy pada dua baris ini dijaga lewat tinjauan kode dan komentar NatSpec, bukan lewat test otomatis.
- Kolom "bukti" di SPEC.md menyebut test kontrak penyerang terhadap versi rentan. Test itu sengaja tidak dibuat di proyek ini.

### Ancaman 2: Satu heir memblokir pembagian (DoS)

**Mitigasi.** Pull payment: `finalizeClaim` hanya mencatat bagian setiap heir dan tidak mengirim ETH. Setiap heir menarik sendiri lewat `withdrawInheritance`. Hasil setiap `call` dicek, dan kegagalan menghasilkan `TransferFailed`.

**Bukti.**

- [S] `test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected`:
  - heir berupa kontrak yang menolak ETH hanya menggagalkan penarikannya sendiri;
  - catatan bagiannya (3 ETH) tetap utuh;
  - dua heir lain tetap menerima 5 ETH dan 2 ETH.
- [S] `test_RevertWhen_OwnerRejectsEth`: jika owner menolak ETH, `withdraw` dibatalkan seluruhnya dan saldo vault tetap utuh.
- Uji perusakan M04 dan M05 (menghapus pemeriksaan hasil `call`) tertangkap oleh dua test ini.

**Yang tidak dibuktikan test.** SPEC.md menyebut perbandingan versi push dengan versi pull. Versi push tidak dibuat. Test hanya membuktikan bahwa versi pull di kontrak ini tidak bisa diblokir oleh satu heir.

### Ancaman 3: Akses tanpa izin

**Mitigasi.**

- Modifier peran pada setiap fungsi yang dibatasi: `onlyOwner`, `onlyGuardian`, `onlyHeir`, `onlyHeirOrGuardian`.
- Semua fungsi dan state variable punya visibilitas eksplisit.
- `updateHeirs` menghapus tanda `isHeir` milik daftar lama.

**Bukti.**

- [S] `testFuzz_RevertWhen_NonOwnerCallsOwnerFunctions`: 1000 alamat acak selain owner. Semuanya ditolak dengan `NotOwner` di `withdraw`, `checkIn`, `updateHeirs`, dan `cancelClaim`.
- [S] `test_RevertWhen_HeirApproves`, `test_RevertWhen_OwnerApproves`, `test_RevertWhen_StrangerApproves`: hanya guardian yang bisa menyetujui.
- [S] `test_RevertWhen_StrangerStartsClaim`, `test_RevertWhen_OwnerStartsClaim`: hanya heir dan guardian yang bisa memulai klaim.
- [S] `test_RevertWhen_GuardianWithdrawsInheritance`, `test_RevertWhen_OwnerWithdrawsInheritance`, `test_RevertWhen_StrangerWithdrawsInheritance`: hanya heir yang bisa menarik warisan.
- [S] `test_UpdateHeirs_RemovedHeirCannotStartClaim`: heir yang dikeluarkan kehilangan perannya.
- [U] Jalur gagal per peran untuk setiap fungsi owner, misalnya:
  - `test_RevertWhen_HeirWithdraws`, `test_RevertWhen_GuardianWithdraws`;
  - `test_RevertWhen_HeirChecksIn`, `test_RevertWhen_GuardianChecksIn`;
  - `test_RevertWhen_HeirUpdatesHeirs`, `test_RevertWhen_GuardianUpdatesHeirs`.
- [U] Validasi peran saat deploy:
  - `test_RevertWhen_OwnerIsHeir`, `test_RevertWhen_OwnerIsGuardian`;
  - `test_RevertWhen_GuardianIsAlsoHeir`;
  - `test_RevertWhen_DuplicateHeir`, `test_RevertWhen_DuplicateGuardian`;
  - `test_RevertWhen_HeirIsZeroAddress`, `test_RevertWhen_GuardianIsZeroAddress`.
- Uji perusakan M06, M07, M08, M13 (menghapus modifier peran) semuanya tertangkap.

### Ancaman 4: Klaim keliru saat pemilik masih hidup

**Mitigasi.** Empat lapis:

1. Masa tidak aktif harus terlewati.
2. Persetujuan guardian harus mencapai threshold.
3. Timelock harus terlewati.
4. Owner bisa `cancelClaim` kapan saja selama `Claiming`.

Setoran dari selain owner tidak dihitung sebagai check-in, sehingga pihak lain tidak bisa memalsukan tanda "pemilik masih aktif".

**Bukti.**

- [S] `test_RevertWhen_StartClaimBeforeInactivityEnds`: ditolak dengan `OwnerStillActive`.
- [S] `test_RevertWhen_StartClaimAfterOwnerCheckedIn`: check-in menghitung ulang masa tidak aktif.
- [S] `test_Deposit_ByStrangerDoesNotCheckIn`.
- [S] `test_RevertWhen_FinalizeWithoutApprovals`, `test_RevertWhen_FinalizeBeforeThreshold`: ditolak dengan `NotEnoughApprovals`.
- [S] `test_RevertWhen_FinalizeBeforeTimelock`: ditolak dengan `TimelockNotExpired`.
- [S] `test_FinalizeClaim_ByAnyoneAtUnlockTime`: klaim bisa difinalkan tepat di detik `unlockTime`, oleh alamat luar sekalipun. Bersama test sebelumnya, ini menunjukkan batas waktunya tepat.
- [S] `test_CancelClaim_DuringTimelockBlocksFinalize`: pembatalan di tengah timelock mencegah dana cair.
- [S] `test_RevertWhen_HeirCancelsClaim`, `test_RevertWhen_GuardianCancelsClaim`: hanya owner yang bisa membatalkan.
- Uji perusakan M09–M13 tertangkap. Termasuk M12, yang mengubah `<` menjadi `<=` pada batas timelock.

### Ancaman 5: Persetujuan ganda atau persetujuan lama dipakai ulang

**Mitigasi.** Persetujuan disimpan di `hasApproved[claimId][guardian]`. Setiap klaim baru memakai `claimId` baru, sehingga catatan persetujuan klaim lama tidak terbaca lagi.

**Bukti.**

- [S] `test_RevertWhen_GuardianApprovesTwice`: ditolak dengan `AlreadyApproved`.
- [S] `test_CancelClaim_OldApprovalsDoNotCarryOver`: persetujuan dari klaim yang dibatalkan tidak terbawa ke klaim berikutnya, dan klaim baru tidak bisa final dengan persetujuan lama.
- [U] `test_CancelClaim_ReturnsToActiveAndChecksIn`: hitungan persetujuan kembali 0 setelah pembatalan.
- Uji perusakan M14 dan M15 tertangkap test keamanan. M16 hanya tertangkap test fungsional; penjelasannya ada di MUTATION.md.

### Ancaman 6: Manipulasi `block.timestamp`

**Mitigasi.** Semua periode minimal 1 hari (`MIN_PERIOD`). Pembahasan lengkapnya ada di [bagian 2](#2-kenapa-blocktimestamp-aman-di-konteks-ini). Sejak tahap 7, periode juga dibatasi maksimal 3650 hari (`MAX_PERIOD`); lihat temuan L-1 di bawah.

**Bukti.**

- [S] `test_RevertWhen_InactivityPeriodBelowOneDay`, `test_RevertWhen_TimelockPeriodBelowOneDay`: periode di bawah 1 hari ditolak dengan `PeriodTooShort`.
- [U] `test_Constructor_AcceptsPeriodsOfExactlyOneDay`.
- Uji perusakan M17 (menghapus batas minimal) tertangkap.

Test hanya membuktikan bahwa batas 1 hari ditegakkan. Bahwa batas itu *cukup* adalah analisis, bukan hasil test.

### Ancaman 7: Pembulatan porsi

**Mitigasi.** Porsi dalam basis point dengan total tepat 10000. Sisa pembulatan diberikan ke heir terakhir.

**Bukti.**

- [S] `test_WithdrawInheritance_RoundingRemainderGoesToLastHeir`: saldo 1 ETH + 7 wei dengan porsi 3333/3333/3334. Heir terakhir menerima sisa, dan saldo vault menjadi 0 setelah semua heir menarik.
- [S] `testFuzz_SharesAlwaysAddUpToSnapshot`: 1000 kombinasi acak. Saldo 0 sampai 1 miliar ETH, 1–10 heir, porsi acak yang valid. Test ini memeriksa:
  - invariant 1: total yang ditarik tidak pernah melebihi snapshot;
  - invariant 2: setelah semua heir menarik, total tepat sama dengan snapshot dan saldo vault 0.
- [U] `test_RevertWhen_SharesSumBelow10000`, `test_RevertWhen_SharesSumAbove10000`, `test_RevertWhen_HeirShareIsZero`.
- Uji perusakan M18 tertangkap.

### Ancaman 8: Gas DoS karena daftar terlalu panjang

**Mitigasi.** Maksimal 10 heir dan 10 guardian. Batas ini dicek di constructor dan `updateHeirs`, sehingga loop di `finalizeClaim` dan `updateHeirs` selalu pendek.

**Bukti.**

- [S] `test_RevertWhen_MoreThanTenHeirs`, `test_RevertWhen_MoreThanTenGuardians`, `test_RevertWhen_UpdateHeirsWithMoreThanTenHeirs`.
- [U] `test_Constructor_AcceptsTenHeirsAndTenGuardians`: batas atas tepat 10 diterima.
- Uji perusakan M19 dan M20 tertangkap.

### Ancaman 9: ETH dikirim setelah `Distributed`

**Mitigasi.** `receive` dan `deposit` memakai `inState(State.Active)`.

**Bukti.**

- [S] `test_RevertWhen_DepositAfterDistributed`, `test_RevertWhen_PlainTransferAfterDistributed`.
- [U] `test_RevertWhen_DepositDuringClaiming`, `test_RevertWhen_PlainTransferDuringClaiming`.
- Uji perusakan M21 dan M22 tertangkap.

Mitigasi ini hanya berlaku untuk ETH yang masuk lewat `receive` atau `deposit`. ETH yang dipaksa masuk tetap mungkin; lihat [bagian 3](#3-risiko-yang-diterima).

### Tambahan dari review tahap 7: periode raksasa (temuan L-1)

**Ancaman.** Dulu tidak ada batas atas periode. Jika deployer mengisi angka raksasa, penjumlahan waktu meluap:
- `getStatus` dan `startClaim` selalu gagal;
- `approveClaim` yang mencapai threshold selalu gagal, sehingga klaim tertahan dan dana terkunci.

Rinciannya dan bukti sebelum perbaikan ada di [REVIEW.md](REVIEW.md).

**Mitigasi.** `MAX_PERIOD = 3650 days`, dicek di constructor. Periode yang lebih panjang ditolak dengan `PeriodTooLong`.

**Bukti.**

- [S] `test_RevertWhen_InactivityPeriodAboveTenYears`, `test_RevertWhen_TimelockPeriodAboveTenYears`, `test_RevertWhen_PeriodsAreUint256Max`.
- [S] `test_MaxPeriods_ClaimFlowCompletesWithoutOverflow`: dengan periode terpanjang yang diizinkan, `getStatus` bekerja dan klaim selesai sampai `Distributed`.
- [U] `test_Constructor_AcceptsPeriodsOfExactlyTenYears`.
- Uji perusakan M23 (menghapus pemeriksaan batas atas) tertangkap oleh 3 test.

### Tambahan di luar tabel SPEC: akun Anvil di jaringan publik

Private key akun bawaan Anvil diketahui semua orang. Jika salah satunya dipakai sebagai heir atau guardian di jaringan publik, siapa pun bisa memakai peran itu.

**Mitigasi.**

- `script/Deploy.s.sol` menolak akun Anvil di luar chainId 31337 dengan error `AnvilAccountOnPublicChain`.
- `script/SeedDemo.s.sol` hanya berjalan di Anvil.
- UI menolak bekerja jika chainId bukan 31337.

**Bukti.**

- [D] `test_RevertWhen_DeployOnPublicChainWithAnvilHeir`, `test_RevertWhen_DeployOnPublicChainWithAnvilGuardian`.
- [D] `test_RevertWhen_SeedDemoRunsOutsideAnvil`.
- [D] `test_Deploy_OnAnvilAllowsAnvilAccounts`.

Penolakan di UI diperiksa manual di browser saat tahap 5, dengan Anvil di chainId 1337. Tidak ada test otomatis untuk UI.

## 2. Kenapa `block.timestamp` aman di konteks ini

Kontrak memakai `block.timestamp` di tiga tempat:

- `lastCheckIn`;
- syarat `startClaim` (`block.timestamp < lastCheckIn + inactivityPeriod` berarti ditolak);
- `unlockTime` dan syarat `finalizeClaim`.

`block.timestamp` ditentukan oleh pembuat blok, bukan oleh jam yang disepakati semua orang, sehingga ada kekhawatiran pembuat blok bisa "memalsukan" waktu. Alasan risiko ini dapat diterima di sini:

1. **Ruang geraknya kecil.** Di Ethereum sejak *The Merge* (proof of stake), waktu dibagi menjadi slot 12 detik, dan timestamp setiap blok harus sama dengan waktu slotnya. Pembuat blok tidak bebas memilih angka. Paling jauh ia bisa melewatkan slotnya sehingga transaksi masuk di slot berikutnya, yang berarti terlambat beberapa kali 12 detik. Di era proof of work, pergeserannya pun dalam hitungan detik.
2. **Skala waktu kontrak jauh lebih besar.** Periode terpendek yang diizinkan adalah 1 hari (86.400 detik), dan contoh demo memakai 180 hari dan 7 hari. Pergeseran 12 detik pada periode 1 hari hanya sekitar 0,014%.
3. **Tidak ada yang bisa dimenangkan dari selisih detik.** Kontrak tidak punya undian, lelang, atau harga yang bergantung pada detik tertentu. Pembuat blok yang menggeser waktu paling-paling membuat klaim bisa dimulai atau difinalkan beberapa detik lebih awal atau lebih lambat. Itu tidak melewati satu pun dari empat lapis perlindungan di Ancaman 4.
4. **Arah manipulasinya pun terbatas.** Untuk mempercepat klaim sampai bermakna, waktu harus dimajukan berhari-hari. Itu tidak mungkin di jaringan publik.

Pilihan lain, misalnya `block.number`, tidak lebih baik. Waktu per blok bisa berubah karena slot kosong atau perubahan protokol, sehingga "180 hari" dalam jumlah blok justru menjadi kurang tepat.

Catatan:

- Poin 1 sampai 4 adalah **analisis**, bukan hasil test.
- Yang dibuktikan test hanyalah batas minimal 1 hari (Ancaman 6) dan batas tepat di `unlockTime` (`test_FinalizeClaim_ByAnyoneAtUnlockTime`).
- Di Anvil, waktu sengaja dimajukan dengan `evm_increaseTime`. Ini fitur jaringan lokal untuk demo, bukan celah kontrak. UI menolak fitur ini di jaringan selain chainId 31337.

## 3. Risiko yang diterima

Risiko berikut tercantum di SPEC.md bagian 7 sebagai risiko yang tidak dimitigasi penuh. Kolom "Yang ada di kontrak" menjelaskan seberapa jauh risikonya dikurangi.

| Risiko | Akibat | Yang ada di kontrak | Didukung test? |
|---|---|---|---|
| Guardian berkolusi dengan heir | Dana bisa cair jika pemilik yang masih hidup tidak membatalkan selama timelock | Guardian tidak boleh sekaligus heir. Klaim butuh threshold, dan owner bisa membatalkan. | Ya, sebagian: `test_RevertWhen_GuardianIsAlsoHeir` [U] dan `test_CancelClaim_DuringTimelockBlocksFinalize` [S]. Kolusi itu sendiri tidak bisa dicegah kode. |
| Guardian tidak responsif atau kehilangan kunci | Klaim tertahan di `Claiming` jika persetujuan tidak mencapai threshold | Skema m-of-n, sehingga tidak semua guardian harus aktif | Test hanya menunjukkan finalize ditolak tanpa persetujuan cukup (`test_RevertWhen_FinalizeBeforeThreshold` [S]). Tidak ada jalan keluar dari kemacetan; lihat README bagian Keterbatasan. |
| Pemilik lupa check-in | Klaim bisa dimulai padahal pemilik masih hidup | Timelock dan `cancelClaim`. Pembatalan dihitung sebagai check-in. | Ya: `test_CancelClaim_DuringTimelockBlocksFinalize` [S], `test_CancelClaim_ReturnsToActiveAndChecksIn` [U] |
| ETH dipaksa masuk setelah `Distributed` (misalnya lewat `selfdestruct` dari kontrak lain) | ETH itu terkunci selamanya, karena snapshot sudah diambil dan tidak ada fungsi untuk menariknya | Hanya `receive` dan `deposit` yang ditolak | Penolakan `receive` dan `deposit` diuji (Ancaman 9). Pemaksaan lewat `selfdestruct` tidak diuji. |
| Data heir, guardian, dan porsi terlihat publik | Siapa pun bisa melihat siapa ahli waris dan berapa bagiannya | Tidak ada; ini sifat blockchain publik | Tidak relevan untuk test |
| Owner tidak bisa mengganti guardian | Jika guardian harus diganti, owner perlu menarik dana dan men-deploy vault baru | Tidak ada fungsi penggantian guardian (disederhanakan) | Tidak ada fungsi, jadi tidak ada test |
| Heir tidak bisa menerima ETH (temuan L-2, tahap 7) | Bagian heir itu terkunci selamanya | Pull payment, jadi heir lain tidak terdampak | Ya: `test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected` [S] menunjukkan bagiannya tetap tercatat tanpa jalan keluar, sementara heir lain bisa menarik |
| Heir kehilangan private key (tahap 7) | Bagian heir itu terkunci selamanya | Tidak ada; tidak bisa dicegah tanpa pihak ketiga yang dipercaya | Tidak relevan untuk test |

## 4. Batasan analisis ini

- Analisis dan test ini dibuat oleh pengembang proyek sendiri, bukan audit independen.
- Fuzz test memakai 1000 run per test (`foundry.toml`), jadi ini bukan pembuktian formal.
- Kontrak belum pernah di-deploy ke jaringan publik.
