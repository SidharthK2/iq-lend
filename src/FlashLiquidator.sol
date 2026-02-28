// SPDX-License-Identifier: ISC
pragma solidity >=0.8.20;

import { IMorphoLiquidateCallback } from "@morpho-blue/interfaces/IMorphoCallbacks.sol";
import { MarketParams } from "@morpho-blue/interfaces/IMorpho.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IFraxswapRouter } from "./interfaces/IFraxswapRouter.sol";
import { ICurvePool } from "./interfaces/ICurvePool.sol";
import { IQLend } from "./IQLend.sol";
import { Constants } from "./Constants.sol";

/// @title FlashLiquidator
/// @notice Capital-free liquidator for IQ Lend markets using Morpho's liquidation callback.
/// @dev Seizes collateral, swaps it to the loan token via Fraxswap (IQ<->FRAX) + Curve (FRAX<->USDC),
///      and lets Morpho pull the repayment. Profit is swept to the caller.
contract FlashLiquidator is IMorphoLiquidateCallback, Ownable {
    using SafeERC20 for IERC20;

    IQLend public immutable iqLend;
    IFraxswapRouter public immutable fraxswapRouter;
    ICurvePool public immutable curvePool;

    address public immutable iq;
    address public immutable usdc;
    address public immutable frax;

    struct CallbackData {
        address collateralToken;
        address loanToken;
    }

    constructor(address owner) Ownable(owner) {
        iqLend = IQLend(Constants.IQ_LEND);
        fraxswapRouter = IFraxswapRouter(Constants.FRAXSWAP_ROUTER);
        curvePool = ICurvePool(Constants.CURVE_FRAX_USDC);
        iq = Constants.IQ;
        usdc = Constants.USDC;
        frax = Constants.FRAX;

        // Max approvals (same pattern as IQRouter)
        IERC20(Constants.USDC).approve(address(iqLend), type(uint256).max);
        IERC20(Constants.USDC).approve(address(curvePool), type(uint256).max);
        IERC20(Constants.IQ).approve(address(iqLend), type(uint256).max);
        IERC20(Constants.IQ).approve(address(fraxswapRouter), type(uint256).max);
        IERC20(Constants.FRAX).approve(address(curvePool), type(uint256).max);
        IERC20(Constants.FRAX).approve(address(fraxswapRouter), type(uint256).max);
    }

    /// @notice Liquidate an unhealthy position, swapping seized collateral to repay the loan.
    /// @param marketParams The Morpho market parameters.
    /// @param borrower The address of the unhealthy borrower.
    /// @param seizedAssets Amount of collateral to seize.
    function liquidate(
        MarketParams calldata marketParams,
        address borrower,
        uint256 seizedAssets
    )
        external
        returns (uint256 assetsSeized, uint256 assetsRepaid)
    {
        bytes memory data = abi.encode(
            CallbackData({ collateralToken: marketParams.collateralToken, loanToken: marketParams.loanToken })
        );

        (assetsSeized, assetsRepaid) = iqLend.liquidate(marketParams, borrower, seizedAssets, 0, data);

        // Sweep profit (loan token remainder + any dust) to caller
        _sweep(marketParams.loanToken, msg.sender);
        _sweep(marketParams.collateralToken, msg.sender);
    }

    /// @notice Morpho liquidation callback. Swaps seized collateral to loan token.
    /// @dev Only callable by IQLend. After this returns, Morpho pulls repaidAssets of loan token.
    function onMorphoLiquidate(uint256, bytes calldata data) external {
        require(msg.sender == address(iqLend), "not iqLend");

        CallbackData memory cb = abi.decode(data, (CallbackData));
        uint256 collateralBalance = IERC20(cb.collateralToken).balanceOf(address(this));

        if (cb.collateralToken == iq && cb.loanToken == usdc) {
            // Market 1 (Long): IQ collateral → FRAX → USDC
            _swapIQtoUSDC(collateralBalance);
        } else if (cb.collateralToken == usdc && cb.loanToken == iq) {
            // Market 2 (Short): USDC collateral → FRAX → IQ
            _swapUSDCtoIQ(collateralBalance);
        }
        // After return, Morpho pulls the loan token from this contract
    }

    /// @notice Swap IQ → FRAX (Fraxswap) → USDC (Curve)
    function _swapIQtoUSDC(uint256 amountIn) internal {
        address[] memory path = new address[](2);
        path[0] = iq;
        path[1] = frax;
        uint256[] memory amounts =
            fraxswapRouter.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
        curvePool.exchange(0, 1, amounts[1], 0);
    }

    /// @notice Swap USDC → FRAX (Curve) → IQ (Fraxswap)
    function _swapUSDCtoIQ(uint256 amountIn) internal {
        uint256 fraxOut = curvePool.exchange(1, 0, amountIn, 0);
        address[] memory path = new address[](2);
        path[0] = frax;
        path[1] = iq;
        fraxswapRouter.swapExactTokensForTokens(fraxOut, 0, path, address(this), block.timestamp);
    }

    function _sweep(address token, address to) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(to, balance);
        }
    }

    /// @notice Rescue tokens accidentally sent to the contract.
    function sweep(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }
}
