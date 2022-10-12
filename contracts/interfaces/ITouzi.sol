//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ITouzi {
    // -------------------------------------------------------------------
    // Platform functions
    // -------------------------------------------------------------------

    function setPlatformFeeRate(uint256 feeRate) external;
    // withdraw all platform fee by token
    function withdrawPlatformFee(address token) external;

    // -------------------------------------------------------------------
    // Merchant functions
    // -------------------------------------------------------------------

    struct PoolConfig {
        address paymentToken;       // payment token address
        uint256 singleDrawPrice;    // single draw price
        uint256 batchDrawSize;      // batch draw size
        uint256 batchDrawPrice;     // batch draw price
        address[] prizeTokens;      // prize token address list
        uint256[] prizeData;        // prize data list, [value, probability, share]
    }

    struct PoolBillboard {
        uint256 totalDrawCount;     // total draw count
        uint256 totalWinCount;      // total win count
        uint256 totalFeeValue;      // total fee amount. Every withdrawal will be deducted from the total amount, if changed the payment token, set to 0
    }

    struct DrawRequest {
        bool isWaitingFulfill;     // is waiting fulfill
        uint256 poolId;             // pool id
    }

    // Create a new Pool
    function createPool() external returns (uint256 poolId);

    // @dev When paymentToken updated, the totalFeeValue will be reset to 0 and auto withdraw all fee to the owner of the pool
    // If update the pool share, will deposit the new share to the pool, new share >= old share
    function setPoolConfig(uint256 _poolId, PoolConfig memory config) external;

    // Withdraw Pool fee
    function withdrawPoolFee(uint256 _poolId) external;

    function batchWithdrawPoolFee(uint256[] memory _poolIds) external;

    // -------------------------------------------------------------------
    // Player functions
    // -------------------------------------------------------------------

    function draw(uint256 _poolId) external;

    function batchDraw(uint256 _poolId) external;
}