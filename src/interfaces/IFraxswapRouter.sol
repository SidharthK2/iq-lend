// SPDX-License-Identifier: ISC
pragma solidity >=0.8.20;

interface IFraxswapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    )
        external
        returns (uint256[] memory amounts);
}
