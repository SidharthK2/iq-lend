// SPDX-License-Identifier: ISC
pragma solidity >=0.8.20;

import { Id, MarketParams } from "@morpho-blue/interfaces/IMorpho.sol";
import { IMorphoFlashLoanCallback } from "@morpho-blue/interfaces/IMorphoCallbacks.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "@morpho-blue/libraries/SharesMathLib.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IFraxswapRouter } from "./interfaces/IFraxswapRouter.sol";
import { ICurvePool } from "./interfaces/ICurvePool.sol";
import { IQLend } from "./IQLend.sol";

import { Constants } from "./Constants.sol";

contract IQRouter is IMorphoFlashLoanCallback, Ownable {
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    address public usdc = Constants.USDC;
    address public iq = Constants.IQ;
    address public frax = Constants.FRAX;

    IQLend public iqLend = IQLend(Constants.IQ_LEND);
    IFraxswapRouter public fraxswapRouter = IFraxswapRouter(Constants.FRAXSWAP_ROUTER);
    ICurvePool public curvePool = ICurvePool(Constants.CURVE_FRAX_USDC);

    // Market 1: Long IQ (collateral=IQ, loan=USDC)
    MarketParams public market1Params;
    Id public market1Id;

    // Market 2: Short IQ (collateral=USDC, loan=IQ)
    MarketParams public market2Params;
    Id public market2Id;

    enum Action {
        OPEN_LONG,
        CLOSE_LONG,
        OPEN_SHORT,
        CLOSE_SHORT
    }

    constructor(address owner) Ownable(owner) {
        //Approvals
        IERC20(usdc).approve(address(iqLend), type(uint256).max);
        IERC20(usdc).approve(address(curvePool), type(uint256).max);
        IERC20(iq).approve(address(iqLend), type(uint256).max);
        IERC20(iq).approve(address(fraxswapRouter), type(uint256).max);
        IERC20(Constants.FRAX).approve(address(curvePool), type(uint256).max);
        IERC20(Constants.FRAX).approve(address(fraxswapRouter), type(uint256).max);

        market1Params = MarketParams({
            loanToken: usdc,
            collateralToken: iq,
            oracle: Constants.IQ_ORACLE_MARKET1,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });
        market1Id = market1Params.id();

        market2Params = MarketParams({
            loanToken: iq,
            collateralToken: usdc,
            oracle: Constants.IQ_ORACLE_MARKET2,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });
        market2Id = market2Params.id();
    }

    function openLong(uint256 usdcAmount, uint256 leverageX18, uint256 minIQOut) external {
        IERC20(usdc).transferFrom(msg.sender, address(this), usdcAmount);
        uint256 flashAmount = (usdcAmount * (leverageX18 - 1e18)) / 1e18;
        bytes memory data = abi.encode(msg.sender, usdcAmount, minIQOut, Action.OPEN_LONG);
        iqLend.flashLoan(usdc, flashAmount, data);
    }

    function closeLong(uint256 minUsdcOut) external {
        (, uint256 borrowShares,) = iqLend.position(market1Id, msg.sender);
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = iqLend.market(market1Id);
        uint256 borrowAssets = borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
        bytes memory data = abi.encode(msg.sender, borrowAssets, minUsdcOut, Action.CLOSE_LONG);
        iqLend.flashLoan(usdc, borrowAssets, data);
    }

    function openShort(uint256 usdcAmount, uint256 iqFlashAmount, uint256 minUsdcCollateral) external { }

    function closeShort(uint256 minUsdcOut) external { }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(iqLend), "Not IQ Lend");
        (address user, uint256 userAmount, uint256 minAmtOut, Action action) =
            abi.decode(data, (address, uint256, uint256, Action));

        if (action == Action.OPEN_LONG) {
            uint256 totalUsdc = userAmount + assets;

            //USDC -> FRAX
            uint256 fraxOut = curvePool.exchange(1, 0, totalUsdc, 0);

            //FRAX -> IQ
            address[] memory path = new address[](2);
            path[0] = frax;
            path[1] = iq;
            uint256[] memory amounts =
                fraxswapRouter.swapExactTokensForTokens(fraxOut, minAmtOut, path, address(this), block.timestamp);

            //Supply IQ collateral
            iqLend.supplyCollateral(market1Params, amounts[1], user, "");

            //Borrow USDC to repay loan
            iqLend.borrow(market1Params, assets, 0, user, address(this));
        }

        if (action == Action.CLOSE_LONG) { }
    }
}
