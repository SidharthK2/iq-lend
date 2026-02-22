// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { BaseRouterTest } from "./BaseRouterTest.sol";
import { Constants } from "../src/Constants.sol";
import { IOracle } from "../src/interfaces/IOracle.sol";
import { MarketParams, Id } from "@morpho-blue/interfaces/IMorpho.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 as console } from "forge-std/Test.sol";

contract LiquidationTest is BaseRouterTest {
    function testLiquidateLongPosition() public {
        // Open a 3x long
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 3e18, 0);
        vm.stopPrank();

        // Verify position exists
        (, uint256 borrowShares, uint256 collateral) = lend.position(market1Id, user);
        assertGt(borrowShares, 0, "should have borrow");
        assertGt(collateral, 0, "should have collateral");

        // Mock oracle to return a much lower IQ price (simulating 80% crash)
        uint256 currentPrice = IOracle(market1Params.oracle).price();
        uint256 crashedPrice = currentPrice / 5; // 80% drop
        vm.mockCall(
            market1Params.oracle,
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(crashedPrice)
        );

        // Liquidator seizes the position
        deal(Constants.USDC, liquidator, 10_000_000e6);
        vm.startPrank(liquidator);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);

        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = lend.market(market1Id);
        uint256 borrowAssets = uint256(borrowShares) * uint256(totalBorrowAssets) / uint256(totalBorrowShares);

        lend.liquidate(market1Params, user, collateral, 0, "");
        vm.stopPrank();

        // Position should be cleared
        (, uint256 borrowSharesAfter, uint256 collateralAfter) = lend.position(market1Id, user);
        assertEq(collateralAfter, 0, "collateral should be 0 after liquidation");

        vm.clearMockedCalls();
    }

    function testCannotLiquidateHealthyPosition() public {
        // Open a conservative 1.5x long
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 15e17, 0);
        vm.stopPrank();

        (, uint256 borrowShares, uint256 collateral) = lend.position(market1Id, user);
        assertGt(collateral, 0, "should have collateral");

        // Try to liquidate without price crash -- should revert
        deal(Constants.USDC, liquidator, 10_000_000e6);
        vm.startPrank(liquidator);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        vm.expectRevert();
        lend.liquidate(market1Params, user, collateral, 0, "");
        vm.stopPrank();
    }

    function testLiquidateShortPosition() public {
        // Open a 2x short
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openShort(1000e6, 2e18, 0);
        vm.stopPrank();

        (, uint256 borrowShares, uint256 collateral) = lend.position(market2Id, user);
        assertGt(borrowShares, 0, "should have borrow");
        assertGt(collateral, 0, "should have collateral");

        // Mock oracle to simulate IQ price surge (bad for shorts)
        // Market 2 oracle: price = IQ_per_USDC. If IQ surges, fewer IQ per USDC, so price drops.
        uint256 currentPrice = IOracle(market2Params.oracle).price();
        uint256 surgedPrice = currentPrice / 5; // IQ 5x surge means 1/5 the IQ per USDC
        vm.mockCall(
            market2Params.oracle,
            abi.encodeWithSelector(IOracle.price.selector),
            abi.encode(surgedPrice)
        );

        // Liquidator seizes the position
        deal(Constants.IQ, liquidator, 100_000_000e18);
        vm.startPrank(liquidator);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        lend.liquidate(market2Params, user, collateral, 0, "");
        vm.stopPrank();

        (, uint256 borrowSharesAfter, uint256 collateralAfter) = lend.position(market2Id, user);
        assertEq(collateralAfter, 0, "collateral should be 0 after liquidation");

        vm.clearMockedCalls();
    }
}
