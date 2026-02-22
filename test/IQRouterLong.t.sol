// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { IQRouter } from "../src/IQRouter.sol";
import { Constants } from "../src/Constants.sol";
import { MarketParams, Id } from "@morpho-blue/interfaces/IMorpho.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console2 as console } from "forge-std/Test.sol";

contract IQRouterLongTest is Test {
    using MarketParamsLib for MarketParams;

    IQLend lend;
    IQRouter router;
    MarketParams market1Params;
    Id market1Id;

    address user = makeAddr("user");
    address liquidityProvider = makeAddr("lp");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_MAINNET_URL"));

        lend = IQLend(Constants.IQ_LEND);
        router = new IQRouter(address(this));

        market1Params = MarketParams({
            loanToken: Constants.USDC,
            collateralToken: Constants.IQ,
            oracle: Constants.IQ_ORACLE_MARKET1,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });
        market1Id = market1Params.id();

        // Create market 1 if needed
        (,,,, uint128 lastUpdate,) = lend.market(market1Id);
        if (lastUpdate == 0) {
            vm.startPrank(lend.owner());
            try lend.enableIrm(Constants.IRM) { } catch { }
            try lend.enableLltv(Constants.LLTV) { } catch { }
            lend.createMarket(market1Params);
            vm.stopPrank();
        }

        // Set caps for market 1
        vm.prank(lend.owner());
        lend.setCaps(market1Id, 50_000_000e6, 50_000_000e6);

        // Seed market 1 with USDC liquidity so borrows can succeed
        deal(Constants.USDC, liquidityProvider, 10_000_000e6);
        vm.startPrank(liquidityProvider);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        lend.supply(market1Params, 10_000_000e6, 0, liquidityProvider, "");
        vm.stopPrank();

        // Fund user with USDC
        deal(Constants.USDC, user, 10_000e6);

        // User authorizes router to act on their behalf in IQLend
        vm.prank(user);
        lend.setAuthorization(address(router), true);
    }

    function testOpenLong() public {
        uint256 seedUsdc = 100e6;
        uint256 leverage = 2e18; // 2x

        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), seedUsdc);
        router.openLong(seedUsdc, leverage, 0); // minIQOut=0 for fork test
        vm.stopPrank();

        // User should have a position in market 1: IQ collateral > 0, USDC borrow > 0
        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) = lend.position(market1Id, user);
        assertEq(supplyShares, 0, "user should have no supply shares");
        assertGt(borrowShares, 0, "user should have USDC borrow shares");
        assertGt(collateral, 0, "user should have IQ collateral");

        console.log("IQ collateral:", collateral);
        console.log("USDC borrow shares:", borrowShares);

        // User's USDC balance should have decreased by seedUsdc
        uint256 userUsdcAfter = IERC20(Constants.USDC).balanceOf(user);
        assertEq(userUsdcAfter, 10_000e6 - seedUsdc, "user USDC balance should decrease by seed amount");
    }

    function testCloseLong() public {
        uint256 seedUsdc = 100e6;
        uint256 leverage = 2e18;

        // Open long first
        vm.startPrank(user);
        IERC20(Constants.USDC).approve(address(router), seedUsdc);
        router.openLong(seedUsdc, leverage, 0);

        // Verify position exists
        (, uint128 borrowSharesBefore, uint128 collateralBefore) = lend.position(market1Id, user);
        assertGt(borrowSharesBefore, 0, "should have borrow before close");
        assertGt(collateralBefore, 0, "should have collateral before close");

        console.log("--- Before close ---");
        console.log("IQ collateral:", collateralBefore);
        console.log("USDC borrow shares:", borrowSharesBefore);

        // Close the long
        router.closeLong(0); // minUsdcOut=0 for fork test
        vm.stopPrank();

        // Position should be fully closed
        (uint256 supplySharesAfter, uint128 borrowSharesAfter, uint128 collateralAfter) = lend.position(market1Id, user);
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

    function testOpenLongRevertsWithNoApproval() public {
        address noApprovalUser = makeAddr("noApproval");
        deal(Constants.USDC, noApprovalUser, 1000e6);

        vm.startPrank(noApprovalUser);
        IERC20(Constants.USDC).approve(address(router), 1000e6);
        vm.expectRevert();
        router.openLong(1000e6, 2e18, 0);
        vm.stopPrank();
    }
}
