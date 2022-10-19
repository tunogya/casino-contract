//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ISnatch.sol";

contract Snatch is RrpRequesterV0, ISnatch, Ownable {
    using Counters for Counters.Counter;

    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);
    event Draw(uint256 indexed poolId, bytes32 requestId);
    event BatchDraw(uint256 indexed poolId, uint256 size, bytes32 requestId);
    event GetRarePrize(uint256 indexed poolId, address indexed user);
    event GetNormalPrize(uint256 indexed poolId, address indexed user, address token, uint256 value);
    event Withdraw(address indexed token, uint256 value);

    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    // poolId => poolConfig
    mapping(uint256 => PoolConfig) private poolConfigMap;
    // address => poolId => rp
    mapping(address => mapping(uint256 => uint256)) private rpMap;
    // requestId => DrawRequest
    mapping(bytes32 => DrawRequest) private drawRequestMap;

    Counters.Counter private poolIdCounter;

    /// @dev RrpRequester sponsors itself, meaning that it can make requests
    /// that will be fulfilled by its sponsor wallet. See the Airnode protocol
    /// docs about sponsorship for more information.
    /// @param _airnodeRrp Airnode RRP contract address, view https://docs.api3.org/qrng/reference/chains.html
    constructor(address _airnodeRrp) RrpRequesterV0(_airnodeRrp) {}

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

    /// @notice Creates a new pool
    function createPool(PoolConfig memory config) onlyOwner external returns (uint256 poolId) {
        poolId = poolIdCounter.current();
        poolConfigMap[poolId] = config;
        poolIdCounter.increment();
    }

    // @notice Update exist pool's config
    function setPoolConfig(uint256 _poolId, PoolConfig memory config) onlyOwner external {
        require(_poolId < poolIdCounter.current(), "Pool does not exist");
        require(config.rarePrizeInitRate <= config.rarePrizeAvgRate, "Rare prize init rate must be less than avg rate");
        poolConfigMap[_poolId] = config;
    }

    function nextPoolId() external view returns (uint256 poolId) {
        poolId = poolIdCounter.current();
    }

    function draw(uint256 _poolId) external {
        require(_poolId < poolIdCounter.current(), "Pool does not exist");
        PoolConfig memory config = poolConfigMap[_poolId];
        ERC20(config.paymentToken).transferFrom(msg.sender, address(this), config.singleDrawPrice);
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        drawRequestMap[requestId] = DrawRequest(msg.sender, _poolId, true);
        emit Draw(_poolId, requestId);
    }

    function batchDraw(uint256 _poolId) external {
        require(_poolId < poolIdCounter.current(), "Pool does not exist");
        PoolConfig memory config = poolConfigMap[_poolId];
        ERC20(config.paymentToken).transferFrom(msg.sender, address(this), config.batchDrawPrice);
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            abi.encode(bytes32("1u"), bytes32("size"), config.batchDrawSize)
        );
        drawRequestMap[requestId] = DrawRequest(msg.sender, _poolId, true);
        emit BatchDraw(_poolId, config.batchDrawSize, requestId);
    }

    function _calculateRarePrizeProbability(uint256 _poolId, uint256 _number) internal view returns (uint256) {
        PoolConfig memory config = poolConfigMap[_poolId];
        uint256 initRare = config.rarePrizeInitRate;
        uint256 avgRare = config.rarePrizeAvgRate;
        uint256 maxRP = config.rarePrizeMaxRP;
        if (_number >= maxRP) {
            return 1e18;
        }
        uint256 d = (2 * avgRare - 2 * initRare) / (maxRP - 1);

        return initRare + d * _number;
    }

    function calculateRarePrizeProbability(uint256 _poolId, uint256 _rp) external view returns (uint256) {
        return _calculateRarePrizeProbability(_poolId, _rp);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @dev Note the `onlyAirnodeRrp` modifier. You should only accept RRP
    /// fulfillments from this protocol contract. Also note that only
    /// fulfillments for the requests made by this contract are accepted, and
    /// a request cannot be responded to multiple times.
    /// @param requestId Request IDw
    /// @param data ABI-encoded response
    function fulfillUint256(bytes32 requestId, bytes calldata data)
    external
    onlyAirnodeRrp
    {
        require(
            drawRequestMap[requestId].isWaitingFulfill,
            "Request ID not known"
        );
        drawRequestMap[requestId].isWaitingFulfill = false;
        address requester = drawRequestMap[requestId].requester;
        uint256 qrngUint256 = abi.decode(data, (uint256)) & 0x3ffff;
        uint256 poolId = drawRequestMap[requestId].poolId;
        uint256 rp = rpMap[requester][poolId];
        uint256 p = _calculateRarePrizeProbability(poolId, rp);
        if (qrngUint256 <= p) {
            rpMap[requester][poolId] = 0;
            PoolConfig memory config = poolConfigMap[poolId];
            ERC20(config.rarePrizeToken).transfer(requester, config.rarePrizeValue);
            emit GetRarePrize(poolId, requester);
        } else {
            PoolConfig memory config = poolConfigMap[poolId];
            rpMap[requester][poolId] += 1;
            uint256 start = 0;
            for (uint256 i = 0; i < config.normalPrizesRate.length; i++) {
                start += config.normalPrizesRate[i];
                if (qrngUint256 <= start) {
                    uint256 balance = ERC20(config.normalPrizesToken[i]).balanceOf(address(this));
                    if (balance >= config.normalPrizesValue[i]) {
                        ERC20(config.normalPrizesToken[i]).transfer(requester, config.normalPrizesValue[i]);
                        emit GetNormalPrize(poolId, requester, config.normalPrizesToken[i], config.normalPrizesValue[i]);
                        break;
                    }
                }
            }
        }

        emit ReceivedUint256(requestId, qrngUint256);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256Array(bytes32 requestId, bytes calldata data)
    external
    onlyAirnodeRrp
    {
        require(
            drawRequestMap[requestId].isWaitingFulfill,
            "Request ID not known"
        );
        drawRequestMap[requestId].isWaitingFulfill = false;
        address requester = drawRequestMap[requestId].requester;
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));
        uint256 poolId = drawRequestMap[requestId].poolId;
        for (uint256 i = 0; i <= qrngUint256Array.length; i++) {
            uint256 rp = rpMap[requester][poolId];
            uint256 p = _calculateRarePrizeProbability(poolId, rp);
            uint256 qrngUint256 = qrngUint256Array[i] & 0x3ffff;
            if (qrngUint256 <= p) {
                rpMap[requester][poolId] = 0;
                PoolConfig memory config = poolConfigMap[poolId];
                ERC20(config.rarePrizeToken).transfer(requester, config.rarePrizeValue);
                emit GetRarePrize(poolId, requester);
            } else {
                PoolConfig memory config = poolConfigMap[poolId];
                rpMap[requester][poolId] += 1;
                uint256 start = 0;
                for (uint256 j = 0; j < config.normalPrizesRate.length; j++) {
                    start += config.normalPrizesRate[j];
                    if (qrngUint256 <= start) {
                        uint256 balance = ERC20(config.normalPrizesToken[j]).balanceOf(address(this));
                        if (balance >= config.normalPrizesValue[j]) {
                            ERC20(config.normalPrizesToken[j]).transfer(requester, config.normalPrizesValue[j]);
                            emit GetNormalPrize(poolId, requester, config.normalPrizesToken[j], config.normalPrizesValue[j]);
                            break;
                        }
                    }
                }
            }
        }

        emit ReceivedUint256Array(requestId, qrngUint256Array);
    }

    function withdraw(address token, uint256 amount) onlyOwner external {
        require(amount <= ERC20(token).balanceOf(address(this)), "Not enough balance");
        ERC20(token).transfer(msg.sender, amount);
        emit Withdraw(token, amount);
    }

    function rpOf(address _user, uint256 _poolId) external view returns (uint256) {
        require(_poolId < poolIdCounter.current(), "Pool does not exist");
        return rpMap[_user][_poolId];
    }

    function poolConfigOf(uint256 _poolId) external view returns (PoolConfig memory) {
        require(_poolId < poolIdCounter.current(), "Pool does not exist");
        return poolConfigMap[_poolId];
    }

    function drawRequestOf(bytes32 _requestId) external view returns (DrawRequest memory) {
        return drawRequestMap[_requestId];
    }
}