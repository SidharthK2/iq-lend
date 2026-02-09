// SPDX-License-Identifier: ISC
pragma solidity >=0.8.20;

import {IFraxswapPair} from "./IFraxswapPair.sol";

interface IFraxswapOracle {
    function getPrice(IFraxswapPair pool, uint256 period, uint256 rounds, uint256 maxDiffPerc)
        external
        view
        returns (uint256 result0, uint256 result1);
}
