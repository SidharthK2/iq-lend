// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMorpho, MarketParams, Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {FraxswapOracle} from "@frax-bamm/contracts/FraxswapOracle.sol";

/// @title IQLend
contract IQLend {
    IMorpho public immutable MORPHO;

    constructor(address morpho) {
        MORPHO = IMorpho(morpho);
    }
}
