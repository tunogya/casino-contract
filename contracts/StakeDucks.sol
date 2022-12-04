//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IStakeDucks.sol";
import "./interfaces/ICash.sol";
import "./lib/RrpRequesterV0Upgradeable.sol";

contract StakeDucks is Initializable, RrpRequesterV0Upgradeable, OwnableUpgradeable, UUPSUpgradeable, IStakeDucks {
    using Counters for Counters.Counter;

    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;
    ICash public cash = ICash(0x0000000000000000000000000000000000000000);
    uint256[] private P = [
        1,
        0,2,
        0,1,3,
        0,0,4,4,
        0,0,1,10,5,
        0,0,0,8,18,6,
        0,0,0,1,28,28,7,
        0,0,0,0,16,64,40,8,
        0,0,0,0,1,75,117,54,9,
        0,0,0,0,0,32,210,190,70,10
    ];

    // bytes32 => poolId
    mapping(bytes32 => uint256) private requestId2PoolIdMap;
    // poolId => poolSnapshot, poolSnapshot contain stakeDetails
    mapping(uint256 => POOL_SNAPSHOT) private poolId2PoolSnapshotMap;

    Counters.Counter private poolIdCounter;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _airnodeRrp) initializer public {
        __RrpRequesterV0_init(_airnodeRrp);
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256 Endpoint ID used to request a `uint256`
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) onlyOwner external {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    // @notice solo stake will auto draw
    function soloStake(address _token, uint256 _size, STAKE_DETAIL calldata _stakeDetail) payable external returns (bool) {
        uint256 poolId = poolIdCounter.current();
        poolIdCounter.increment();

        require(ICash.burn(_token, msg.sender, _stakeDetail.amount), "ICash: burn failed");

        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            abi.encode(bytes32("1u"), bytes32("size"), _size)
        );

        requestId2PoolIdMap[requestId] = poolId;

        POOL_SNAPSHOT storage poolSnapshot = poolId2PoolSnapshotMap[poolId];
        poolSnapshot.isWaitingFulfill = true;
        poolSnapshot.isGameOver = true;
        poolSnapshot.token = _token;
        poolSnapshot.size = _size;
        poolSnapshot.stakeDetails.push(_stakeDetail);

        return true;
    }

    // @notice create a new pooled stake
    function startPooledStake(address _token, uint256 _size) external returns (uint256 poolId) {
        poolId = poolIdCounter.current();
        poolIdCounter.increment();
    }

    // @notice pooled stake will not auto draw
    function pooledStake(uint256 _poolId, STAKE_DETAIL calldata _stakeDetail) payable external returns (bool) {
        POOL_SNAPSHOT storage poolSnapshot = poolId2PoolSnapshotMap[_poolId];
        require(!poolSnapshot.isGameOver, "StakeDucks: game over"); // game over
        require(ICash.burn(_token, msg.sender, _stakeDetail.amount), "ICash: burn failed");

        poolSnapshot.stakeDetails.push(_stakeDetail);

        return true;
    }

    // @notice end the pool, and start draw
    // only players of this pool can end the pool
    function endPooledStake(uint256 _poolId) external returns (bool) {
        POOL_SNAPSHOT storage poolSnapshot = poolId2PoolSnapshotMap[_poolId];
        require(!poolSnapshot.isGameOver, "StakeDucks: game over"); // game over
        require(poolSnapshot.stakeDetails.length > 0, "StakeDucks: not enough players"); // not enough players

        poolSnapshot.isWaitingFulfill = true;
        poolSnapshot.isGameOver = true;

        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            abi.encode(bytes32("1u"), bytes32("size"), poolSnapshot.size)
        );
        requestId2PoolIdMap[requestId] = _poolId;

        return true;
    }

    // @notice get pool snapshot
    function poolSnapshotOf(uint256 _poolId) external view returns (POOL_SNAPSHOT memory) {
        return poolId2PoolSnapshotMap[_poolId];
    }

    // @notice query next pool id
    function nextPoolId() external view returns (uint256 poolId) {
        poolId = poolIdCounter.current();
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    function pOf(uint256 _size) public view returns (uint256[] memory) {
        uint256[] memory p = new uint256[](_size);
        uint256 startIndex = _size * (_size - 1) / 2;
        for (uint256 i = 0; i < _size; i++) {
            p[i] = P[startIndex + i];
        }
        return p;
    }
}
