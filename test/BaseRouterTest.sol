// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { IQLend } from "../src/IQLend.sol";
import { IQRouter } from "../src/IQRouter.sol";
import { Constants } from "../src/Constants.sol";
import { IOracle } from "../src/interfaces/IOracle.sol";
import { MarketParams, Id } from "@morpho-blue/interfaces/IMorpho.sol";
import { MarketParamsLib } from "@morpho-blue/libraries/MarketParamsLib.sol";
import { SharesMathLib } from "@morpho-blue/libraries/SharesMathLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console2 as console } from "forge-std/Test.sol";

abstract contract BaseRouterTest is Test {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;

    IQLend lend;
    IQRouter router;

    MarketParams market1Params;
    Id market1Id;
    MarketParams market2Params;
    Id market2Id;

    address user = makeAddr("user");
    address liquidator = makeAddr("liquidator");
    address lp = makeAddr("lp");

    function setUp() public virtual {
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

        market2Params = MarketParams({
            loanToken: Constants.IQ,
            collateralToken: Constants.USDC,
            oracle: Constants.IQ_ORACLE_MARKET2,
            irm: Constants.IRM,
            lltv: Constants.LLTV
        });
        market2Id = market2Params.id();

        _createMarketIfNeeded(market1Params, market1Id);
        _createMarketIfNeeded(market2Params, market2Id);

        vm.startPrank(lend.owner());
        lend.setCaps(market1Id, type(uint256).max, type(uint256).max);
        lend.setCaps(market2Id, type(uint256).max, type(uint256).max);
        vm.stopPrank();

        deal(Constants.USDC, lp, 10_000_000e6);
        deal(Constants.IQ, lp, 100_000_000e18);
        vm.startPrank(lp);
        IERC20(Constants.USDC).approve(address(lend), type(uint256).max);
        IERC20(Constants.IQ).approve(address(lend), type(uint256).max);
        lend.supply(market1Params, 10_000_000e6, 0, lp, "");
        lend.supply(market2Params, 100_000_000e18, 0, lp, "");
        vm.stopPrank();

        deal(Constants.USDC, user, 100_000e6);

        vm.prank(user);
        lend.setAuthorization(address(router), true);
    }

    function _createMarketIfNeeded(MarketParams memory params, Id id) internal {
        (,,,, uint128 lastUpdate,) = lend.market(id);
        if (lastUpdate == 0) {
            vm.startPrank(lend.owner());
            try lend.enableIrm(params.irm) {} catch {}
            try lend.enableLltv(params.lltv) {} catch {}
            lend.createMarket(params);
            vm.stopPrank();
        }
    }
}
