//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ITouzi.sol";

contract Touzi is RrpRequesterV0, ITouzi, Ownable {
    using Counters for Counters.Counter;

    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);
    event SetFeeRate(uint256 feeRate);
    event WithdrawPlatformFee(address indexed token, uint256 amount);
    event WithdrawPoolFee(uint256 indexed poolId, address token, uint256 amount);
    event Draw(uint256 indexed poolId, bytes32 requestId);
    event BatchDraw(uint256 indexed poolId, uint256 size, bytes32 requestId);

    // Platform fee rate
    uint256 public feeRate;

    // These variables can also be declared as `constant`/`immutable`.
    // However, this would mean that they would not be updatable.
    // Since it is impossible to ensure that a particular Airnode will be
    // indefinitely available, you are recommended to always implement a way
    // to update these parameters.
    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    // poolId => pool owner address
    mapping(uint256 => address) public poolOwnerMap;
    // poolId => poolConfig
    mapping(uint256 => PoolConfig) public poolConfigMap;
    // poolId => PoolBillboard
    mapping(uint256 => PoolBillboard) public poolBillboardMap;
    // token => amount, platform fee
    mapping(address => uint256) public platformFeeMap;
    // requestId => DrawRequest
    mapping(bytes32 => DrawRequest) public drawRequestMap;

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

    // -------------------------------------------------------------------
    // Platform functions
    // -------------------------------------------------------------------

    // set platform fee rate, only owner can call
    function setPlatformFeeRate(uint256 _feeRate) onlyOwner external {
        require(_feeRate <= 1e18, "Touzi: feeRate must <= 1e18");
        feeRate = _feeRate;

        emit SetFeeRate(_feeRate);
    }

    // withdraw all platform fee by token
    function withdrawPlatformFee(address token) onlyOwner external {
        require(token != address(0), "Touzi: token is zero address");
        uint256 amount = platformFeeMap[token];
        platformFeeMap[token] = 0;
        ERC20(token).transfer(msg.sender, amount);

        emit WithdrawPlatformFee(token, amount);
    }

    // -------------------------------------------------------------------
    // Merchant functions
    // -------------------------------------------------------------------

    // Create a new Pool
    function createPool() external returns (uint256 poolId) {
        poolId = poolIdCounter.current();
        poolIdCounter.increment();
        poolOwnerMap[poolId] = msg.sender;
    }

    // @dev When paymentToken updated, the totalFeeValue will be reset to 0 and auto withdraw all fee to the owner of the pool
    // If update the pool share, will deposit the new share to the pool, new share >= old share
    function setPoolConfig(uint256 _poolId, PoolConfig memory config) onlyPoolOwner(_poolId) external {
        poolConfigMap[_poolId] = config;
    }

    // Withdraw Pool fee
    function withdrawPoolFee(uint256 _poolId) external {
        _withdrawPoolFee(_poolId);
    }

    // Batch withdraw Pool fee
    function batchWithdrawPoolFee(uint256[] memory _poolIds) external {
        for (uint256 i = 0; i < _poolIds.length; i++) {
            _withdrawPoolFee(_poolIds[i]);
        }
    }

    function _withdrawPoolFee(uint256 _poolId) onlyPoolOwner(_poolId) internal {
        address paymentToken = poolConfigMap[_poolId].paymentToken;
        uint256 totalFeeValue = poolBillboardMap[_poolId].totalFeeValue;
        ERC20(paymentToken).transfer(poolOwnerMap[_poolId], totalFeeValue);

        emit WithdrawPoolFee(_poolId, paymentToken, totalFeeValue);
    }

    /**
     * @dev Throws if called by any account other than the owner of pool. Checked by poolId.
     * @param _poolId The poolId of the pool
     */
    modifier onlyPoolOwner(uint256 _poolId) {
        require(_poolId < poolIdCounter.current(), "Touzi: poolId not exist");
        require(poolOwnerMap[_poolId] == _msgSender(), "Touzi: caller is not the owner of pool");
        _;
    }

    // -------------------------------------------------------------------
    // Player functions
    // -------------------------------------------------------------------

    function draw(uint256 _poolId) external {
        PoolConfig memory config = poolConfigMap[_poolId];

        ERC20(config.paymentToken).transferFrom(msg.sender, address(this), config.singleDrawPrice);

        uint256 platformFee = config.singleDrawPrice * feeRate / 1e18;
        poolBillboardMap[_poolId].totalFeeValue += (config.singleDrawPrice - platformFee);
        poolBillboardMap[_poolId].totalDrawCount += 1;
        platformFeeMap[config.paymentToken] += platformFee;

        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        drawRequestMap[requestId] = DrawRequest(true, _poolId);

        emit Draw(_poolId, requestId);
    }

    function batchDraw(uint256 _poolId) external {
        PoolConfig memory config = poolConfigMap[_poolId];

        ERC20(config.paymentToken).transferFrom(msg.sender, address(this), config.batchDrawPrice);

        uint256 platformFee = config.batchDrawPrice * feeRate / 1e18;
        poolBillboardMap[_poolId].totalFeeValue += (config.batchDrawPrice - platformFee);
        poolBillboardMap[_poolId].totalDrawCount += config.batchDrawSize;
        platformFeeMap[config.paymentToken] += platformFee;

        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
        // Using Airnode ABI to encode the parameters
            abi.encode(bytes32("1u"), bytes32("size"), config.batchDrawSize)
        );
        drawRequestMap[requestId] = DrawRequest(true, _poolId);
        emit RequestedUint256Array(requestId, config.batchDrawSize);
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @dev Note the `onlyAirnodeRrp` modifier. You should only accept RRP
    /// fulfillments from this protocol contract. Also note that only
    /// fulfillments for the requests made by this contract are accepted, and
    /// a request cannot be responded to multiple times.
    /// @param requestId Request ID
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
        uint256 qrngUint256 = abi.decode(data, (uint256));
        // Do what you want with `qrngUint256` here...
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
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));
        // Do what you want with `qrngUint256Array` here...
        emit ReceivedUint256Array(requestId, qrngUint256Array);
    }
}