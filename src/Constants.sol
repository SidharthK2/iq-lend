// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0;

/// @title Constants
/// @notice Protocol-wide constants for token addresses, DEX integrations, oracle parameters,
///         market configuration, and deployed contract addresses on Ethereum mainnet.
library Constants {
    // -------------------------------------------------------------------------
    // Mainnet tokens
    // -------------------------------------------------------------------------

    /// @notice IQ governance token.
    address constant IQ = 0x579CEa1889991f68aCc35Ff5c3dd0621fF29b0C9;

    /// @notice USD Coin (6 decimals).
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    /// @notice Frax stablecoin (18 decimals).
    address constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

    // -------------------------------------------------------------------------
    // Fraxswap
    // -------------------------------------------------------------------------

    /// @notice Fraxswap IQ-FRAX pair used by the oracle and router.
    address constant FRAXSWAP_IQ_FRAX_PAIR = 0x07AF6BB51d6Ad0Cf126E3eD2DeE6EaC34BF094F8;

    /// @notice Fraxswap router used for IQ<->FRAX swaps.
    address constant FRAXSWAP_ROUTER = 0xC14d550632db8592D1243Edc8B95b0Ad06703867;

    // -------------------------------------------------------------------------
    // Curve
    // -------------------------------------------------------------------------

    /// @notice Curve FRAX-USDC pool used for stablecoin swaps.
    address constant CURVE_FRAX_USDC = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;

    // -------------------------------------------------------------------------
    // Oracle parameters
    // -------------------------------------------------------------------------

    /// @notice TWAP observation window in seconds (5 minutes).
    uint256 constant TWAP_PERIOD = 300;

    /// @notice Number of TWAP rounds used for the moving average.
    uint256 constant TWAP_ROUNDS = 7;

    /// @notice Maximum allowed spot/TWAP price deviation in basis points (5%).
    uint256 constant MAX_DIFF_PERC = 500;

    // -------------------------------------------------------------------------
    // Market parameters
    // -------------------------------------------------------------------------

    /// @notice Liquidation loan-to-value ratio (70%, scaled by 1e18).
    uint256 constant LLTV = 0.7e18;

    /// @notice Maximum total supply allowed per market in USDC (500 USDC, 6 decimals).
    uint256 constant SUPPLY_CAP = 500e6;

    /// @notice Maximum total borrows allowed per market in USDC (500 USDC, 6 decimals).
    uint256 constant BORROW_CAP = 500e6;

    // -------------------------------------------------------------------------
    // Deployed contracts
    // -------------------------------------------------------------------------

    /// @notice Fraxswap TWAP oracle contract.
    address constant FRAXSWAP_ORACLE = 0xd1714D6b97cB5e514488D8DDEe564F3194303b64;

    /// @notice IQOracle for market 1 (usePrice0=true: returns IQ price in FRAX terms).
    address constant IQ_ORACLE_MARKET1 = 0xf967BB7DA29a187A16b9276A9edB31733CbA443A;

    /// @notice IQOracle for market 2 (usePrice0=false: returns FRAX price in IQ terms).
    address constant IQ_ORACLE_MARKET2 = 0x13aF5D132f5e93EcEe7080D06d523EEb585c5b63;

    /// @notice Deployed IQLend contract.
    address constant IQ_LEND = 0x7731a73252371de56Fb37F7F428aBD9f0e54c737;

    /// @notice Morpho Blue adaptive curve interest rate model.
    address constant IRM = 0x2DeC53af9ebA8c9F85c6C57A8A9a111f3BB0186a;
}
