// SPDX-License-Identifier: ISC
pragma solidity >=0.8.20;

import { Id, MarketParams } from "@morpho-blue/interfaces/IMorpho.sol";
import { IMorphoFlashLoanCallback } from "@morpho-blue/interfaces/IMorphoCallbacks.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "@morpho-blue/libraries/SharesMathLib.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IFraxswapRouter } from "./interfaces/IFraxswapRouter.sol";
import { ICurvePool } from "./interfaces/ICurvePool.sol";
import { IQLend } from "./IQLend.sol";
import { IOracle } from "./interfaces/IOracle.sol";

import { Constants } from "./Constants.sol";

/// @title IQRouter
/// @notice Router for opening and closing leveraged long and short positions on IQ token via Morpho Blue flash loans.
/// @dev Routes through IQLend flash loans, Fraxswap (IQ<->FRAX), and Curve (FRAX<->USDC).
///      Market 1 is long IQ (collateral=IQ, loan=USDC); Market 2 is short IQ (collateral=USDC, loan=IQ).
contract IQRouter is IMorphoFlashLoanCallback, Ownable {
    using SafeERC20 for IERC20;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    /// @notice USDC token address.
    address public usdc = Constants.USDC;
    /// @notice IQ token address.
    address public iq = Constants.IQ;
    /// @notice FRAX token address.
    address public frax = Constants.FRAX;

    /// @notice IQLend lending contract used for flash loans and position management.
    IQLend public iqLend = IQLend(Constants.IQ_LEND);
    /// @notice Fraxswap router used for IQ<->FRAX swaps.
    IFraxswapRouter public fraxswapRouter = IFraxswapRouter(Constants.FRAXSWAP_ROUTER);
    /// @notice Curve pool used for FRAX<->USDC stablecoin swaps.
    ICurvePool public curvePool = ICurvePool(Constants.CURVE_FRAX_USDC);

    /// @notice Market params for market 1: long IQ (collateral=IQ, loan=USDC).
    MarketParams public market1Params;
    /// @notice Morpho market ID for market 1.
    Id public market1Id;

    /// @notice Market params for market 2: short IQ (collateral=USDC, loan=IQ).
    MarketParams public market2Params;
    /// @notice Morpho market ID for market 2.
    Id public market2Id;

    /// @notice Actions encoded into flash loan callback data to identify the leverage operation.
    enum Action {
        OPEN_LONG,
        CLOSE_LONG,
        OPEN_SHORT,
        CLOSE_SHORT
    }

    /// @notice Deploys IQRouter, grants max token approvals, and initialises market params.
    /// @param owner Initial owner of the contract.
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

    /// @notice Opens a leveraged long position on IQ.
    /// @dev Flash borrows additional USDC from IQLend, swaps the combined USDC (seed + flash) to IQ via
    ///      FRAX, supplies IQ as collateral in market 1, then borrows USDC to repay the flash loan.
    /// @param usdcAmount Amount of USDC the caller contributes as seed capital (pulled from caller).
    /// @param leverageX18 Desired leverage multiplier scaled by 1e18 (e.g. 2e18 = 2x). Must be > 1e18.
    /// @param minIQOut Minimum IQ to receive from the USDC->FRAX->IQ swap (slippage protection).
    function openLong(uint256 usdcAmount, uint256 leverageX18, uint256 minIQOut) external {
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), usdcAmount);
        uint256 flashAmount = (usdcAmount * (leverageX18 - 1e18)) / 1e18;
        bytes memory data = abi.encode(msg.sender, usdcAmount, minIQOut, Action.OPEN_LONG);
        iqLend.flashLoan(usdc, flashAmount, data);
    }

    /// @notice Closes an existing leveraged long position in market 1.
    /// @dev Calculates the caller's full USDC debt, flash borrows that amount from IQLend, repays the
    ///      debt, withdraws IQ collateral, swaps IQ back to USDC, repays the flash loan, and forwards
    ///      any residual USDC to the caller.
    /// @param minUsdcOut Minimum net USDC to receive after unwinding the position (slippage protection).
    function closeLong(uint256 minUsdcOut) external {
        (, uint256 borrowShares,) = iqLend.position(market1Id, msg.sender);
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = iqLend.market(market1Id);
        uint256 borrowAssets = borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
        bytes memory data = abi.encode(msg.sender, borrowAssets, minUsdcOut, Action.CLOSE_LONG);
        iqLend.flashLoan(usdc, borrowAssets, data);
        uint256 residualAmt = IERC20(usdc).balanceOf(address(this));
        IERC20(usdc).safeTransfer(msg.sender, residualAmt);
    }

    /// @notice Opens a leveraged short position on IQ.
    /// @dev Computes the IQ flash loan amount from the Market 2 oracle price, flash borrows IQ, sells it
    ///      for USDC via FRAX, supplies seed + swapped USDC as collateral in market 2, then borrows IQ
    ///      to repay the flash loan.
    /// @param usdcAmount Amount of USDC the caller contributes as seed capital (pulled from caller).
    /// @param leverageX18 Desired leverage multiplier scaled by 1e18 (e.g. 2e18 = 2x). Must be > 1e18.
    /// @param minUsdcCollateral Minimum total USDC collateral after swap (slippage protection).
    function openShort(uint256 usdcAmount, uint256 leverageX18, uint256 minUsdcCollateral) external {
        IERC20(usdc).safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Compute how much IQ to flash loan: convert the borrowed USDC portion to IQ using the oracle.
        // Market 2 oracle: price() = IQ per USDC scaled by 1e36.
        uint256 usdcBorrowed = (usdcAmount * (leverageX18 - 1e18)) / 1e18;
        uint256 oraclePrice = IOracle(market2Params.oracle).price();
        uint256 iqFlashAmount = (usdcBorrowed * oraclePrice) / 1e36;

        bytes memory data = abi.encode(msg.sender, usdcAmount, minUsdcCollateral, Action.OPEN_SHORT);
        iqLend.flashLoan(iq, iqFlashAmount, data);
    }

    /// @notice Closes an existing leveraged short position in market 2.
    /// @dev Flash borrows IQ to repay the full debt, withdraws USDC collateral, swaps all USDC to IQ
    ///      to cover the flash loan repayment. After the callback, any leftover IQ is swapped back to
    ///      USDC and forwarded to the caller along with any residual USDC.
    /// @param minUsdcOut Minimum net USDC to receive after unwinding the position (slippage protection).
    function closeShort(uint256 minUsdcOut) external {
        (, uint256 borrowShares,) = iqLend.position(market2Id, msg.sender);
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = iqLend.market(market2Id);
        uint256 borrowAssets = borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares);
        bytes memory data = abi.encode(msg.sender, borrowAssets, minUsdcOut, Action.CLOSE_SHORT);
        iqLend.flashLoan(iq, borrowAssets, data);

        // Swap any leftover IQ back to USDC
        uint256 iqBalance = IERC20(iq).balanceOf(address(this));
        if (iqBalance > 0) {
            address[] memory path = new address[](2);
            path[0] = iq;
            path[1] = frax;
            uint256[] memory amounts =
                fraxswapRouter.swapExactTokensForTokens(iqBalance, 0, path, address(this), block.timestamp);
            curvePool.exchange(0, 1, amounts[1], 0);
        }

        // Forward residual USDC to user
        uint256 residualAmt = IERC20(usdc).balanceOf(address(this));
        require(residualAmt >= minUsdcOut, "slippage");
        IERC20(usdc).safeTransfer(msg.sender, residualAmt);
    }

    /// @notice Morpho Blue flash loan callback. Executes the leverage action encoded in `data`.
    /// @dev Only callable by IQLend. Decodes the action and routes to the appropriate handler.
    /// @param assets Amount of tokens received in the flash loan (must be returned by end of call).
    /// @param data ABI-encoded tuple: (address user, uint256 userAmount, uint256 minAmtOut, Action action).
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

        if (action == Action.CLOSE_LONG) {
            iqLend.repay(market1Params, assets, 0, user, "");
            (,, uint256 collateral) = iqLend.position(market1Id, user);
            iqLend.withdrawCollateral(market1Params, collateral, user, address(this));
            address[] memory path = new address[](2);
            path[0] = iq;
            path[1] = frax;
            uint256[] memory amounts =
                fraxswapRouter.swapExactTokensForTokens(collateral, minAmtOut, path, address(this), block.timestamp);
            curvePool.exchange(0, 1, amounts[1], 0);
        }

        if (action == Action.OPEN_SHORT) {
            // Swap flash-loaned IQ -> FRAX
            address[] memory path = new address[](2);
            path[0] = iq;
            path[1] = frax;
            uint256[] memory amounts =
                fraxswapRouter.swapExactTokensForTokens(assets, 0, path, address(this), block.timestamp);

            // FRAX -> USDC
            uint256 usdcOut = curvePool.exchange(0, 1, amounts[1], 0);

            // Supply seed USDC + swapped USDC as collateral in market 2
            uint256 totalUsdc = userAmount + usdcOut;
            require(totalUsdc >= minAmtOut, "slippage");
            iqLend.supplyCollateral(market2Params, totalUsdc, user, "");

            // Borrow IQ to repay flash loan
            iqLend.borrow(market2Params, assets, 0, user, address(this));
        }

        if (action == Action.CLOSE_SHORT) {
            // Repay IQ debt
            iqLend.repay(market2Params, assets, 0, user, "");

            // Withdraw all USDC collateral
            (,, uint256 collateral) = iqLend.position(market2Id, user);
            iqLend.withdrawCollateral(market2Params, collateral, user, address(this));

            // Swap USDC -> FRAX -> IQ to cover flash loan repayment
            uint256 fraxOut = curvePool.exchange(1, 0, collateral, 0);
            address[] memory path = new address[](2);
            path[0] = frax;
            path[1] = iq;
            fraxswapRouter.swapExactTokensForTokens(fraxOut, assets, path, address(this), block.timestamp);
        }
    }
}
