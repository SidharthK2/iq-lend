// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0;

library Constants {
    // Mainnet tokens
    address constant IQ = 0x579CEa1889991f68aCc35Ff5c3dd0621fF29b0C9;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    // Fraxswap
    address constant FRAXSWAP_IQ_FRAX_PAIR = 0x07AF6BB51d6Ad0Cf126E3eD2DeE6EaC34BF094F8;

    // Oracle params
    uint256 constant TWAP_PERIOD = 300; // 5 min
    uint256 constant TWAP_ROUNDS = 7;
    uint256 constant MAX_DIFF_PERC = 500; // 5%

    // Market params
    uint256 constant LLTV = 0.7e18; // 70%
    uint256 constant SUPPLY_CAP = 500e6; // 500 USDC
    uint256 constant BORROW_CAP = 500e6; // 500 USDC
}
