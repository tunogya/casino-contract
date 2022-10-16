//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISnatch {
    struct PoolConfig {
        address paymentToken;           // payment token address
        uint256 singleDrawPrice;        // single draw price
        uint256 batchDrawPrice;         // batch draw price
        address rarePrizeToken;         // rare prize token address
        uint256 rarePrizeInitRate;      // rare prize init rate, 100% = 1e18
        uint256 rarePrizeAvgRate;       // rare prize avg rate, 100% = 1e18
        uint256 rarePrizeValue;         // rare prize value
        uint256 rarePrizeMaxRP;         // rare prize max rp
        address[] normalPrizesToken;    // normal prize token addresses
        uint256[] normalPrizesValue;    // normal prize values
        uint256[] normalPrizesRate;     // normal prize rates
    }

    struct DrawRequest {
        bool isWaitingFulfill;          // is waiting fulfill
        uint256 poolId;                 // pool id
    }

    function createPool(PoolConfig memory config) external returns (uint256 poolId);

    // @dev When paymentToken updated, the totalFeeValue will be reset to 0 and auto withdraw all fee to the owner of the pool
    // If update the pool share, will deposit the new share to the pool, new share >= old share
    function setPoolConfig(uint256 _poolId, PoolConfig memory config) external;

    function draw(uint256 _poolId) external;

    function batchDraw(uint256 _poolId) external;
}