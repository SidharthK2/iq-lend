// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { BaseRouterTest } from "./BaseRouterTest.sol";
import { Constants } from "../src/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 as console } from "forge-std/Test.sol";

contract MaxLeverageTest is BaseRouterTest {
    function testMaxLeverageLong3x() public {
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 3e18, 0);
        vm.stopPrank();

        (, uint256 borrowShares, uint256 collateral) = lend.position(market1Id, user);
        assertGt(borrowShares, 0, "should have borrow at 3x");
        assertGt(collateral, 0, "should have collateral at 3x");
    }

    function testOverLeverageLongReverts() public {
        // 4x exceeds max leverage for 70% LLTV (max ~3.33x)
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        vm.expectRevert();
        router.openLong(1000e6, 4e18, 0);
        vm.stopPrank();
    }

    function testMaxLeverageShort3x() public {
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openShort(1000e6, 3e18, 0);
        vm.stopPrank();

        (, uint256 borrowShares, uint256 collateral) = lend.position(market2Id, user);
        assertGt(borrowShares, 0, "should have borrow at 3x");
        assertGt(collateral, 0, "should have collateral at 3x");
    }

    function testOverLeverageShortReverts() public {
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        vm.expectRevert();
        router.openShort(1000e6, 4e18, 0);
        vm.stopPrank();
    }

    function testLeverageOf1xReverts() public {
        // 1x means no flash loan (leverageX18 - 1e18 = 0), should revert or be a no-op
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        vm.expectRevert();
        router.openLong(1000e6, 1e18, 0);
        vm.stopPrank();
    }
}
