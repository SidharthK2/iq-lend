// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { Constants } from "../src/Constants.sol";
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
        vm.createSelectFork(vm.envString("ETHEREUM_MAINNET_URL"));

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
            lend.enableIrm(Constants.IRM);
            lend.enableLltv(Constants.LLTV);
            lend.createMarket(market1Params);
            lend.setCaps(market1Id, Constants.SUPPLY_CAP, Constants.BORROW_CAP);
            vm.stopPrank();
        }

        // Fund accounts
        deal(Constants.USDC, supplier, 1000e6);
        deal(Constants.IQ, borrower, 1_000_000e18);
    }

    function testSupplyCapEnforced() public {
        vm.startPrank(supplier);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);

        // Supply up to cap — should succeed
        lend.supply(market1Params, Constants.SUPPLY_CAP, 0, supplier, "");

        // Next supply should revert
        vm.expectRevert("supply cap reached");
        lend.supply(market1Params, 1e6, 0, supplier, "");
        vm.stopPrank();
    }

    function testBorrowCapEnforced() public {
        // Supply first
        vm.startPrank(supplier);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        lend.supply(market1Params, Constants.SUPPLY_CAP, 0, supplier, "");
        vm.stopPrank();

        // Deposit collateral and borrow up to cap
        vm.startPrank(borrower);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        lend.supplyCollateral(market1Params, 1_000_000e18, borrower, "");

        // Borrow full cap
        lend.borrow(market1Params, Constants.BORROW_CAP, 0, borrower, borrower);

        // Next borrow should revert
        vm.expectRevert("borrow cap reached");
        lend.borrow(market1Params, 1e6, 0, borrower, borrower);
        vm.stopPrank();
    }

    function testFullFlow() public {
        // 1. Supply USDC
        vm.startPrank(supplier);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        lend.supply(market1Params, 500e6, 0, supplier, "");
        vm.stopPrank();

        // 2. Deposit IQ collateral + borrow USDC
        vm.startPrank(borrower);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);

        lend.supplyCollateral(market1Params, 500_000e18, borrower, "");

        uint256 borrowAmount = 100e6; // borrow 100 USDC
        lend.borrow(market1Params, borrowAmount, 0, borrower, borrower);

        uint256 borrowerUSDC = IERC20(Constants.USDC).balanceOf(borrower);
        assertEq(borrowerUSDC, borrowAmount, "borrower should have received USDC");

        // 3. Repay
        lend.repay(market1Params, borrowAmount, 0, borrower, "");

        // 4. Withdraw collateral
        lend.withdrawCollateral(market1Params, 500_000e18, borrower, borrower);
        vm.stopPrank();

        // 5. Supplier withdraws
        vm.startPrank(supplier);
        lend.withdraw(market1Params, 500e6, 0, supplier, supplier);

        uint256 supplierUSDC = IERC20(Constants.USDC).balanceOf(supplier);
        assertEq(supplierUSDC, 1000e6, "supplier should have all USDC back");
        vm.stopPrank();
    }
}
