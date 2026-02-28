// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
import { IOracle } from "../src/interfaces/IOracle.sol";
import { MarketParams, Id } from "@morpho-blue/interfaces/IMorpho.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console2 as console } from "forge-std/Test.sol";

contract IQLendE2ETest is Test {
    using MarketParamsLib for MarketParams;

    IQLend lend;
    MarketParams market1Params;
    Id market1Id;

    address supplier = makeAddr("supplier");
    address borrower = makeAddr("borrower");

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        lend = IQLend(Constants.IQ_LEND);

        market1Params = MarketParams({
            loanToken: Constants.USDC,
            collateralToken: Constants.IQ,
            oracle: Constants.IQ_ORACLE_MARKET1,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });
        market1Id = market1Params.id();

        // Create market if not already created
        (,,,, uint128 lastUpdate,) = lend.market(market1Id);
        if (lastUpdate == 0) {
            vm.startPrank(lend.owner());
            try lend.enableIrm(Constants.IRM) { } catch { }
            try lend.enableLltv(Constants.LLTV) { } catch { }
            lend.createMarket(market1Params);
            vm.stopPrank();
        }

        // Set caps high so tests work regardless of existing mainnet state
        vm.prank(lend.owner());
        lend.setCaps(market1Id, 10_000e6, 10_000e6);

        // Fund accounts
        deal(Constants.USDC, supplier, 1000e6);
        deal(Constants.IQ, borrower, 1_000_000e18);
    }

    function testSupplyCapEnforced() public {
        vm.startPrank(supplier);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        lend.supply(market1Params, 100e6, 0, supplier, "");
        vm.stopPrank();

        // Set cap to current total supply so next supply reverts
        (uint128 totalSupplyAssets,,,,,) = lend.market(market1Id);
        vm.prank(lend.owner());
        lend.setCaps(market1Id, totalSupplyAssets, 10_000e6);

        vm.startPrank(supplier);
        vm.expectRevert("supply cap reached");
        lend.supply(market1Params, 1e6, 0, supplier, "");
        vm.stopPrank();
    }

    function testBorrowCapEnforced() public {
        // Supply first
        vm.startPrank(supplier);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        lend.supply(market1Params, 500e6, 0, supplier, "");
        vm.stopPrank();

        // Deposit collateral and borrow
        vm.startPrank(borrower);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        lend.supplyCollateral(market1Params, 1_000_000e18, borrower, "");
        lend.borrow(market1Params, 100e6, 0, borrower, borrower);
        vm.stopPrank();

        // Set borrow cap to current total borrows so next borrow reverts
        (,, uint128 totalBorrowAssets,,,) = lend.market(market1Id);
        vm.prank(lend.owner());
        lend.setCaps(market1Id, 10_000e6, totalBorrowAssets);

        vm.startPrank(borrower);
        vm.expectRevert("borrow cap reached");
        lend.borrow(market1Params, 1e6, 0, borrower, borrower);
        vm.stopPrank();
    }

    function testFullFlow() public {
        // Sanity: oracle returns a real price on this fork
        uint256 iqPrice = IOracle(market1Params.oracle).price();
        assertGt(iqPrice, 0, "oracle must return non-zero price on mainnet fork");

        // ── 1. Supply USDC
        // ──────────────────────────────────────────────
        vm.startPrank(supplier);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        (, uint256 supplyShares) = lend.supply(market1Params, 500e6, 0, supplier, "");
        vm.stopPrank();

        // On-chain: supplier position records exact supply shares
        assertGt(supplyShares, 0, "supply must mint shares");
        (uint256 supplierSharesOnChain,,) = lend.position(market1Id, supplier);
        assertEq(supplierSharesOnChain, supplyShares, "on-chain supply shares must match");

        // ── 2. Deposit IQ collateral + borrow USDC ─────────────────────
        vm.startPrank(borrower);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);

        lend.supplyCollateral(market1Params, 1_000_000e18, borrower, "");

        // On-chain: collateral recorded
        (,, uint256 collateralOnChain) = lend.position(market1Id, borrower);
        assertEq(collateralOnChain, 1_000_000e18, "on-chain collateral must match deposit");
        assertEq(IERC20(Constants.IQ).balanceOf(borrower), 0, "all IQ should be deposited");

        uint256 borrowAmount = 100e6;
        lend.borrow(market1Params, borrowAmount, 0, borrower, borrower);

        // On-chain: borrow shares created, exact USDC received (borrower started with 0 USDC)
        (, uint256 borrowSharesOnChain,) = lend.position(market1Id, borrower);
        assertGt(borrowSharesOnChain, 0, "on-chain borrow shares must be positive");
        assertEq(IERC20(Constants.USDC).balanceOf(borrower), borrowAmount, "borrower must receive exact borrow amount");

        // ── 3. Repay
        // ────────────────────────────────────────────────────
        lend.repay(market1Params, borrowAmount, 0, borrower, "");

        // On-chain: borrow shares reduced to at most 1 (Morpho rounds toSharesDown on repay,
        // which can leave 1 share of dust when the original borrow used toSharesUp)
        (, uint256 borrowSharesAfterRepay,) = lend.position(market1Id, borrower);
        assertLe(borrowSharesAfterRepay, 1, "repay must clear debt to at most 1 share of dust");
        assertEq(IERC20(Constants.USDC).balanceOf(borrower), 0, "borrower spent all USDC on repay");

        // ── 4. Withdraw collateral
        // ──────────────────────────────────────
        // Dust borrow share means full withdrawal reverts (expected Morpho behavior).
        // Withdraw 999k IQ, leaving 1k as collateral buffer for the dust.
        lend.withdrawCollateral(market1Params, 999_000e18, borrower, borrower);

        (,, uint256 remainingCollateral) = lend.position(market1Id, borrower);
        assertEq(remainingCollateral, 1000e18, "1000 IQ must remain as collateral for dust debt");
        assertEq(IERC20(Constants.IQ).balanceOf(borrower), 999_000e18, "borrower must receive withdrawn IQ");
        vm.stopPrank();

        // ── 5. Supplier withdraws
        // ───────────────────────────────────────
        // Withdraw by shares to avoid the toSharesUp rounding that would
        // overflow position.supplyShares when withdrawing by assets.
        vm.startPrank(supplier);
        lend.withdraw(market1Params, 0, supplyShares, supplier, supplier);

        // On-chain: supply position fully cleared
        (uint256 supplierSharesAfter,,) = lend.position(market1Id, supplier);
        assertEq(supplierSharesAfter, 0, "supplier shares must be fully withdrawn");

        // Supplier balance: within 1 wei of 1000 USDC.
        // Rounding: supply uses toSharesDown, withdraw uses toAssetsDown → supplier loses at most 1 wei.
        uint256 supplierUSDC = IERC20(Constants.USDC).balanceOf(supplier);
        assertApproxEqAbs(supplierUSDC, 1000e6, 1, "supplier must get back ~all USDC");
        assertLe(supplierUSDC, 1000e6, "Morpho rounding must favor protocol, not supplier");
        vm.stopPrank();
    }
}
