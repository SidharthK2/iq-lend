// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {IFraxswapOracle} from "./interfaces/IFraxswapOracle.sol";
import {IFraxswapPair} from "./interfaces/IFraxswapPair.sol";

contract IQOracle is IOracle, Ownable {
    error InvalidTwapPeriod();
    error InvalidScaleExponent();

    event SetTwapPeriod(uint256 newTwapPeriod);

    IFraxswapOracle public immutable fraxswapOracle;
    IFraxswapPair public immutable pair;
    uint256 public immutable twapRounds;
    uint256 public immutable maxDiffPerc;
    bool public immutable usePrice0;
    uint256 public immutable scaleMultiplier;
    uint256 public immutable scaleDivisor;

    uint256 public twapPeriod;

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
    ) Ownable(owner_) {
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

    function setTwapPeriod(uint256 newTwapPeriod) external onlyOwner {
        if (newTwapPeriod == 0) revert InvalidTwapPeriod();
        twapPeriod = newTwapPeriod;
        emit SetTwapPeriod(newTwapPeriod);
    }

    function price() external view returns (uint256) {
        (uint256 price0, uint256 price1) = fraxswapOracle.getPrice(pair, twapPeriod, twapRounds, maxDiffPerc);
        uint256 fraxPrice = usePrice0 ? price0 : price1;
        return fraxPrice * scaleMultiplier / scaleDivisor;
    }
}
