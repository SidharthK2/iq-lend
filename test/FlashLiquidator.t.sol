// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { BaseRouterTest } from "./BaseRouterTest.sol";
import { FlashLiquidator } from "../src/FlashLiquidator.sol";
import { Constants } from "../src/Constants.sol";
import { IOracle } from "../src/interfaces/IOracle.sol";
import { MarketParams, Id } from "@morpho-blue/interfaces/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 as console } from "forge-std/Test.sol";

contract FlashLiquidatorTest is BaseRouterTest {
    FlashLiquidator flashLiq;

    function setUp() public override {
        super.setUp();
        flashLiq = new FlashLiquidator(address(this));
    }

    // ─── Market 1 (Long IQ): collateral = IQ, loan = USDC ──────────────

    function testFlashLiquidateLongPosition() public {
        // Open a 3x long
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 3e18, 0);
        vm.stopPrank();

        // Verify position exists on-chain
        (, uint256 borrowShares, uint256 collateral) = lend.position(market1Id, user);
        assertGt(borrowShares, 0, "should have borrow shares");
        assertGt(collateral, 0, "should have collateral");

        // Liquidator starts with zero capital
        assertEq(IERC20(Constants.USDC).balanceOf(liquidator), 0, "liquidator must start with 0 USDC");
        assertEq(IERC20(Constants.IQ).balanceOf(liquidator), 0, "liquidator must start with 0 IQ");

        // Mock oracle: 80% IQ crash makes position liquidatable
        uint256 realPrice = IOracle(market1Params.oracle).price();
        uint256 crashedPrice = realPrice / 5;
        vm.mockCall(market1Params.oracle, abi.encodeWithSelector(IOracle.price.selector), abi.encode(crashedPrice));

        // Liquidate — capital-free, all swap through real Fraxswap + Curve
        vm.prank(liquidator);
        (uint256 assetsSeized, uint256 assetsRepaid) = flashLiq.liquidate(market1Params, user, collateral);

        assertGt(assetsSeized, 0, "must seize collateral");
        assertGt(assetsRepaid, 0, "must repay debt");

        // Position should be cleared
        (, uint256 borrowSharesAfter, uint256 collateralAfter) = lend.position(market1Id, user);
        assertEq(collateralAfter, 0, "collateral must be 0 after full seizure");

        // Liquidator must have profited (received USDC from the mocked-vs-real price arb)
        uint256 profit = IERC20(Constants.USDC).balanceOf(liquidator);
        assertGt(profit, 0, "liquidator must profit in USDC");

        // FlashLiquidator contract must not hold any residual tokens
        assertEq(IERC20(Constants.USDC).balanceOf(address(flashLiq)), 0, "no residual USDC in contract");
        assertEq(IERC20(Constants.IQ).balanceOf(address(flashLiq)), 0, "no residual IQ in contract");

        vm.clearMockedCalls();
    }

    function testFlashLiquidateLongPartialSeizure() public {
        // Open a 3x long
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 3e18, 0);
        vm.stopPrank();

        (, uint256 borrowSharesBefore, uint256 collateral) = lend.position(market1Id, user);

        // Mock 80% crash
        uint256 realPrice = IOracle(market1Params.oracle).price();
        vm.mockCall(market1Params.oracle, abi.encodeWithSelector(IOracle.price.selector), abi.encode(realPrice / 5));

        // Seize only half the collateral
        uint256 halfCollateral = collateral / 2;
        vm.prank(liquidator);
        flashLiq.liquidate(market1Params, user, halfCollateral);

        // Position should be partially remaining
        (, uint256 borrowSharesAfter, uint256 collateralAfter) = lend.position(market1Id, user);
        assertGt(collateralAfter, 0, "should have remaining collateral");
        assertLt(collateralAfter, collateral, "collateral must have decreased");
        assertLt(borrowSharesAfter, borrowSharesBefore, "borrow shares must have decreased");

        vm.clearMockedCalls();
    }

    // ─── Market 2 (Short IQ): collateral = USDC, loan = IQ ─────────────

    function testFlashLiquidateShortPosition() public {
        // Open a 2x short
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openShort(1000e6, 2e18, 0);
        vm.stopPrank();

        // Verify position exists on-chain
        (, uint256 borrowShares, uint256 collateral) = lend.position(market2Id, user);
        assertGt(borrowShares, 0, "should have borrow shares");
        assertGt(collateral, 0, "should have collateral");

        // Liquidator starts with zero capital
        assertEq(IERC20(Constants.USDC).balanceOf(liquidator), 0, "liquidator must start with 0 USDC");
        assertEq(IERC20(Constants.IQ).balanceOf(liquidator), 0, "liquidator must start with 0 IQ");

        // Mock oracle: IQ price surges (bad for shorts).
        // Market 2 oracle = IQ per USDC. Surge means fewer IQ per USDC → price drops.
        uint256 realPrice = IOracle(market2Params.oracle).price();
        uint256 surgedPrice = realPrice / 5;
        vm.mockCall(market2Params.oracle, abi.encodeWithSelector(IOracle.price.selector), abi.encode(surgedPrice));

        // Liquidate — capital-free
        vm.prank(liquidator);
        (uint256 assetsSeized, uint256 assetsRepaid) = flashLiq.liquidate(market2Params, user, collateral);

        assertGt(assetsSeized, 0, "must seize collateral");
        assertGt(assetsRepaid, 0, "must repay debt");

        // Position should be cleared
        (, uint256 borrowSharesAfter, uint256 collateralAfter) = lend.position(market2Id, user);
        assertEq(collateralAfter, 0, "collateral must be 0 after full seizure");

        // Liquidator must have received profit (IQ and/or USDC)
        uint256 iqProfit = IERC20(Constants.IQ).balanceOf(liquidator);
        uint256 usdcProfit = IERC20(Constants.USDC).balanceOf(liquidator);
        assertTrue(iqProfit > 0 || usdcProfit > 0, "liquidator must receive profit");

        // FlashLiquidator contract must not hold any residual tokens
        assertEq(IERC20(Constants.USDC).balanceOf(address(flashLiq)), 0, "no residual USDC in contract");
        assertEq(IERC20(Constants.IQ).balanceOf(address(flashLiq)), 0, "no residual IQ in contract");

        vm.clearMockedCalls();
    }

    // ─── Revert cases
    // ───────────────────────────────────────────────────

    function testFlashLiquidateHealthyPositionReverts() public {
        // Open a conservative 1.5x long
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 15e17, 0);
        vm.stopPrank();

        (,, uint256 collateral) = lend.position(market1Id, user);
        assertGt(collateral, 0, "should have collateral");

        // No price crash — position is healthy — must revert
        vm.prank(liquidator);
        vm.expectRevert();
        flashLiq.liquidate(market1Params, user, collateral);
    }

    function testOnMorphoLiquidateOnlyIQLend() public {
        bytes memory data =
            abi.encode(FlashLiquidator.CallbackData({ collateralToken: Constants.IQ, loanToken: Constants.USDC }));

        // Direct call from non-IQLend address must revert
        vm.prank(liquidator);
        vm.expectRevert("not iqLend");
        flashLiq.onMorphoLiquidate(0, data);
    }

    // ─── Sweep access control
    // ───────────────────────────────────────────

    function testSweepOnlyOwner() public {
        vm.prank(liquidator);
        vm.expectRevert();
        flashLiq.sweep(Constants.USDC, liquidator, 0);
    }

    function testSweepByOwner() public {
        deal(Constants.USDC, address(flashLiq), 100e6);

        uint256 before = IERC20(Constants.USDC).balanceOf(address(this));
        flashLiq.sweep(Constants.USDC, address(this), 100e6);
        uint256 received = IERC20(Constants.USDC).balanceOf(address(this)) - before;

        assertEq(received, 100e6, "owner must receive swept tokens");
        assertEq(IERC20(Constants.USDC).balanceOf(address(flashLiq)), 0, "contract must be empty after sweep");
    }
}
