// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LegacyVault} from "../src/LegacyVault.sol";
import {AnvilAccounts} from "./AnvilAccounts.sol";

/// @title Skrip data demo untuk Anvil
/// @notice Men-deploy LegacyVault dengan tokoh demo dan menyetor 10 ETH, supaya UI langsung punya
///         sesuatu untuk ditampilkan. Hanya berjalan di Anvil (chainId 31337).
/// @dev Tokoh demo memakai akun bawaan Anvil:
///      akun 0 Pak Icanov (owner), akun 1-2 Mas Kevin dan Mas Murni (heir, 60% dan 40%),
///      akun 3-5 Mas Barrok, Notaris Budi, Pak RT Wowo (guardian, threshold 2).
contract SeedDemo is Script {
    address internal constant PAK_ICANOV = AnvilAccounts.ACCOUNT_0;
    address internal constant MAS_KEVIN = AnvilAccounts.ACCOUNT_1;
    address internal constant MAS_MURNI = AnvilAccounts.ACCOUNT_2;
    address internal constant MAS_BARROK = AnvilAccounts.ACCOUNT_3;
    address internal constant NOTARIS_BUDI = AnvilAccounts.ACCOUNT_4;
    address internal constant PAK_RT_WOWO = AnvilAccounts.ACCOUNT_5;

    uint256 internal constant DEMO_DEPOSIT = 10 ether;
    uint256 internal constant DEMO_THRESHOLD = 2;
    uint256 internal constant DEMO_INACTIVITY = 180 days;
    uint256 internal constant DEMO_TIMELOCK = 7 days;

    error NotAnvilChain(uint256 chainId);

    function run() external returns (LegacyVault vault) {
        // Akun-akun demo ini private key-nya publik; di jaringan lain skrip ini berbahaya.
        if (block.chainid != AnvilAccounts.CHAIN_ID) revert NotAnvilChain(block.chainid);

        address[] memory heirs = new address[](2);
        heirs[0] = MAS_KEVIN;
        heirs[1] = MAS_MURNI;

        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 6000;
        sharesBps[1] = 4000;

        address[] memory guardians = new address[](3);
        guardians[0] = MAS_BARROK;
        guardians[1] = NOTARIS_BUDI;
        guardians[2] = PAK_RT_WOWO;

        // Semua transaksi dikirim atas nama Pak Icanov, sehingga ia menjadi owner.
        vm.startBroadcast(PAK_ICANOV);
        vault = new LegacyVault(heirs, sharesBps, guardians, DEMO_THRESHOLD, DEMO_INACTIVITY, DEMO_TIMELOCK);
        vault.deposit{value: DEMO_DEPOSIT}();
        vm.stopBroadcast();

        console.log("LegacyVault demo di-deploy ke:", address(vault));
        console.log("Owner   Pak Icanov   :", PAK_ICANOV);
        console.log("Heir    Mas Kevin 60%:", MAS_KEVIN);
        console.log("Heir    Mas Murni 40%:", MAS_MURNI);
        console.log("Guardian Mas Barrok  :", MAS_BARROK);
        console.log("Guardian Notaris Budi:", NOTARIS_BUDI);
        console.log("Guardian Pak RT Wowo :", PAK_RT_WOWO);
        console.log("Saldo vault (wei)    :", address(vault).balance);
    }
}
