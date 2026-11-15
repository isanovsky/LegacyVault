// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {LegacyVault} from "../../src/LegacyVault.sol";

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

/// @notice Konfigurasi dan helper bersama untuk semua file test LegacyVault.
/// @dev Owner, 3 heir (50/30/20), 3 guardian dengan threshold 2, masa tidak aktif 180 hari,
///      timelock 7 hari, setoran awal 10 ETH.
abstract contract LegacyVaultFixture is Test {
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
}
