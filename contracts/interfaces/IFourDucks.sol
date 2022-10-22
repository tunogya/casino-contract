//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IFourDucks {
    struct PoolConfig {
        address[4] players;          // players
        address[4] tokens;           // payment token address
        uint256[4] amount;           // stake amount
        bool[4] unified;             // unified
    }

    struct StakeRequest {
        address poolId;              // pool Id
        bool isWaitingFulfill;       // is waiting fulfill
    }

    // 10% = 1e17
    function setFee(uint256 _value) external;

    function stake(address _poolId, address _token, uint256 _amount, bool _unified) external;

    function withdraw(address _token, uint256 _amount) external;

    function withdrawETH(uint256 _amount) external;

    function poolConfigOf(address _poolId) external view returns (PoolConfig memory);
}