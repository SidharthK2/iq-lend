// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { BaseRouterTest } from "./BaseRouterTest.sol";
import { Constants } from "../src/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { console2 as console } from "forge-std/Test.sol";

contract InterestAccrualTest is BaseRouterTest {
    function testInterestAccruesOnLong() public {
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 2e18, 0);
        vm.stopPrank();

        (, uint256 borrowSharesBefore,) = lend.position(market1Id, user);
        (,, uint128 totalBorrowAssetsBefore, uint128 totalBorrowSharesBefore,,) = lend.market(market1Id);
        uint256 debtBefore =
            uint256(borrowSharesBefore) * uint256(totalBorrowAssetsBefore) / uint256(totalBorrowSharesBefore);

        // Warp 30 days
        vm.warp(block.timestamp + 30 days);
        lend.accrueInterest(market1Params);

        (,, uint128 totalBorrowAssetsAfter, uint128 totalBorrowSharesAfter,,) = lend.market(market1Id);
        uint256 debtAfter =
            uint256(borrowSharesBefore) * uint256(totalBorrowAssetsAfter) / uint256(totalBorrowSharesAfter);

        assertGt(debtAfter, debtBefore, "debt should increase after interest accrual");
        console.log("Debt before:", debtBefore);
        console.log("Debt after:", debtAfter);
        console.log("Interest accrued:", debtAfter - debtBefore);
    }

    function testInterestAccruesOnShort() public {
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openShort(1000e6, 2e18, 0);
        vm.stopPrank();

        (, uint256 borrowSharesBefore,) = lend.position(market2Id, user);
        (,, uint128 totalBorrowAssetsBefore, uint128 totalBorrowSharesBefore,,) = lend.market(market2Id);
        uint256 debtBefore =
            uint256(borrowSharesBefore) * uint256(totalBorrowAssetsBefore) / uint256(totalBorrowSharesBefore);

        vm.warp(block.timestamp + 30 days);
        lend.accrueInterest(market2Params);

        (,, uint128 totalBorrowAssetsAfter, uint128 totalBorrowSharesAfter,,) = lend.market(market2Id);
        uint256 debtAfter =
            uint256(borrowSharesBefore) * uint256(totalBorrowAssetsAfter) / uint256(totalBorrowSharesAfter);

        assertGt(debtAfter, debtBefore, "debt should increase after interest accrual");
        console.log("Debt before:", debtBefore);
        console.log("Debt after:", debtAfter);
        console.log("Interest accrued:", debtAfter - debtBefore);
    }

    function testCloseLongAfterInterestAccrual() public {
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        router.openLong(1000e6, 2e18, 0);
        vm.stopPrank();

        // Warp a short period to accrue some interest
        vm.warp(block.timestamp + 1 hours);

        vm.prank(user);
        router.closeLong(0);

        (, uint256 borrowSharesAfter, uint256 collateralAfter) = lend.position(market1Id, user);
        assertEq(borrowSharesAfter, 0, "borrow should be 0 after close");
        assertEq(collateralAfter, 0, "collateral should be 0 after close");
    }
}
