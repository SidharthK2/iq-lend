// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { IFraxswapOracle } from "./interfaces/IFraxswapOracle.sol";
import { IFraxswapPair } from "./interfaces/IFraxswapPair.sol";

/// @title IQOracle
/// @notice Price oracle for Morpho Blue markets, derived from a Fraxswap TWAP.
/// @dev Returns the collateral price in loan-token units scaled to Morpho's ORACLE_PRICE_SCALE (1e36).
///      Scaling is computed at construction from the collateral and loan token decimals so that
///      `price()` returns a value directly usable by IQLend without further adjustment.
contract IQOracle is IOracle, Ownable {
    /// @notice Thrown when a zero value is passed as the TWAP period.
    error InvalidTwapPeriod();

    /// @notice Thrown when the computed decimal-adjustment exponent is out of the safe cast range.
    error InvalidScaleExponent();

    /// @notice Emitted when the owner updates the TWAP observation window.
    /// @param newTwapPeriod New TWAP period in seconds.
    event SetTwapPeriod(uint256 newTwapPeriod);

    /// @notice Fraxswap oracle used to retrieve TWAP prices from the pair.
    IFraxswapOracle public immutable fraxswapOracle;

    /// @notice Fraxswap pair from which TWAP prices are read.
    IFraxswapPair public immutable pair;

    /// @notice Number of TWAP rounds used when computing the moving average.
    uint256 public immutable twapRounds;

    /// @notice Maximum allowed deviation between spot price and TWAP price in basis points (e.g. 500 = 5%).
    uint256 public immutable maxDiffPerc;

    /// @notice Whether to use price0 (true) or price1 (false) from the Fraxswap pair.
    bool public immutable usePrice0;

    /// @notice Numerator scaling factor derived from token decimals, used to normalise the price to 1e36.
    uint256 public immutable scaleMultiplier;

    /// @notice Denominator scaling factor derived from token decimals, used to normalise the price to 1e36.
    uint256 public immutable scaleDivisor;

    /// @notice TWAP observation window in seconds. Updatable by the owner.
    uint256 public twapPeriod;

    /// @notice Deploys IQOracle and pre-computes decimal scaling factors.
    /// @param owner_ Contract owner, allowed to call `setTwapPeriod`.
    /// @param fraxswapOracle_ Fraxswap oracle contract that exposes `getPrice`.
    /// @param pair_ Fraxswap pair to read prices from.
    /// @param collateralToken Address of the collateral token (decimals used for scaling).
    /// @param loanToken Address of the loan token (decimals used for scaling).
    /// @param usePrice0_ True to use price0 from the pair, false to use price1.
    /// @param twapPeriod_ Initial TWAP observation window in seconds. Must be non-zero.
    /// @param twapRounds_ Number of TWAP rounds for the moving average.
    /// @param maxDiffPerc_ Maximum allowed spot/TWAP deviation in basis points.
    constructor(
        address owner_,
        IFraxswapOracle fraxswapOracle_,
        IFraxswapPair pair_,
        address collateralToken,
        address loanToken,
        bool usePrice0_,
        uint256 twapPeriod_,
        uint256 twapRounds_,
        uint256 maxDiffPerc_
    )
        Ownable(owner_)
    {
        fraxswapOracle = fraxswapOracle_;
        pair = pair_;
        usePrice0 = usePrice0_;
        twapRounds = twapRounds_;
        maxDiffPerc = maxDiffPerc_;

        if (twapPeriod_ == 0) revert InvalidTwapPeriod();
        twapPeriod = twapPeriod_;
        emit SetTwapPeriod(twapPeriod_);

        uint8 collateralDecimals = IERC20Metadata(collateralToken).decimals();
        uint8 loanDecimals = IERC20Metadata(loanToken).decimals();

        int256 exponent = int256(uint256(loanDecimals)) - int256(uint256(collateralDecimals)) + 2;
        if (exponent >= 0) {
            scaleMultiplier = 10 ** uint256(exponent);
            scaleDivisor = 1;
        } else {
            scaleMultiplier = 1;
            scaleDivisor = 10 ** uint256(-exponent);
        }
    }

    /// @notice Updates the TWAP observation window.
    /// @param newTwapPeriod New TWAP period in seconds. Must be non-zero.
    function setTwapPeriod(uint256 newTwapPeriod) external onlyOwner {
        if (newTwapPeriod == 0) revert InvalidTwapPeriod();
        twapPeriod = newTwapPeriod;
        emit SetTwapPeriod(newTwapPeriod);
    }

    /// @notice Returns the collateral price in loan-token units, scaled to 1e36.
    /// @dev Reads the Fraxswap TWAP and applies the pre-computed decimal scaling.
    /// @return Collateral price per unit of collateral expressed in loan-token terms (1e36 scale).
    function price() external view returns (uint256) {
        (uint256 price0, uint256 price1) = fraxswapOracle.getPrice(pair, twapPeriod, twapRounds, maxDiffPerc);
        uint256 fraxPrice = usePrice0 ? price0 : price1;
        return fraxPrice * scaleMultiplier / scaleDivisor;
    }
}
