// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LegacyVault} from "../src/LegacyVault.sol";
import {AnvilAccounts} from "./AnvilAccounts.sol";

/// @title Skrip deploy LegacyVault
/// @notice Membaca konfigurasi dari environment variable (otomatis dari file .env oleh forge),
///         lalu men-deploy satu LegacyVault. Akun yang men-deploy menjadi owner.
/// @dev Variabel yang dibaca (lihat .env.example):
///      HEIRS, SHARES_BPS, GUARDIANS (dipisah koma), THRESHOLD, INACTIVITY_PERIOD, TIMELOCK_PERIOD
///      (dalam detik), INITIAL_DEPOSIT_WEI (opsional), dan PRIVATE_KEY (hanya di luar Anvil).
contract Deploy is Script {
    struct Config {
        address[] heirs;
        uint256[] sharesBps;
        address[] guardians;
        uint256 threshold;
        uint256 inactivityPeriod;
        uint256 timelockPeriod;
        uint256 initialDeposit;
    }

    error AnvilAccountOnPublicChain(address account);

    function run() external returns (LegacyVault) {
        return deploy(readConfig());
    }

    /// @notice Membaca konfigurasi dari environment variable. Revert jika ada variabel wajib yang kosong.
    function readConfig() public view returns (Config memory config) {
        config.heirs = vm.envAddress("HEIRS", ",");
        config.sharesBps = vm.envUint("SHARES_BPS", ",");
        config.guardians = vm.envAddress("GUARDIANS", ",");
        config.threshold = vm.envUint("THRESHOLD");
        config.inactivityPeriod = vm.envUint("INACTIVITY_PERIOD");
        config.timelockPeriod = vm.envUint("TIMELOCK_PERIOD");
        config.initialDeposit = vm.envOr("INITIAL_DEPOSIT_WEI", uint256(0));
    }

    /// @notice Men-deploy LegacyVault dengan konfigurasi yang diberikan.
    /// @dev Di Anvil, pengirim transaksi diatur dari command line (--unlocked --sender), tanpa private key.
    ///      Di jaringan lain, private key dibaca dari PRIVATE_KEY, dan semua alamat diperiksa supaya
    ///      tidak ada akun Anvil (private key-nya publik) yang ikut menjadi owner, heir, atau guardian.
    function deploy(Config memory config) public returns (LegacyVault vault) {
        if (block.chainid == AnvilAccounts.CHAIN_ID) {
            vm.startBroadcast();
        } else {
            _rejectAnvilAccounts(config.heirs);
            _rejectAnvilAccounts(config.guardians);

            uint256 deployerKey = vm.envUint("PRIVATE_KEY");
            address deployer = vm.addr(deployerKey);
            if (AnvilAccounts.isAnvilAccount(deployer)) revert AnvilAccountOnPublicChain(deployer);

            vm.startBroadcast(deployerKey);
        }

        vault = new LegacyVault{value: config.initialDeposit}(
            config.heirs,
            config.sharesBps,
            config.guardians,
            config.threshold,
            config.inactivityPeriod,
            config.timelockPeriod
        );

        vm.stopBroadcast();

        console.log("LegacyVault di-deploy ke:", address(vault));
        console.log("Owner:", vault.owner());
        console.log("Chain ID:", block.chainid);
    }

    function _rejectAnvilAccounts(address[] memory accounts) private pure {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (AnvilAccounts.isAnvilAccount(accounts[i])) revert AnvilAccountOnPublicChain(accounts[i]);
        }
    }
}
