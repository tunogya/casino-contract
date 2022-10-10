//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ITouzi {
    // -------------------------------------------------------------------
    // Platform functions
    // -------------------------------------------------------------------

    // get platform config
    function getPlatformFeeRate() external view returns (uint256);

    // set platform config
    function setPlatformFeeRate(uint256 feeRate) external;

    // withdraw all platform fee by token
    function withdrawPlatformFee(address token) external;

    // -------------------------------------------------------------------
    // Merchant functions
    // -------------------------------------------------------------------

    struct Prize {
        address token;              // ERC20 token address
        uint256 value;              // value per share
        uint256 share;              // total share
        uint256 probability;        // 100% = 1e18, 1% = 1e16
    }

    struct PooConfig {
        address paymentToken;       // payment token address
        uint256 singleDrawPrice;    // single draw price
        uint256 batchDrawQuota;     // batch draw quota
        uint256 batchDrawPrice;     // batch draw price
        Prize[] prizeArray;         // prize array
    }

    // Create a new Pool, only the room owner can create a pool
    function createPool() external;

    // Delete a Pool, only the room owner can delete it
    function deletePool(uint256 _poolId) external;

    function batchDeletePool(uint256[] _poolIds) external;

    function setPoolConfig(uint256 _poolId, PooConfig memory config) external;

    // Get Pool config
    // @return pool config
    function getPoolConfig(uint256 _poolId) external view returns (PooConfig memory);

    // Withdraw Pool fee
    function withdrawPoolFee(uint256 _poolId) external;

    function batchWithdrawPoolFee(uint256[] _poolIds) external;

    // -------------------------------------------------------------------
    // Player functions
    // -------------------------------------------------------------------

    // Roll, will makeRequestUint256()
    function draw(uint256 _roomId, uint256 _poolId) external;

    // Batch roll, will makeRequestUint256Array()
    function batchDraw(uint256 _roomId, uint256 _poolId) external;
}