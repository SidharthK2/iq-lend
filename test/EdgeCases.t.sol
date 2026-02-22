// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { BaseRouterTest } from "./BaseRouterTest.sol";
import { Constants } from "../src/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 as console } from "forge-std/Test.sol";

contract EdgeCasesTest is BaseRouterTest {
    function testSmallDustAmountLong() public {
        // Tiny position: 1 USDC (1e6)
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1e6);
        router.openLong(1e6, 2e18, 0);
        vm.stopPrank();

        (, uint256 borrowShares, uint256 collateral) = lend.position(market1Id, user);
        assertGt(borrowShares, 0, "dust long should have borrow");
        assertGt(collateral, 0, "dust long should have collateral");
    }

    function testSmallDustAmountShort() public {
        // Tiny position: 10 USDC
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 10e6);
        router.openShort(10e6, 2e18, 0);
        vm.stopPrank();

        (, uint256 borrowShares, uint256 collateral) = lend.position(market2Id, user);
        assertGt(borrowShares, 0, "dust short should have borrow");
        assertGt(collateral, 0, "dust short should have collateral");
    }

    function testZeroAmountLongReverts() public {
        vm.startPrank(user);
        vm.expectRevert();
        router.openLong(0, 2e18, 0);
        vm.stopPrank();
    }

    function testZeroAmountShortReverts() public {
        vm.startPrank(user);
        vm.expectRevert();
        router.openShort(0, 2e18, 0);
        vm.stopPrank();
    }

    function testCloseWithNoPositionLongReverts() public {
        vm.prank(user);
        vm.expectRevert();
        router.closeLong(0);
    }

    function testCloseWithNoPositionShortReverts() public {
        vm.prank(user);
        vm.expectRevert();
        router.closeShort(0);
    }
}
