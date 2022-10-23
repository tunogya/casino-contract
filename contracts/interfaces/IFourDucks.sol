//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IFourDucks {
    struct PoolConfig {
        address[] players;          // players
        address[] tokens;           // payment token address
        int256[] amount;           // stake amount
    }

    struct StakeRequest {
        address poolId;              // pool Id
        bool isWaitingFulfill;       // is waiting fulfill
    }

    // 10% = 1e17
    function setFee(uint256 _value) external;

    function stake(address _poolId, address _token, int256 _amount) payable external;

    function withdrawERC20(address _token, uint256 _amount) external;

    function withdrawNativeCurrency(uint256 _amount) external;

    function poolConfigOf(address _poolId) external view returns (PoolConfig memory);
}