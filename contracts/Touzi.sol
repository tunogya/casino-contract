//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/ITouzi.sol";

contract Touzi is RrpRequesterV0, Ownable, ITouzi {
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event RequestedUint256Array(bytes32 indexed requestId, uint256 size);
    event ReceivedUint256Array(bytes32 indexed requestId, uint256[] response);

    // Platform fee rate
    uint256 private feeRate;

    // These variables can also be declared as `constant`/`immutable`.
    // However, this would mean that they would not be updatable.
    // Since it is impossible to ensure that a particular Airnode will be
    // indefinitely available, you are recommended to always implement a way
    // to update these parameters.
    address public airnode;
    bytes32 public endpointIdUint256;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    mapping (uint256 => address) public poolOwner;

    using Counters for Counters.Counter;
    Counters.Counter private _poolIdCounter;

    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;

    /// @dev RrpRequester sponsors itself, meaning that it can make requests
    /// that will be fulfilled by its sponsor wallet. See the Airnode protocol
    /// docs about sponsorship for more information.
    /// @param _airnodeRrp Airnode RRP contract address, view https://docs.api3.org/qrng/reference/chains.html
    constructor(address _airnodeRrp) RrpRequesterV0(_airnodeRrp) {}

    /// @notice Sets parameters used in requesting QRNG services
    /// @dev No access control is implemented here for convenience. This is not
    /// secure because it allows the contract to be pointed to an arbitrary
    /// Airnode. Normally, this function should only be callable by the "owner"
    /// or not exist in the first place.
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256 Endpoint ID used to request a `uint256`
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) external {
        // Normally, this function should be protected, as in:
        // require(msg.sender == owner, "Sender not owner");
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    // -------------------------------------------------------------------
    // Platform functions
    // -------------------------------------------------------------------

    // get platform config
    function getPlatformFeeRate() external view returns (uint256) {
        return feeRate;
    }

    // set platform config, only owner can call
    function setPlatformFeeRate(uint256 _feeRate) onlyOwner external {
        feeRate = _feeRate;
    }

    // withdraw all platform fee by token
    function withdrawPlatformFee(address token) external {
        // TODO, withdraw all platform fee by token
        // Revenue from the platform needs to be recorded
    }

    // -------------------------------------------------------------------
    // Merchant functions
    // -------------------------------------------------------------------

    // Create a new Pool, only the room owner can create a pool
    function createPool() external returns (uint256 poolId) {
        poolId = _poolIdCounter.current();
        _poolIdCounter.increment();
    }

    // Delete a Pool, only the room owner can delete it
    function deletePool(uint256 _poolId) external {
        _deletePool(_poolId);
    }

    function batchDeletePool(uint256[] _poolIds) external {
        for (uint256 i = 0; i < _poolIds.length; i++) {
            _deletePool(_poolIds[i]);
        }
    }

    // @dev When paymentToken updated, the totalFeeValue will be reset to 0 and auto withdraw all fee to the owner of the pool
    // If update the pool share, will deposit the new share to the pool, new share >= old share
    function setPoolConfig(uint256 _poolId, PooConfig memory config) onlyPoolOwner(_poolId) external {

    }

    // Withdraw Pool fee
    function withdrawPoolFee(uint256 _poolId) external {
        _withdrawPoolFee(_poolId);
    }

    // Batch withdraw Pool fee
    function batchWithdrawPoolFee(uint256[] _poolIds) external {
        for (uint256 i = 0; i < _poolIds.length; i++) {
            _withdrawPoolFee(_poolIds[i]);
        }
    }

    function _deletePool(uint256 _poolId) onlyPoolOwner(_poolId) internal {
        // TODO, delete a pool from the platform
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function getPoolOwner(uint256 _poolId) public view virtual returns (address) {
        // TODO, get owner of pool
        return _owner;
    }

    function _withdrawPoolFee(uint256 _poolId) onlyPoolOwner(_poolId) internal {
        // TODO, withdraw pool fee
    }

    /**
     * @dev Throws if called by any account other than the owner of pool.
     */
    modifier onlyPoolOwner(uint256 _poolId) {
        require(getPoolOwner(_poolId) == _msgSender(), "Ownable: caller is not the owner of pool");
        _;
    }

    // -------------------------------------------------------------------
    // Player functions
    // -------------------------------------------------------------------

    // Roll, will makeRequestUint256()
    function draw(uint256 _roomId, uint256 _poolId) external {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256(requestId);
    }

    // Batch roll, will makeRequestUint256Array()
    function batchDraw(uint256 _roomId, uint256 _poolId) external {
        // TODO: batch draw size
        uint256 size = 5;
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
        // Using Airnode ABI to encode the parameters
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256Array(requestId, size);
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
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
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
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));
        // Do what you want with `qrngUint256Array` here...
        emit ReceivedUint256Array(requestId, qrngUint256Array);
    }
}