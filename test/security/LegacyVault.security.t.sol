// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LegacyVault} from "../../src/LegacyVault.sol";
import {LegacyVaultFixture, RejectingHeir, RejectingOwner} from "../utils/LegacyVaultFixture.sol";

/// @title Test keamanan LegacyVault
/// @notice Dikelompokkan per baris tabel model ancaman di SPEC.md bagian 7.
///         Setiap kelompok menyebut ancaman, mitigasinya, dan test yang membuktikannya.
contract LegacyVaultSecurityTest is LegacyVaultFixture {
    // =====================================================================
    // Ancaman 1. Reentrancy saat penarikan
    // Mitigasi: Checks-Effects-Interactions (bagian di-nol-kan sebelum ETH dikirim) + nonReentrant.
    // Batasan: tanpa penerima ETH yang memanggil ulang kontrak, test hanya bisa membuktikan bahwa
    // bagian di-nol-kan (tidak bisa ditarik dua kali). Urutan CEI dan nonReentrant tidak teramati
    // langsung di sini; lihat docs/MUTATION.md untuk hasil uji perusakannya.
    // =====================================================================

    function test_RevertWhen_HeirWithdrawsInheritanceTwice() public {
        _runToDistributed(vault);
        vm.prank(alice);
        vault.withdrawInheritance();

        vm.expectRevert(LegacyVault.NothingToWithdraw.selector);
        vm.prank(alice);
        vault.withdrawInheritance();

        assertEq(alice.balance, 5 ether);
    }

    // =====================================================================
    // Ancaman 2. Satu heir memblokir pembagian (DoS)
    // Mitigasi: pull payment. finalizeClaim tidak mengirim ETH; setiap heir menarik sendiri,
    // dan hasil setiap call dicek (TransferFailed) supaya kegagalan tidak diam-diam.
    // =====================================================================

    /// @dev Heir yang menolak ETH hanya menggagalkan penarikannya sendiri; heir lain tetap bisa menarik.
    function test_RevertWhen_HeirRejectsEth_OtherHeirsUnaffected() public {
        RejectingHeir rejecting = new RejectingHeir();
        address[] memory heirs = _defaultHeirs();
        heirs[1] = address(rejecting);
        LegacyVault withRejecter =
            _deploy(heirs, _defaultShares(), _defaultGuardians(), THRESHOLD, INACTIVITY, TIMELOCK);
        _runToDistributed(withRejecter);

        vm.expectRevert(LegacyVault.TransferFailed.selector);
        rejecting.withdrawFrom(withRejecter);
        assertEq(withRejecter.inheritanceOf(address(rejecting)), 3 ether);

        vm.prank(alice);
        withRejecter.withdrawInheritance();
        vm.prank(carol);
        withRejecter.withdrawInheritance();
        assertEq(alice.balance, 5 ether);
        assertEq(carol.balance, 2 ether);
    }

    function test_RevertWhen_OwnerRejectsEth() public {
        RejectingOwner rejecting = new RejectingOwner();
        LegacyVault ownedByContract = rejecting.deployVault(
            _defaultHeirs(), _defaultShares(), _defaultGuardians(), THRESHOLD, INACTIVITY, TIMELOCK
        );
        vm.prank(stranger);
        ownedByContract.deposit{value: 1 ether}();

        vm.expectRevert(LegacyVault.TransferFailed.selector);
        rejecting.withdrawFrom(ownedByContract, 1 ether);

        // Karena seluruh transaksi dibatalkan, saldo tetap utuh.
        assertEq(address(ownedByContract).balance, 1 ether);
    }

    // =====================================================================
    // Ancaman 3. Akses tanpa izin
    // Mitigasi: modifier peran per fungsi (onlyOwner, onlyGuardian, onlyHeir, onlyHeirOrGuardian).
    // =====================================================================

    /// @dev Untuk alamat acak mana pun selain owner, semua fungsi owner harus menolak.
    function testFuzz_RevertWhen_NonOwnerCallsOwnerFunctions(address caller) public {
        vm.assume(caller != owner);

        vm.startPrank(caller);
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vault.withdraw(1);
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vault.checkIn();
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vault.updateHeirs(_defaultHeirs(), _defaultShares());
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vault.cancelClaim();
        vm.stopPrank();
    }

    function test_RevertWhen_HeirApproves() public {
        _startClaim();
        vm.expectRevert(LegacyVault.NotGuardian.selector);
        vm.prank(alice);
        vault.approveClaim();
    }

    function test_RevertWhen_OwnerApproves() public {
        _startClaim();
        vm.expectRevert(LegacyVault.NotGuardian.selector);
        vm.prank(owner);
        vault.approveClaim();
    }

    function test_RevertWhen_StrangerApproves() public {
        _startClaim();
        vm.expectRevert(LegacyVault.NotGuardian.selector);
        vm.prank(stranger);
        vault.approveClaim();
    }

    function test_RevertWhen_StrangerStartsClaim() public {
        _warpPastInactivity(vault);
        vm.expectRevert(LegacyVault.NotHeirOrGuardian.selector);
        vm.prank(stranger);
        vault.startClaim();
    }

    function test_RevertWhen_OwnerStartsClaim() public {
        _warpPastInactivity(vault);
        vm.expectRevert(LegacyVault.NotHeirOrGuardian.selector);
        vm.prank(owner);
        vault.startClaim();
    }

    function test_RevertWhen_GuardianWithdrawsInheritance() public {
        _runToDistributed(vault);
        vm.expectRevert(LegacyVault.NotHeir.selector);
        vm.prank(guardian1);
        vault.withdrawInheritance();
    }

    function test_RevertWhen_OwnerWithdrawsInheritance() public {
        _runToDistributed(vault);
        vm.expectRevert(LegacyVault.NotHeir.selector);
        vm.prank(owner);
        vault.withdrawInheritance();
    }

    function test_RevertWhen_StrangerWithdrawsInheritance() public {
        _runToDistributed(vault);
        vm.expectRevert(LegacyVault.NotHeir.selector);
        vm.prank(stranger);
        vault.withdrawInheritance();
    }

    function test_UpdateHeirs_RemovedHeirCannotStartClaim() public {
        address[] memory newHeirs = new address[](1);
        newHeirs[0] = bob;
        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000;

        vm.prank(owner);
        vault.updateHeirs(newHeirs, newShares);

        _warpPastInactivity(vault);
        vm.expectRevert(LegacyVault.NotHeirOrGuardian.selector);
        vm.prank(alice);
        vault.startClaim();
    }

    // =====================================================================
    // Ancaman 4. Klaim keliru saat pemilik masih hidup
    // Mitigasi: masa tidak aktif + persetujuan guardian + timelock + cancelClaim oleh owner.
    // =====================================================================

    function test_RevertWhen_StartClaimBeforeInactivityEnds() public {
        uint256 activeUntil = vault.lastCheckIn() + INACTIVITY;
        vm.warp(activeUntil - 1);

        vm.expectRevert(abi.encodeWithSelector(LegacyVault.OwnerStillActive.selector, activeUntil));
        vm.prank(alice);
        vault.startClaim();
    }

    /// @dev Check-in owner memundurkan batas, sehingga klaim yang tadinya boleh menjadi ditolak.
    function test_RevertWhen_StartClaimAfterOwnerCheckedIn() public {
        vm.warp(vm.getBlockTimestamp() + INACTIVITY - 1 days);
        vm.prank(owner);
        vault.checkIn();

        vm.warp(vm.getBlockTimestamp() + 2 days);
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.OwnerStillActive.selector, vault.lastCheckIn() + INACTIVITY));
        vm.prank(alice);
        vault.startClaim();
    }

    /// @dev Peran "salah" untuk deposit: siapa pun boleh menyetor, tetapi setoran bukan-owner
    ///      tidak boleh dianggap bukti owner masih aktif.
    function test_Deposit_ByStrangerDoesNotCheckIn() public {
        uint256 checkInBefore = vault.lastCheckIn();
        vm.warp(vm.getBlockTimestamp() + 10 days);

        vm.prank(stranger);
        vault.deposit{value: 1 ether}();

        assertEq(address(vault).balance, INITIAL_DEPOSIT + 1 ether);
        assertEq(vault.lastCheckIn(), checkInBefore);
    }

    function test_RevertWhen_FinalizeWithoutApprovals() public {
        _startClaim();
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.NotEnoughApprovals.selector, 0, THRESHOLD));
        vault.finalizeClaim();
    }

    function test_RevertWhen_FinalizeBeforeThreshold() public {
        _startClaim();
        _approve(guardian1);
        vm.warp(vm.getBlockTimestamp() + 365 days);

        vm.expectRevert(abi.encodeWithSelector(LegacyVault.NotEnoughApprovals.selector, 1, THRESHOLD));
        vault.finalizeClaim();
    }

    function test_RevertWhen_FinalizeBeforeTimelock() public {
        _startClaim();
        _approve(guardian1);
        _approve(guardian2);
        uint256 unlockAt = vault.unlockTime();
        vm.warp(unlockAt - 1);

        vm.expectRevert(abi.encodeWithSelector(LegacyVault.TimelockNotExpired.selector, unlockAt));
        vault.finalizeClaim();
    }

    function test_FinalizeClaim_ByAnyoneAtUnlockTime() public {
        _startClaim();
        _approve(guardian1);
        _approve(guardian2);
        vm.warp(vault.unlockTime());

        vm.expectEmit(address(vault));
        emit LegacyVault.ClaimFinalized(1, INITIAL_DEPOSIT);

        vm.prank(stranger);
        vault.finalizeClaim();

        assertEq(uint256(vault.state()), uint256(LegacyVault.State.Distributed));
        assertEq(vault.snapshot(), INITIAL_DEPOSIT);
        assertEq(vault.inheritanceOf(alice), 5 ether);
        assertEq(vault.inheritanceOf(bob), 3 ether);
        assertEq(vault.inheritanceOf(carol), 2 ether);
    }

    /// @dev Pemilik yang ternyata masih hidup bisa membatalkan di tengah timelock.
    function test_CancelClaim_DuringTimelockBlocksFinalize() public {
        _startClaim();
        _approve(guardian1);
        _approve(guardian2);
        uint256 unlockAt = vault.unlockTime();

        vm.warp(unlockAt - 1 days);
        vm.prank(owner);
        vault.cancelClaim();

        vm.warp(unlockAt + 1);
        vm.expectRevert(_invalidState(LegacyVault.State.Claiming, LegacyVault.State.Active));
        vault.finalizeClaim();

        // Klaim baru juga tidak bisa langsung dimulai karena cancel dihitung sebagai check-in.
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.OwnerStillActive.selector, vault.lastCheckIn() + INACTIVITY));
        vm.prank(alice);
        vault.startClaim();
    }

    function test_RevertWhen_HeirCancelsClaim() public {
        _startClaim();
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(alice);
        vault.cancelClaim();
    }

    function test_RevertWhen_GuardianCancelsClaim() public {
        _startClaim();
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(guardian1);
        vault.cancelClaim();
    }

    // =====================================================================
    // Ancaman 5. Persetujuan ganda / persetujuan lama dipakai ulang
    // Mitigasi: hasApproved[claimId][guardian]; klaim baru memakai claimId baru.
    // =====================================================================

    function test_RevertWhen_GuardianApprovesTwice() public {
        _startClaim();
        _approve(guardian1);

        vm.expectRevert(abi.encodeWithSelector(LegacyVault.AlreadyApproved.selector, 1));
        _approve(guardian1);

        assertEq(vault.approvalCount(), 1);
    }

    /// @dev Skenario utama invariant 6: approve -> cancel -> klaim baru -> persetujuan lama tidak terhitung.
    function test_CancelClaim_OldApprovalsDoNotCarryOver() public {
        _startClaim();
        _approve(guardian1);
        _approve(guardian2);
        assertEq(vault.approvalCount(), THRESHOLD);

        vm.prank(owner);
        vault.cancelClaim();

        _startClaim();
        assertEq(vault.claimId(), 2);
        assertEq(vault.approvalCount(), 0);
        assertFalse(vault.hasApproved(2, guardian1));
        assertFalse(vault.hasApproved(2, guardian2));
        // Catatan klaim lama masih ada, tetapi tidak dibaca lagi.
        assertTrue(vault.hasApproved(1, guardian1));

        // Walaupun sudah lama sekali, klaim baru belum bisa cair tanpa persetujuan baru.
        vm.warp(vm.getBlockTimestamp() + 365 days);
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.NotEnoughApprovals.selector, 0, THRESHOLD));
        vault.finalizeClaim();

        // Guardian yang sama boleh menyetujui lagi untuk klaim baru, dan hitungan mulai dari 1.
        _approve(guardian1);
        assertEq(vault.approvalCount(), 1);
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.NotEnoughApprovals.selector, 1, THRESHOLD));
        vault.finalizeClaim();
    }

    // =====================================================================
    // Ancaman 6. Manipulasi block.timestamp
    // Mitigasi: periode minimal 1 hari, sehingga pergeseran beberapa detik oleh validator tidak berarti.
    // =====================================================================

    function test_RevertWhen_InactivityPeriodBelowOneDay() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.PeriodTooShort.selector, 1 days - 1),
            _defaultHeirs(),
            _defaultShares(),
            _defaultGuardians(),
            THRESHOLD,
            1 days - 1,
            TIMELOCK
        );
    }

    function test_RevertWhen_TimelockPeriodBelowOneDay() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.PeriodTooShort.selector, 1 days - 1),
            _defaultHeirs(),
            _defaultShares(),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            1 days - 1
        );
    }

    // =====================================================================
    // Ancaman 7. Pembulatan porsi
    // Mitigasi: basis point dengan total tepat 10000; sisa pembulatan ke heir terakhir.
    // =====================================================================

    /// @dev Saldo yang tidak habis dibagi: sisa pembulatan jatuh ke heir terakhir, tidak ada wei tertinggal.
    function test_WithdrawInheritance_RoundingRemainderGoesToLastHeir() public {
        uint256[] memory shares = new uint256[](3);
        shares[0] = 3333;
        shares[1] = 3333;
        shares[2] = 3334;
        vm.prank(owner);
        LegacyVault odd = new LegacyVault{value: 1 ether + 7}(
            _defaultHeirs(), shares, _defaultGuardians(), THRESHOLD, INACTIVITY, TIMELOCK
        );

        _runToDistributed(odd);

        // Disimpan di variabel dulu supaya dihitung sebagai bilangan bulat (dibulatkan ke bawah),
        // bukan sebagai konstanta pecahan oleh compiler.
        uint256 total = 1 ether + 7;
        uint256 aliceShare = (total * 3333) / 10000;
        assertEq(odd.inheritanceOf(alice), aliceShare);
        assertEq(odd.inheritanceOf(bob), aliceShare);
        assertEq(odd.inheritanceOf(carol), total - 2 * aliceShare);
        // Bukti ada sisa pembulatan: bagian carol lebih besar dari hitungan bps murninya.
        assertGt(odd.inheritanceOf(carol), (total * 3334) / 10000);

        vm.prank(alice);
        odd.withdrawInheritance();
        vm.prank(bob);
        odd.withdrawInheritance();
        vm.prank(carol);
        odd.withdrawInheritance();
        assertEq(address(odd).balance, 0);
    }

    function testFuzz_SharesAlwaysAddUpToSnapshot(uint256 balance, uint256 heirCount, uint256 seed) public {
        heirCount = _bound(heirCount, 1, 10);
        balance = _bound(balance, 0, 1_000_000_000 ether);

        // Bangun porsi acak yang valid: setiap porsi >= 1 dan totalnya tepat 10000.
        address[] memory heirs = _makeAddrs("fuzzHeir", heirCount);
        uint256[] memory shares = new uint256[](heirCount);
        uint256 remaining = 10000;
        for (uint256 i = 0; i < heirCount - 1; i++) {
            uint256 slotsLeft = heirCount - 1 - i;
            uint256 share = _bound(uint256(keccak256(abi.encode(seed, i))), 1, remaining - slotsLeft);
            shares[i] = share;
            remaining -= share;
        }
        shares[heirCount - 1] = remaining;

        vm.deal(owner, balance);
        vm.prank(owner);
        LegacyVault fuzzVault =
            new LegacyVault{value: balance}(heirs, shares, _defaultGuardians(), THRESHOLD, INACTIVITY, TIMELOCK);
        _runToDistributed(fuzzVault);

        uint256 snapshot = fuzzVault.snapshot();
        assertEq(snapshot, balance);

        uint256 totalAllocated = 0;
        for (uint256 i = 0; i < heirCount; i++) {
            uint256 allocated = fuzzVault.inheritanceOf(heirs[i]);
            if (i < heirCount - 1) {
                assertEq(allocated, (balance * shares[i]) / 10000);
            }
            totalAllocated += allocated;
        }
        // Invariant 2 (dari sisi pencatatan): seluruh snapshot terbagi habis.
        assertEq(totalAllocated, snapshot);

        uint256 totalWithdrawn = 0;
        for (uint256 i = 0; i < heirCount; i++) {
            if (fuzzVault.inheritanceOf(heirs[i]) == 0) continue;
            vm.prank(heirs[i]);
            fuzzVault.withdrawInheritance();
            totalWithdrawn += heirs[i].balance;
            // Invariant 1: total yang sudah ditarik tidak pernah melebihi snapshot.
            assertLe(totalWithdrawn, snapshot);
        }
        // Invariant 2: setelah semua heir menarik, total tepat = snapshot dan tidak ada wei tersisa.
        assertEq(totalWithdrawn, snapshot);
        assertEq(address(fuzzVault).balance, 0);
    }

    // =====================================================================
    // Ancaman 8. Gas DoS karena daftar terlalu panjang
    // Mitigasi: batas 10 heir dan 10 guardian, dicek di constructor dan updateHeirs.
    // =====================================================================

    function test_RevertWhen_MoreThanTenHeirs() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidHeirCount.selector, 11),
            _makeAddrs("heir", 11),
            _equalShares(11),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_MoreThanTenGuardians() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidGuardianCount.selector, 11),
            _defaultHeirs(),
            _defaultShares(),
            _makeAddrs("guard", 11),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_UpdateHeirsWithMoreThanTenHeirs() public {
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.InvalidHeirCount.selector, 11));
        vm.prank(owner);
        vault.updateHeirs(_makeAddrs("heir", 11), _equalShares(11));
    }

    // =====================================================================
    // Ancaman 9. ETH dikirim setelah Distributed
    // Mitigasi: receive dan deposit memakai inState(State.Active).
    // =====================================================================

    function test_RevertWhen_DepositAfterDistributed() public {
        _runToDistributed(vault);
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Distributed));
        vm.prank(stranger);
        vault.deposit{value: 1 ether}();
    }

    function test_RevertWhen_PlainTransferAfterDistributed() public {
        _runToDistributed(vault);
        vm.prank(stranger);
        (bool success, bytes memory returnData) = address(vault).call{value: 1 ether}("");
        assertFalse(success);
        assertEq(returnData, _invalidState(LegacyVault.State.Active, LegacyVault.State.Distributed));
    }
}
