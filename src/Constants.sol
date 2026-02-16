// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0;

library Constants {
    // Mainnet tokens
    address constant IQ = 0x579CEa1889991f68aCc35Ff5c3dd0621fF29b0C9;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    // Fraxswap
    address constant FRAXSWAP_IQ_FRAX_PAIR = 0x07AF6BB51d6Ad0Cf126E3eD2DeE6EaC34BF094F8;

    //Curve
    address constant CURVE_FRAX_USDC = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;

    // Oracle params
    uint256 constant TWAP_PERIOD = 300; // 5 min
    uint256 constant TWAP_ROUNDS = 7;
    uint256 constant MAX_DIFF_PERC = 500; // 5%

    // Market params
    uint256 constant LLTV = 0.7e18; // 70%
    uint256 constant SUPPLY_CAP = 500e6; // 500 USDC
    uint256 constant BORROW_CAP = 500e6; // 500 USDC

    // Deployed contracts
    address constant FRAXSWAP_ORACLE = 0xd1714D6b97cB5e514488D8DDEe564F3194303b64; //
    address constant IQ_ORACLE_MARKET1 = 0xf967BB7DA29a187A16b9276A9edB31733CbA443A; // usePrice0=true
    address constant IQ_ORACLE_MARKET2 = 0x13aF5D132f5e93EcEe7080D06d523EEb585c5b63; // usePrice0=false
    address constant IQ_LEND = 0x7731a73252371de56Fb37F7F428aBD9f0e54c737;
    address constant IRM = 0x2DeC53af9ebA8c9F85c6C57A8A9a111f3BB0186a;
}
