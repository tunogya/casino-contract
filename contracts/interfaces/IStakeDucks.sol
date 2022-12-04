//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IStakeDucks {
    event SoloStake(uint256 indexed poolId, POOL_SNAPSHOT snapshot);
    event PooledStake(uint256 indexed poolId, POOL_SNAPSHOT snapshot);
    event EndPooledStake(uint256 indexed poolId, POOL_SNAPSHOT snapshot);

    // @notice Get every stake info of a pool
    struct STAKE_DETAIL {
        address account;            // player account
        uint256 amount;             // stake amount
        uint256 divine;             // how much ducks in the half of the pool
    }

    // @notice Polar coordinate system
    struct COORDINATE {
        uint128 angle;              // angular coordinates
        uint128 radius;             // radius coordinates
    }

    // @notice bytes32 => poolId, poolId => poolSnapshot, poolSnapshot contain stakeDetails
    struct POOL_SNAPSHOT {
        bool isWaitingFulfill;       // is waiting fulfill, default is false, when true, can't stake
        bool isGameOver;             // is game over, default false, when game over, can't stake
        address token;               // payment token, default is AddressZero, ETH
        uint256 size;                // how much ducks in this pool, can't be changed, need >= 4
        uint256 result;              // the result of the pool, default is 0, when game over, can't be changed
        STAKE_DETAIL[] stakeDetails; // stake details, can be append when account and divine is the same
        COORDINATE[] coordinates;    // coordinates, coordinates.length == size
    }

    // @notice solo stake will auto draw
    function soloStake(address _token, uint256 _size, STAKE_DETAIL calldata _stakeDetail) payable external returns (bool);

    // @notice create a new pooled stake
    function startPooledStake(address _token, uint256 _size) external returns (uint256 poolId);

    // @notice pooled stake will not auto draw
    function pooledStake(uint256 _poolId, STAKE_DETAIL calldata _stakeDetail) payable external returns (bool);

    // @notice end the pool, and start draw
    // only players of this pool can end the pool
    function endPooledStake(uint256 _poolId) external returns (bool);

    // @notice get pool snapshot
    function poolSnapshotOf(uint256 _poolId) external view returns (POOL_SNAPSHOT memory);

    // @notice query next pool id
    function nextPoolId() external view returns (uint256 poolId);
}