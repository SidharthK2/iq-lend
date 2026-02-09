// SPDX-License-Identifier: ISC
pragma solidity >=0.8.20;

interface IFraxswapPair {
    struct TWAPObservation {
        uint256 timestamp;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
    }

    function TWAPObservationHistory(uint256 index) external view returns (TWAPObservation memory);
    function getTWAPHistoryLength() external view returns (uint256);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
