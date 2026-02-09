//SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

import { Test, console2 as console } from "forge-std/Test.sol";
import { IQOracle } from "../src/IQOracle.sol";
import { FraxswapOracle } from "public-frax-bamm/src/contracts/FraxswapOracle.sol";
import { IFraxswapOracle } from "../src/interfaces/IFraxswapOracle.sol";
import { IFraxswapPair } from "../src/interfaces/IFraxswapPair.sol";
import { Constants } from "../src/Constants.sol";

contract IQOracleTest is Test {
    IQOracle oracleMarket1;
    IQOracle oracleMarket2;
    IFraxswapOracle fraxswapOracle;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_MAINNET_URL"));

        fraxswapOracle = IFraxswapOracle(address(new FraxswapOracle()));

        // Market 1: IQ collateral, USDC loan
        oracleMarket1 = new IQOracle(
            address(this),
            fraxswapOracle,
            IFraxswapPair(Constants.FRAXSWAP_IQ_FRAX_PAIR),
            Constants.IQ,
            Constants.USDC,
            true,
            Constants.TWAP_PERIOD,
            Constants.TWAP_ROUNDS,
            Constants.MAX_DIFF_PERC
        );

        // Market 2: USDC collateral, IQ loan
        oracleMarket2 = new IQOracle(
            address(this),
            fraxswapOracle,
            IFraxswapPair(Constants.FRAXSWAP_IQ_FRAX_PAIR),
            Constants.USDC,
            Constants.IQ,
            false,
            Constants.TWAP_PERIOD,
            Constants.TWAP_ROUNDS,
            Constants.MAX_DIFF_PERC
        );
    }

    function testMarket1Price() public {
        uint256 p = oracleMarket1.price();
        console.log("Market 1 price (IQ in USDC, 1e24 scale):", p);
        // IQ ~ $0.00125, at 1e24 scale = ~1.25e21
        assertGt(p, 0.5e21);
        assertLt(p, 5e21);
    }

    function testMarket2Price() public {
        uint256 p = oracleMarket2.price();
        console.log("Market 2 price (USDC in IQ, 1e48 scale):", p);
        // 1 USDC ~ 800 IQ, at 1e48 scale = ~800e48
        assertGt(p, 100e48);
        assertLt(p, 5000e48);
    }

    function testPricesAreInverse() public {
        uint256 p1 = oracleMarket1.price();
        uint256 p2 = oracleMarket2.price();
        // p1 * p2 should approximate 1e(24+48) = 1e72
        uint256 product = p1 * p2;
        console.log("Product:", product);
        // Allow 1% tolerance
        assertGt(product, 0.99e72);
        assertLt(product, 1.01e72);
    }
}
