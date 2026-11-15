// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {LegacyVault} from "../src/LegacyVault.sol";

/// @dev Kontrak tanpa receive/fallback, sehingga setiap kiriman ETH kepadanya gagal.
///      Dipakai untuk membuktikan kontrak mengecek hasil `call` dan pull payment tahan DoS.
contract RejectingHeir {
    function withdrawFrom(LegacyVault vault) external {
        vault.withdrawInheritance();
    }
}

/// @dev Owner berupa kontrak yang menolak ETH, untuk menguji jalur TransferFailed di withdraw.
contract RejectingOwner {
    function deployVault(
        address[] memory heirs,
        uint256[] memory sharesBps,
        address[] memory guardians,
        uint256 threshold,
        uint256 inactivityPeriod,
        uint256 timelockPeriod
    ) external returns (LegacyVault) {
        return new LegacyVault(heirs, sharesBps, guardians, threshold, inactivityPeriod, timelockPeriod);
    }

    function withdrawFrom(LegacyVault vault, uint256 amount) external {
        vault.withdraw(amount);
    }
}

contract LegacyVaultTest is Test {
    LegacyVault internal vault;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal guardian1 = makeAddr("guardian1");
    address internal guardian2 = makeAddr("guardian2");
    address internal guardian3 = makeAddr("guardian3");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant INITIAL_DEPOSIT = 10 ether;
    uint256 internal constant THRESHOLD = 2;
    uint256 internal constant INACTIVITY = 180 days;
    uint256 internal constant TIMELOCK = 7 days;

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(stranger, 100 ether);
        vault = _deploy(_defaultHeirs(), _defaultShares(), _defaultGuardians(), THRESHOLD, INACTIVITY, TIMELOCK);
    }

    // =====================================================================
    // Helper
    // =====================================================================

    function _defaultHeirs() internal view returns (address[] memory heirs) {
        heirs = new address[](3);
        heirs[0] = alice;
        heirs[1] = bob;
        heirs[2] = carol;
    }

    /// @dev 50% / 30% / 20%
    function _defaultShares() internal pure returns (uint256[] memory shares) {
        shares = new uint256[](3);
        shares[0] = 5000;
        shares[1] = 3000;
        shares[2] = 2000;
    }

    function _defaultGuardians() internal view returns (address[] memory guardians) {
        guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;
    }

    function _makeAddrs(string memory prefix, uint256 count) internal returns (address[] memory list) {
        list = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            list[i] = makeAddr(string.concat(prefix, vm.toString(i)));
        }
    }

    function _equalShares(uint256 count) internal pure returns (uint256[] memory shares) {
        shares = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            shares[i] = 10000 / count;
        }
        shares[count - 1] += 10000 % count;
    }

    function _deploy(
        address[] memory heirs,
        uint256[] memory shares,
        address[] memory guardians,
        uint256 threshold,
        uint256 inactivity,
        uint256 timelock
    ) internal returns (LegacyVault) {
        vm.prank(owner);
        return new LegacyVault{value: INITIAL_DEPOSIT}(heirs, shares, guardians, threshold, inactivity, timelock);
    }

    function _expectDeployRevert(
        bytes memory expectedError,
        address[] memory heirs,
        uint256[] memory shares,
        address[] memory guardians,
        uint256 threshold,
        uint256 inactivity,
        uint256 timelock
    ) internal {
        vm.expectRevert(expectedError);
        vm.prank(owner);
        new LegacyVault(heirs, shares, guardians, threshold, inactivity, timelock);
    }

    function _invalidState(LegacyVault.State expected, LegacyVault.State current) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(LegacyVault.InvalidState.selector, expected, current);
    }

    function _warpPastInactivity(LegacyVault target) internal {
        vm.warp(target.lastCheckIn() + target.inactivityPeriod());
    }

    function _startClaim() internal {
        _warpPastInactivity(vault);
        vm.prank(alice);
        vault.startClaim();
    }

    function _approve(address guardian) internal {
        vm.prank(guardian);
        vault.approveClaim();
    }

    /// @dev Membawa vault apa pun dari Active sampai Distributed dengan guardian bawaan.
    function _runToDistributed(LegacyVault target) internal {
        _warpPastInactivity(target);
        vm.prank(guardian1);
        target.startClaim();
        vm.prank(guardian1);
        target.approveClaim();
        vm.prank(guardian2);
        target.approveClaim();
        vm.warp(target.unlockTime());
        target.finalizeClaim();
    }

    // =====================================================================
    // 1. Constructor
    // =====================================================================

    function test_Constructor_SetsConfiguration() public view {
        assertEq(vault.owner(), owner);
        assertEq(vault.threshold(), THRESHOLD);
        assertEq(vault.inactivityPeriod(), INACTIVITY);
        assertEq(vault.timelockPeriod(), TIMELOCK);
        assertEq(uint256(vault.state()), uint256(LegacyVault.State.Active));
        assertEq(vault.lastCheckIn(), vm.getBlockTimestamp());
        assertEq(vault.claimId(), 0);
        assertEq(address(vault).balance, INITIAL_DEPOSIT);

        assertEq(vault.heirs(0), alice);
        assertEq(vault.heirs(1), bob);
        assertEq(vault.heirs(2), carol);
        assertEq(vault.sharesBps(0), 5000);
        assertEq(vault.sharesBps(1), 3000);
        assertEq(vault.sharesBps(2), 2000);
        assertEq(vault.guardians(0), guardian1);
        assertEq(vault.guardians(2), guardian3);

        assertTrue(vault.isHeir(alice));
        assertTrue(vault.isGuardian(guardian1));
        assertFalse(vault.isHeir(guardian1));
        assertFalse(vault.isGuardian(alice));
        assertFalse(vault.isHeir(owner));
    }

    function test_Constructor_EmitsDepositedWhenFunded() public {
        vm.expectEmit();
        emit LegacyVault.Deposited(owner, INITIAL_DEPOSIT);
        _deploy(_defaultHeirs(), _defaultShares(), _defaultGuardians(), THRESHOLD, INACTIVITY, TIMELOCK);
    }

    function test_Constructor_AcceptsTenHeirsAndTenGuardians() public {
        address[] memory heirs = _makeAddrs("heir", 10);
        address[] memory guardians = _makeAddrs("guard", 10);
        LegacyVault big = _deploy(heirs, _equalShares(10), guardians, 10, INACTIVITY, TIMELOCK);
        assertEq(big.heirs(9), heirs[9]);
        assertEq(big.guardians(9), guardians[9]);
    }

    function test_Constructor_AcceptsPeriodsOfExactlyOneDay() public {
        LegacyVault minimal = _deploy(_defaultHeirs(), _defaultShares(), _defaultGuardians(), THRESHOLD, 1 days, 1 days);
        assertEq(minimal.inactivityPeriod(), 1 days);
        assertEq(minimal.timelockPeriod(), 1 days);
    }

    function test_RevertWhen_SharesSumBelow10000() public {
        uint256[] memory shares = _defaultShares();
        shares[2] = 1999;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidSharesTotal.selector, 9999),
            _defaultHeirs(),
            shares,
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_SharesSumAbove10000() public {
        uint256[] memory shares = _defaultShares();
        shares[2] = 2001;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidSharesTotal.selector, 10001),
            _defaultHeirs(),
            shares,
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_HeirShareIsZero() public {
        uint256[] memory shares = _defaultShares();
        shares[1] = 0;
        shares[0] = 8000;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.ZeroShare.selector, bob),
            _defaultHeirs(),
            shares,
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_HeirAndShareLengthsDiffer() public {
        uint256[] memory shares = new uint256[](2);
        shares[0] = 5000;
        shares[1] = 5000;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.LengthMismatch.selector, 3, 2),
            _defaultHeirs(),
            shares,
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_HeirIsZeroAddress() public {
        address[] memory heirs = _defaultHeirs();
        heirs[1] = address(0);
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.ZeroAddress.selector),
            heirs,
            _defaultShares(),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_GuardianIsZeroAddress() public {
        address[] memory guardians = _defaultGuardians();
        guardians[0] = address(0);
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.ZeroAddress.selector),
            _defaultHeirs(),
            _defaultShares(),
            guardians,
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_DuplicateHeir() public {
        address[] memory heirs = _defaultHeirs();
        heirs[2] = alice;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.DuplicateAddress.selector, alice),
            heirs,
            _defaultShares(),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_DuplicateGuardian() public {
        address[] memory guardians = _defaultGuardians();
        guardians[1] = guardian1;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.DuplicateAddress.selector, guardian1),
            _defaultHeirs(),
            _defaultShares(),
            guardians,
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_OwnerIsHeir() public {
        address[] memory heirs = _defaultHeirs();
        heirs[0] = owner;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.OwnerCannotHaveRole.selector),
            heirs,
            _defaultShares(),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_OwnerIsGuardian() public {
        address[] memory guardians = _defaultGuardians();
        guardians[2] = owner;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.OwnerCannotHaveRole.selector),
            _defaultHeirs(),
            _defaultShares(),
            guardians,
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_GuardianIsAlsoHeir() public {
        address[] memory heirs = _defaultHeirs();
        heirs[2] = guardian2;
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.GuardianCannotBeHeir.selector, guardian2),
            heirs,
            _defaultShares(),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_ThresholdIsZero() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidThreshold.selector, 0, 3),
            _defaultHeirs(),
            _defaultShares(),
            _defaultGuardians(),
            0,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_ThresholdExceedsGuardianCount() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidThreshold.selector, 4, 3),
            _defaultHeirs(),
            _defaultShares(),
            _defaultGuardians(),
            4,
            INACTIVITY,
            TIMELOCK
        );
    }

    /// @dev Tanpa guardian, threshold apa pun pasti > 0 = jumlah guardian, jadi InvalidThreshold yang muncul.
    function test_RevertWhen_NoGuardians() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidThreshold.selector, 1, 0),
            _defaultHeirs(),
            _defaultShares(),
            new address[](0),
            1,
            INACTIVITY,
            TIMELOCK
        );
    }

    function test_RevertWhen_NoHeirs() public {
        _expectDeployRevert(
            abi.encodeWithSelector(LegacyVault.InvalidHeirCount.selector, 0),
            new address[](0),
            new uint256[](0),
            _defaultGuardians(),
            THRESHOLD,
            INACTIVITY,
            TIMELOCK
        );
    }

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
    // 2. Fase Active: deposit, withdraw, checkIn, updateHeirs
    // =====================================================================

    // ----- deposit / receive -----

    function test_Deposit_ByOwnerAddsBalanceAndChecksIn() public {
        vm.warp(vm.getBlockTimestamp() + 10 days);

        vm.expectEmit(address(vault));
        emit LegacyVault.CheckedIn(vm.getBlockTimestamp());
        vm.expectEmit(address(vault));
        emit LegacyVault.Deposited(owner, 1 ether);

        vm.prank(owner);
        vault.deposit{value: 1 ether}();

        assertEq(address(vault).balance, INITIAL_DEPOSIT + 1 ether);
        assertEq(vault.lastCheckIn(), vm.getBlockTimestamp());
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

    function test_Receive_PlainTransferIsAccepted() public {
        vm.prank(stranger);
        (bool success,) = address(vault).call{value: 2 ether}("");
        assertTrue(success);
        assertEq(address(vault).balance, INITIAL_DEPOSIT + 2 ether);
    }

    function test_RevertWhen_DepositDuringClaiming() public {
        _startClaim();
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Claiming));
        vm.prank(stranger);
        vault.deposit{value: 1 ether}();
    }

    function test_RevertWhen_PlainTransferDuringClaiming() public {
        _startClaim();
        vm.prank(stranger);
        (bool success, bytes memory returnData) = address(vault).call{value: 1 ether}("");
        assertFalse(success);
        assertEq(returnData, _invalidState(LegacyVault.State.Active, LegacyVault.State.Claiming));
    }

    // ----- withdraw -----

    function test_Withdraw_OwnerReceivesEthAndChecksIn() public {
        vm.warp(vm.getBlockTimestamp() + 10 days);
        uint256 ownerBefore = owner.balance;

        vm.expectEmit(address(vault));
        emit LegacyVault.Withdrawn(owner, 4 ether);

        vm.prank(owner);
        vault.withdraw(4 ether);

        assertEq(owner.balance, ownerBefore + 4 ether);
        assertEq(address(vault).balance, INITIAL_DEPOSIT - 4 ether);
        assertEq(vault.lastCheckIn(), vm.getBlockTimestamp());
    }

    function test_Withdraw_OwnerCanWithdrawEntireBalance() public {
        vm.prank(owner);
        vault.withdraw(INITIAL_DEPOSIT);
        assertEq(address(vault).balance, 0);
    }

    function test_RevertWhen_HeirWithdraws() public {
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(alice);
        vault.withdraw(1 ether);
    }

    function test_RevertWhen_GuardianWithdraws() public {
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(guardian1);
        vault.withdraw(1 ether);
    }

    function test_RevertWhen_WithdrawExceedsBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(LegacyVault.InsufficientBalance.selector, INITIAL_DEPOSIT + 1, INITIAL_DEPOSIT)
        );
        vm.prank(owner);
        vault.withdraw(INITIAL_DEPOSIT + 1);
    }

    function test_RevertWhen_WithdrawDuringClaiming() public {
        _startClaim();
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Claiming));
        vm.prank(owner);
        vault.withdraw(1 ether);
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

    // ----- checkIn -----

    function test_CheckIn_UpdatesLastCheckIn() public {
        vm.warp(vm.getBlockTimestamp() + 100 days);

        vm.expectEmit(address(vault));
        emit LegacyVault.CheckedIn(vm.getBlockTimestamp());

        vm.prank(owner);
        vault.checkIn();

        assertEq(vault.lastCheckIn(), vm.getBlockTimestamp());
        assertEq(vault.getStatus().activeUntil, vm.getBlockTimestamp() + INACTIVITY);
    }

    function test_RevertWhen_HeirChecksIn() public {
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(alice);
        vault.checkIn();
    }

    function test_RevertWhen_GuardianChecksIn() public {
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(guardian1);
        vault.checkIn();
    }

    function test_RevertWhen_CheckInDuringClaiming() public {
        _startClaim();
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Claiming));
        vm.prank(owner);
        vault.checkIn();
    }

    // ----- updateHeirs -----

    function test_UpdateHeirs_ReplacesListAndChecksIn() public {
        address dave = makeAddr("dave");
        address[] memory newHeirs = new address[](2);
        newHeirs[0] = bob;
        newHeirs[1] = dave;
        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 6000;
        newShares[1] = 4000;

        vm.warp(vm.getBlockTimestamp() + 10 days);
        vm.expectEmit(address(vault));
        emit LegacyVault.HeirsUpdated();

        vm.prank(owner);
        vault.updateHeirs(newHeirs, newShares);

        assertEq(vault.heirs(0), bob);
        assertEq(vault.heirs(1), dave);
        assertEq(vault.sharesBps(0), 6000);
        assertEq(vault.sharesBps(1), 4000);
        assertTrue(vault.isHeir(bob));
        assertTrue(vault.isHeir(dave));
        assertFalse(vault.isHeir(alice));
        assertFalse(vault.isHeir(carol));
        assertEq(vault.lastCheckIn(), vm.getBlockTimestamp());
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

    /// @dev Heir lama yang tetap ada di daftar baru tidak boleh dianggap duplikat.
    function test_UpdateHeirs_KeepingSameHeirsIsNotDuplicate() public {
        vm.prank(owner);
        vault.updateHeirs(_defaultHeirs(), _defaultShares());
        assertTrue(vault.isHeir(alice));
        assertEq(vault.heirs(2), carol);
    }

    function test_RevertWhen_HeirUpdatesHeirs() public {
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(alice);
        vault.updateHeirs(_defaultHeirs(), _defaultShares());
    }

    function test_RevertWhen_GuardianUpdatesHeirs() public {
        vm.expectRevert(LegacyVault.NotOwner.selector);
        vm.prank(guardian1);
        vault.updateHeirs(_defaultHeirs(), _defaultShares());
    }

    function test_RevertWhen_UpdateHeirsWithInvalidSharesTotal() public {
        uint256[] memory shares = _defaultShares();
        shares[0] = 4000;

        vm.expectRevert(abi.encodeWithSelector(LegacyVault.InvalidSharesTotal.selector, 9000));
        vm.prank(owner);
        vault.updateHeirs(_defaultHeirs(), shares);

        // Daftar lama tetap berlaku karena perubahan dibatalkan seluruhnya.
        assertTrue(vault.isHeir(alice));
        assertEq(vault.sharesBps(0), 5000);
    }

    function test_RevertWhen_UpdateHeirsWithGuardian() public {
        address[] memory heirs = _defaultHeirs();
        heirs[0] = guardian3;
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.GuardianCannotBeHeir.selector, guardian3));
        vm.prank(owner);
        vault.updateHeirs(heirs, _defaultShares());
    }

    function test_RevertWhen_UpdateHeirsWithDuplicate() public {
        address[] memory heirs = _defaultHeirs();
        heirs[1] = carol;
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.DuplicateAddress.selector, carol));
        vm.prank(owner);
        vault.updateHeirs(heirs, _defaultShares());
    }

    function test_RevertWhen_UpdateHeirsWithOwner() public {
        address[] memory heirs = _defaultHeirs();
        heirs[1] = owner;
        vm.expectRevert(LegacyVault.OwnerCannotHaveRole.selector);
        vm.prank(owner);
        vault.updateHeirs(heirs, _defaultShares());
    }

    function test_RevertWhen_UpdateHeirsDuringClaiming() public {
        _startClaim();
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Claiming));
        vm.prank(owner);
        vault.updateHeirs(_defaultHeirs(), _defaultShares());
    }

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

    // =====================================================================
    // 3. Klaim: startClaim, approveClaim, finalizeClaim
    // =====================================================================

    // ----- startClaim -----

    function test_StartClaim_ByHeirAfterInactivity() public {
        _warpPastInactivity(vault);

        vm.expectEmit(address(vault));
        emit LegacyVault.ClaimStarted(1, alice);

        vm.prank(alice);
        vault.startClaim();

        assertEq(uint256(vault.state()), uint256(LegacyVault.State.Claiming));
        assertEq(vault.claimId(), 1);
        assertEq(vault.approvalCount(), 0);
        assertEq(vault.unlockTime(), 0);
    }

    function test_StartClaim_ByGuardianAfterInactivity() public {
        _warpPastInactivity(vault);
        vm.prank(guardian3);
        vault.startClaim();
        assertEq(uint256(vault.state()), uint256(LegacyVault.State.Claiming));
    }

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

    function test_RevertWhen_StartClaimWhileAlreadyClaiming() public {
        _startClaim();
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Claiming));
        vm.prank(bob);
        vault.startClaim();
    }

    // ----- approveClaim -----

    function test_ApproveClaim_CountsVote() public {
        _startClaim();

        vm.expectEmit(address(vault));
        emit LegacyVault.ClaimApproved(1, guardian1, 1);
        _approve(guardian1);

        assertEq(vault.approvalCount(), 1);
        assertTrue(vault.hasApproved(1, guardian1));
        assertEq(vault.unlockTime(), 0);
    }

    function test_ApproveClaim_ReachingThresholdSchedulesUnlock() public {
        _startClaim();
        _approve(guardian1);

        vm.expectEmit(address(vault));
        emit LegacyVault.ClaimUnlockScheduled(1, vm.getBlockTimestamp() + TIMELOCK);
        _approve(guardian2);

        assertEq(vault.unlockTime(), vm.getBlockTimestamp() + TIMELOCK);
    }

    /// @dev Persetujuan tambahan setelah threshold tidak boleh memperpanjang timelock.
    function test_ApproveClaim_ExtraApprovalDoesNotMoveUnlockTime() public {
        _startClaim();
        _approve(guardian1);
        _approve(guardian2);
        uint256 scheduled = vault.unlockTime();

        vm.warp(vm.getBlockTimestamp() + 3 days);
        _approve(guardian3);

        assertEq(vault.approvalCount(), 3);
        assertEq(vault.unlockTime(), scheduled);
    }

    function test_RevertWhen_GuardianApprovesTwice() public {
        _startClaim();
        _approve(guardian1);

        vm.expectRevert(abi.encodeWithSelector(LegacyVault.AlreadyApproved.selector, 1));
        _approve(guardian1);

        assertEq(vault.approvalCount(), 1);
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

    function test_RevertWhen_ApproveWithoutActiveClaim() public {
        vm.expectRevert(_invalidState(LegacyVault.State.Claiming, LegacyVault.State.Active));
        _approve(guardian1);
    }

    // ----- finalizeClaim -----

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

    function test_RevertWhen_FinalizeWithoutClaim() public {
        vm.expectRevert(_invalidState(LegacyVault.State.Claiming, LegacyVault.State.Active));
        vault.finalizeClaim();
    }

    function test_RevertWhen_FinalizeTwice() public {
        _runToDistributed(vault);
        vm.expectRevert(_invalidState(LegacyVault.State.Claiming, LegacyVault.State.Distributed));
        vault.finalizeClaim();
    }

    // =====================================================================
    // 4. Pembatalan
    // =====================================================================

    function test_CancelClaim_ReturnsToActiveAndChecksIn() public {
        _startClaim();
        _approve(guardian1);
        vm.warp(vm.getBlockTimestamp() + 1 days);

        vm.expectEmit(address(vault));
        emit LegacyVault.ClaimCancelled(1);

        vm.prank(owner);
        vault.cancelClaim();

        assertEq(uint256(vault.state()), uint256(LegacyVault.State.Active));
        assertEq(vault.lastCheckIn(), vm.getBlockTimestamp());
        assertEq(vault.approvalCount(), 0);
        assertEq(vault.unlockTime(), 0);
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

    function test_RevertWhen_CancelWithoutClaim() public {
        vm.expectRevert(_invalidState(LegacyVault.State.Claiming, LegacyVault.State.Active));
        vm.prank(owner);
        vault.cancelClaim();
    }

    function test_RevertWhen_CancelAfterDistributed() public {
        _runToDistributed(vault);
        vm.expectRevert(_invalidState(LegacyVault.State.Claiming, LegacyVault.State.Distributed));
        vm.prank(owner);
        vault.cancelClaim();
    }

    // =====================================================================
    // 5. Pencairan
    // =====================================================================

    function test_WithdrawInheritance_EachHeirReceivesCorrectShare() public {
        _runToDistributed(vault);

        vm.expectEmit(address(vault));
        emit LegacyVault.InheritanceWithdrawn(alice, 5 ether);
        vm.prank(alice);
        vault.withdrawInheritance();

        vm.prank(bob);
        vault.withdrawInheritance();
        vm.prank(carol);
        vault.withdrawInheritance();

        assertEq(alice.balance, 5 ether);
        assertEq(bob.balance, 3 ether);
        assertEq(carol.balance, 2 ether);
        assertEq(address(vault).balance, 0);
        assertEq(vault.inheritanceOf(alice), 0);
    }

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

    function test_RevertWhen_HeirWithdrawsInheritanceTwice() public {
        _runToDistributed(vault);
        vm.prank(alice);
        vault.withdrawInheritance();

        vm.expectRevert(LegacyVault.NothingToWithdraw.selector);
        vm.prank(alice);
        vault.withdrawInheritance();

        assertEq(alice.balance, 5 ether);
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

    function test_RevertWhen_WithdrawInheritanceBeforeDistributed() public {
        vm.expectRevert(_invalidState(LegacyVault.State.Distributed, LegacyVault.State.Active));
        vm.prank(alice);
        vault.withdrawInheritance();
    }

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

    function test_RevertWhen_OwnerWithdrawsAfterDistributed() public {
        _runToDistributed(vault);
        vm.expectRevert(_invalidState(LegacyVault.State.Active, LegacyVault.State.Distributed));
        vm.prank(owner);
        vault.withdraw(1 ether);
    }

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

    // =====================================================================
    // getStatus
    // =====================================================================

    function test_GetStatus_ReflectsEachPhase() public {
        LegacyVault.Status memory status = vault.getStatus();
        assertEq(uint256(status.state), uint256(LegacyVault.State.Active));
        assertEq(status.balance, INITIAL_DEPOSIT);
        assertEq(status.lastCheckIn, vm.getBlockTimestamp());
        assertEq(status.activeUntil, vm.getBlockTimestamp() + INACTIVITY);
        assertEq(status.claimId, 0);
        assertEq(status.approvals, 0);
        assertEq(status.threshold, THRESHOLD);
        assertEq(status.unlockTime, 0);

        _startClaim();
        _approve(guardian1);
        _approve(guardian2);
        status = vault.getStatus();
        assertEq(uint256(status.state), uint256(LegacyVault.State.Claiming));
        assertEq(status.claimId, 1);
        assertEq(status.approvals, 2);
        assertEq(status.unlockTime, vm.getBlockTimestamp() + TIMELOCK);

        vm.warp(status.unlockTime);
        vault.finalizeClaim();
        vm.prank(alice);
        vault.withdrawInheritance();
        status = vault.getStatus();
        assertEq(uint256(status.state), uint256(LegacyVault.State.Distributed));
        assertEq(status.balance, INITIAL_DEPOSIT - 5 ether);
    }

    // =====================================================================
    // 6. Fuzz: total semua bagian = snapshot (invariant 1 dan 2)
    // =====================================================================

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
    // 7. End-to-end: dari deposit sampai semua heir menarik
    // =====================================================================

    function test_EndToEnd_HappyPath() public {
        // Owner aktif: menambah dana, ada pihak lain ikut menyetor, owner menarik sebagian.
        vm.warp(vm.getBlockTimestamp() + 30 days);
        vm.prank(owner);
        vault.deposit{value: 5 ether}();

        vm.prank(stranger);
        (bool sent,) = address(vault).call{value: 1 ether}("");
        assertTrue(sent);

        vm.warp(vm.getBlockTimestamp() + 30 days);
        vm.prank(owner);
        vault.withdraw(2 ether);
        assertEq(address(vault).balance, 14 ether);

        // Owner mengubah porsi menjadi 25 / 25 / 50.
        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 2500;
        newShares[1] = 2500;
        newShares[2] = 5000;
        vm.prank(owner);
        vault.updateHeirs(_defaultHeirs(), newShares);

        // Owner tidak aktif lagi. Satu hari sebelum batas, klaim masih ditolak.
        uint256 activeUntil = vault.lastCheckIn() + INACTIVITY;
        vm.warp(activeUntil - 1 days);
        vm.expectRevert(abi.encodeWithSelector(LegacyVault.OwnerStillActive.selector, activeUntil));
        vm.prank(bob);
        vault.startClaim();

        // Setelah batas lewat, bob memulai klaim, dua guardian menyetujui.
        vm.warp(activeUntil);
        vm.prank(bob);
        vault.startClaim();
        _approve(guardian3);
        _approve(guardian1);

        // Timelock lewat, pihak luar menutup klaim.
        vm.warp(vault.unlockTime());
        vm.prank(stranger);
        vault.finalizeClaim();
        assertEq(vault.snapshot(), 14 ether);

        // Semua heir menarik bagiannya.
        vm.prank(alice);
        vault.withdrawInheritance();
        vm.prank(bob);
        vault.withdrawInheritance();
        vm.prank(carol);
        vault.withdrawInheritance();

        assertEq(alice.balance, 3.5 ether);
        assertEq(bob.balance, 3.5 ether);
        assertEq(carol.balance, 7 ether);
        assertEq(address(vault).balance, 0);
        assertEq(uint256(vault.state()), uint256(LegacyVault.State.Distributed));
    }
}
