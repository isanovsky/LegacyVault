// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Alamat akun bawaan Anvil
/// @notice Sepuluh akun yang selalu dibuat Anvil dari mnemonic publik "test test ... junk".
/// @dev Private key akun-akun ini diketahui semua orang. Karena itu alamat ini hanya boleh dipakai
///      di jaringan lokal (chainId 31337). Di jaringan publik, siapa pun bisa menguras ETH yang
///      dikirim ke alamat ini, jadi skrip deploy menolaknya sebagai heir, guardian, atau owner.
library AnvilAccounts {
    uint256 internal constant CHAIN_ID = 31337;

    address internal constant ACCOUNT_0 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant ACCOUNT_1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant ACCOUNT_2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant ACCOUNT_3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address internal constant ACCOUNT_4 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
    address internal constant ACCOUNT_5 = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
    address internal constant ACCOUNT_6 = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
    address internal constant ACCOUNT_7 = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;
    address internal constant ACCOUNT_8 = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
    address internal constant ACCOUNT_9 = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

    function isAnvilAccount(address account) internal pure returns (bool) {
        return account == ACCOUNT_0 || account == ACCOUNT_1 || account == ACCOUNT_2 || account == ACCOUNT_3
            || account == ACCOUNT_4 || account == ACCOUNT_5 || account == ACCOUNT_6 || account == ACCOUNT_7
            || account == ACCOUNT_8 || account == ACCOUNT_9;
    }
}
