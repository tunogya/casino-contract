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

    struct Prize {
        address token;              // ERC20 token address
        uint256 value;              // value per draw
        uint256 probability;        // 100% = 1e18, 1% = 1e16
        uint256 share;              // Every time you draw a new prize, the value will be reduced by 1
    }

    struct PooConfig {
        address paymentToken;       // payment token address
        uint256 singleDrawPrice;    // single draw price
        uint256 batchDrawSize;      // batch draw size
        uint256 batchDrawPrice;     // batch draw price
        Prize[] prizeArray;         // prize array
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
    function setPoolConfig(uint256 _poolId, PooConfig memory config) external;

    function getPoolConfig(uint256 _poolId) external view returns (PooConfig memory);

    // Withdraw Pool fee
    function withdrawPoolFee(uint256 _poolId) external;

    function batchWithdrawPoolFee(uint256[] _poolIds) external;

    // -------------------------------------------------------------------
    // Player functions
    // -------------------------------------------------------------------

    function draw(uint256 _poolId) external;

    function batchDraw(uint256 _poolId) external;
}