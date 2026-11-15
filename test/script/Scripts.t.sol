// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {LegacyVault} from "../../src/LegacyVault.sol";
import {AnvilAccounts} from "../../script/AnvilAccounts.sol";
import {Deploy} from "../../script/Deploy.s.sol";
import {SeedDemo} from "../../script/SeedDemo.s.sol";

/// @notice Test untuk skrip deploy. Skrip dijalankan di dalam test (tanpa jaringan sungguhan),
///         dan chainId diubah dengan vm.chainId untuk meniru Anvil atau Sepolia.
contract ScriptsTest is Test {
    uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

    function _config(address[] memory heirs, address[] memory guardians)
        internal
        pure
        returns (Deploy.Config memory config)
    {
        uint256[] memory shares = new uint256[](2);
        shares[0] = 7000;
        shares[1] = 3000;
        config = Deploy.Config({
            heirs: heirs,
            sharesBps: shares,
            guardians: guardians,
            threshold: 1,
            inactivityPeriod: 30 days,
            timelockPeriod: 3 days,
            initialDeposit: 0
        });
    }

    function _pair(address a, address b) internal pure returns (address[] memory list) {
        list = new address[](2);
        list[0] = a;
        list[1] = b;
    }

    // ----- SeedDemo -----

    function test_SeedDemo_DeploysDemoVaultOnAnvil() public {
        vm.chainId(AnvilAccounts.CHAIN_ID);
        vm.deal(AnvilAccounts.ACCOUNT_0, 100 ether);

        LegacyVault vault = new SeedDemo().run();

        assertEq(vault.owner(), AnvilAccounts.ACCOUNT_0);
        assertEq(address(vault).balance, 10 ether);
        assertEq(vault.heirs(0), AnvilAccounts.ACCOUNT_1);
        assertEq(vault.heirs(1), AnvilAccounts.ACCOUNT_2);
        assertEq(vault.sharesBps(0), 6000);
        assertEq(vault.sharesBps(1), 4000);
        assertEq(vault.guardians(0), AnvilAccounts.ACCOUNT_3);
        assertEq(vault.guardians(1), AnvilAccounts.ACCOUNT_4);
        assertEq(vault.guardians(2), AnvilAccounts.ACCOUNT_5);
        assertEq(vault.threshold(), 2);
        assertEq(vault.inactivityPeriod(), 180 days);
        assertEq(vault.timelockPeriod(), 7 days);
    }

    function test_RevertWhen_SeedDemoRunsOutsideAnvil() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        SeedDemo seed = new SeedDemo();
        vm.expectRevert(abi.encodeWithSelector(SeedDemo.NotAnvilChain.selector, SEPOLIA_CHAIN_ID));
        seed.run();
    }

    // ----- Deploy -----

    function test_Deploy_ReadConfigParsesEnvironment() public {
        address heirA = makeAddr("heirA");
        address heirB = makeAddr("heirB");
        address guardianA = makeAddr("guardianA");
        vm.setEnv("HEIRS", string.concat(vm.toString(heirA), ",", vm.toString(heirB)));
        vm.setEnv("SHARES_BPS", "7000,3000");
        vm.setEnv("GUARDIANS", vm.toString(guardianA));
        vm.setEnv("THRESHOLD", "1");
        vm.setEnv("INACTIVITY_PERIOD", "2592000");
        vm.setEnv("TIMELOCK_PERIOD", "259200");
        vm.setEnv("INITIAL_DEPOSIT_WEI", "1000");

        Deploy.Config memory config = new Deploy().readConfig();

        assertEq(config.heirs.length, 2);
        assertEq(config.heirs[1], heirB);
        assertEq(config.sharesBps[0], 7000);
        assertEq(config.guardians[0], guardianA);
        assertEq(config.threshold, 1);
        assertEq(config.inactivityPeriod, 30 days);
        assertEq(config.timelockPeriod, 3 days);
        assertEq(config.initialDeposit, 1000);
    }

    function test_Deploy_OnAnvilAllowsAnvilAccounts() public {
        vm.chainId(AnvilAccounts.CHAIN_ID);
        Deploy.Config memory config = _config(
            _pair(AnvilAccounts.ACCOUNT_1, AnvilAccounts.ACCOUNT_2),
            _pair(AnvilAccounts.ACCOUNT_3, AnvilAccounts.ACCOUNT_4)
        );

        LegacyVault vault = new Deploy().deploy(config);

        assertEq(vault.heirs(0), AnvilAccounts.ACCOUNT_1);
        assertEq(vault.threshold(), 1);
    }

    function test_Deploy_OnPublicChainUsesPrivateKeyAsOwner() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        (address deployer, uint256 deployerKey) = makeAddrAndKey("testnetDeployer");
        vm.setEnv("PRIVATE_KEY", vm.toString(deployerKey));
        Deploy.Config memory config =
            _config(_pair(makeAddr("h1"), makeAddr("h2")), _pair(makeAddr("g1"), makeAddr("g2")));

        LegacyVault vault = new Deploy().deploy(config);

        assertEq(vault.owner(), deployer);
    }

    function test_RevertWhen_DeployOnPublicChainWithAnvilHeir() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        Deploy deployScript = new Deploy();
        Deploy.Config memory config =
            _config(_pair(makeAddr("h1"), AnvilAccounts.ACCOUNT_2), _pair(makeAddr("g1"), makeAddr("g2")));

        vm.expectRevert(abi.encodeWithSelector(Deploy.AnvilAccountOnPublicChain.selector, AnvilAccounts.ACCOUNT_2));
        deployScript.deploy(config);
    }

    function test_RevertWhen_DeployOnPublicChainWithAnvilGuardian() public {
        vm.chainId(SEPOLIA_CHAIN_ID);
        Deploy deployScript = new Deploy();
        Deploy.Config memory config =
            _config(_pair(makeAddr("h1"), makeAddr("h2")), _pair(AnvilAccounts.ACCOUNT_5, makeAddr("g2")));

        vm.expectRevert(abi.encodeWithSelector(Deploy.AnvilAccountOnPublicChain.selector, AnvilAccounts.ACCOUNT_5));
        deployScript.deploy(config);
    }
}
