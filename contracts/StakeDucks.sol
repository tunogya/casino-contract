//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IStakeDucks.sol";
import "./lib/RrpRequesterV0Upgradeable.sol";

contract FourDucks is Initializable, RrpRequesterV0Upgradeable, OwnableUpgradeable, UUPSUpgradeable, IStakeDucks {
    using Counters for Counters.Counter;

    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

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
    function soloStake(STAKE_DETAIL _stakeDetail) payable external {
        uint256 poolId = poolIdCounter.current();
        poolIdCounter.increment();

        if (_token == address(0)) {
            require(msg.value >= _abs(_amount) + sponsorFee, "FourDucks: eth amount is not enough");
        } else {
            require(ERC20(_token).transferFrom(msg.sender, address(this), _abs(_amount)), "FourDucks: transferFrom failed");
        }
    }

    // @notice create a new pooled stake
    function startPooledStake() external returns (uint256 poolId);

    // @notice pooled stake will not auto draw
    function pooledStake(uint256 _poolId, STAKE_DETAIL _stakeDetail) payable external;

    // @notice end the pool, and start draw
    // only players of this pool can end the pool
    function endPooledStake(uint256 _poolId) external;

    // @notice get pool snapshot
    function poolSnapshotOf(uint256 _poolId) external view returns (POOL_SNAPSHOT memory);

    // @notice query next pool id
    function nextPoolId() external returns (uint256 poolId) {
        return poolIdCounter.current();
    }
}
