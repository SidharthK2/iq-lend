// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { IQRouter } from "../src/IQRouter.sol";
import { Constants } from "../src/Constants.sol";
import { MarketParams, Id } from "@morpho-blue/interfaces/IMorpho.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console2 as console } from "forge-std/Test.sol";

contract IQRouterShortTest is Test {
    using MarketParamsLib for MarketParams;

    IQLend lend;
    IQRouter router;
    MarketParams market2Params;
    Id market2Id;

    address user = makeAddr("user");
    address liquidityProvider = makeAddr("lp");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_MAINNET_URL"));

        lend = IQLend(Constants.IQ_LEND);
        router = new IQRouter(address(this));

        market2Params = MarketParams({
            loanToken: Constants.IQ,
            collateralToken: Constants.USDC,
            oracle: Constants.IQ_ORACLE_MARKET2,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });
        market2Id = market2Params.id();

        // Create market 2 if needed
        (,,,, uint128 lastUpdate,) = lend.market(market2Id);
        if (lastUpdate == 0) {
            vm.startPrank(lend.owner());
            try lend.enableIrm(Constants.IRM) {} catch {}
            try lend.enableLltv(Constants.LLTV) {} catch {}
            lend.createMarket(market2Params);
            vm.stopPrank();
        }

        // Set caps for market 2
        vm.prank(lend.owner());
        lend.setCaps(market2Id, 50_000_000e18, 50_000_000e18);

        // Seed market 2 with IQ liquidity so borrows can succeed
        deal(Constants.IQ, liquidityProvider, 10_000_000e18);
        vm.startPrank(liquidityProvider);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        lend.supply(market2Params, 10_000_000e18, 0, liquidityProvider, "");
        vm.stopPrank();

        // Fund user with USDC
        deal(Constants.USDC, user, 10_000e6);

        // User authorizes router to act on their behalf in IQLend
        vm.prank(user);
        lend.setAuthorization(address(router), true);
    }

    function testOpenShort() public {
        uint256 seedUsdc = 1_000e6;
        uint256 leverage = 2e18; // 2x

        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), seedUsdc);
        router.openShort(seedUsdc, leverage, 0); // minUsdcCollateral=0 for fork test
        vm.stopPrank();

        // User should have a position in market 2: USDC collateral > 0, IQ borrow > 0
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = lend.position(market2Id, user);
        assertEq(supplyShares, 0, "user should have no supply shares");
        assertGt(borrowShares, 0, "user should have IQ borrow shares");
        assertGt(collateral, 0, "user should have USDC collateral");

        console.log("USDC collateral:", collateral);
        console.log("IQ borrow shares:", borrowShares);

        // Collateral should be roughly 2x the seed (minus swap fees)
        assertGt(collateral, seedUsdc * 15 / 10, "collateral should be > 1.5x seed (accounting for slippage)");

        // User's USDC balance should have decreased by seedUsdc
        uint256 userUsdcAfter = IERC20(Constants.USDC).balanceOf(user);
        assertEq(userUsdcAfter, 10_000e6 - seedUsdc, "user USDC balance should decrease by seed amount");
    }

    function testCloseShort() public {
        uint256 seedUsdc = 1_000e6;
        uint256 leverage = 2e18;

        // Open short first
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), seedUsdc);
        router.openShort(seedUsdc, leverage, 0);

        // Verify position exists
        (,uint128 borrowSharesBefore, uint128 collateralBefore) = lend.position(market2Id, user);
        assertGt(borrowSharesBefore, 0, "should have borrow before close");
        assertGt(collateralBefore, 0, "should have collateral before close");

        console.log("--- Before close ---");
        console.log("USDC collateral:", collateralBefore);
        console.log("IQ borrow shares:", borrowSharesBefore);

        // Close the short
        router.closeShort(0); // minUsdcOut=0 for fork test
        vm.stopPrank();

        // Position should be fully closed
        (uint256 supplySharesAfter, uint128 borrowSharesAfter, uint128 collateralAfter) =
            lend.position(market2Id, user);
        assertEq(supplySharesAfter, 0, "supply shares should be 0 after close");
        assertEq(borrowSharesAfter, 0, "borrow shares should be 0 after close");
        assertEq(collateralAfter, 0, "collateral should be 0 after close");

        // User should have received USDC back (seed minus swap costs)
        uint256 userUsdcFinal = IERC20(Constants.USDC).balanceOf(user);
        console.log("--- After close ---");
        console.log("User USDC balance:", userUsdcFinal);
        console.log("Net cost (slippage + fees):", 10_000e6 - userUsdcFinal);

        // User should get back most of their seed (losses are only from swap fees/slippage)
        assertGt(userUsdcFinal, 10_000e6 - seedUsdc, "user should get back more than 9000 USDC");
    }

    function testOpenShortRevertsWithNoApproval() public {
        address noApprovalUser = makeAddr("noApproval");
        deal(Constants.USDC, noApprovalUser, 1_000e6);

        vm.startPrank(noApprovalUser);
        IERC20(Constants.USDC).approve(address(router), 1_000e6);
        // User hasn't called lend.setAuthorization(router, true)
        // The borrow call inside the callback should revert
        vm.expectRevert();
        router.openShort(1_000e6, 2e18, 0);
        vm.stopPrank();
    }
}
