// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { BaseRouterTest } from "./BaseRouterTest.sol";
import { Constants } from "../src/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 as console } from "forge-std/Test.sol";

contract FuzzTest is BaseRouterTest {
    function testFuzzOpenCloseLong(uint256 seedUsdc, uint256 leverageX18) public {
        // Bound seed between 10 USDC and 5k USDC (limited by AMM liquidity/slippage)
        seedUsdc = bound(seedUsdc, 10e6, 5000e6);
        // Bound leverage between 1.1x and 2.5x (safe margin for slippage)
        leverageX18 = bound(leverageX18, 11e17, 25e17);

        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), seedUsdc);
        router.openLong(seedUsdc, leverageX18, 0);

        (, uint256 borrowShares, uint256 collateral) = lend.position(market1Id, user);
        assertGt(borrowShares, 0, "should have borrow");
        assertGt(collateral, 0, "should have collateral");

        // Accrue interest before closing
        lend.accrueInterest(market1Params);

        router.closeLong(0);
        vm.stopPrank();

        (, uint256 borrowAfter, uint256 collateralAfter) = lend.position(market1Id, user);
        assertEq(borrowAfter, 0, "borrow should be 0 after close");
        assertEq(collateralAfter, 0, "collateral should be 0 after close");
    }

    function testFuzzOpenCloseShort(uint256 seedUsdc, uint256 leverageX18) public {
        // Bound seed between 100 USDC and 5k USDC (limited by AMM liquidity/slippage)
        seedUsdc = bound(seedUsdc, 100e6, 5000e6);
        // Bound leverage between 1.1x and 2.5x (safe margin for slippage)
        leverageX18 = bound(leverageX18, 11e17, 25e17);

        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), seedUsdc);
        router.openShort(seedUsdc, leverageX18, 0);

        (, uint256 borrowShares, uint256 collateral) = lend.position(market2Id, user);
        assertGt(borrowShares, 0, "should have borrow");
        assertGt(collateral, 0, "should have collateral");

        // Accrue interest before closing
        lend.accrueInterest(market2Params);

        router.closeShort(0);
        vm.stopPrank();

        (, uint256 borrowAfter, uint256 collateralAfter) = lend.position(market2Id, user);
        assertEq(borrowAfter, 0, "borrow should be 0 after close");
        assertEq(collateralAfter, 0, "collateral should be 0 after close");
    }
}
