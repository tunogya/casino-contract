//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IFourDucks.sol";

contract FourDucks is RrpRequesterV0, IFourDucks, Ownable {
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event Withdraw(address indexed token, uint256 value);
    event WithdrawETH(uint256 value);
    event Stake(address indexed poolId, address indexed player, address token, uint256 amount, bool unified);
    event Opening(address indexed poolId, bytes32 requestId);
    event SetFee(uint256 value);
    event RevealLocation(address indexed poolId, uint256[] coordinate, bool unified);

    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;
    uint256 public fee;

    mapping(address => PoolConfig) public poolConfigMap;
    mapping(bytes32 => StakeRequest) public stakeRequestMap;

    /// @dev RrpRequester sponsors itself, meaning that it can make requests
    /// that will be fulfilled by its sponsor wallet. See the Airnode protocol
    /// docs about sponsorship for more information.
    /// @param _airnodeRrp Airnode RRP contract address, view https://docs.api3.org/qrng/reference/chains.html
    constructor(address _airnodeRrp) RrpRequesterV0(_airnodeRrp) {}

    /// @notice Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256 Endpoint ID used to request a `uint256`
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        address _sponsorWallet
    ) onlyOwner external {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
    }

    function setFee(uint256 _value) onlyOwner external {
        setFee(_value);
        emit SetFee(_value);
    }

    function _playersCountOf(address _poolId) internal view returns (uint256 count) {
        PoolConfig memory config = poolConfigMap[_poolId];
        count = 0;
        for (uint256 i = 0; i < 4; i++) {
            if (config.players[i] != address(0)) {
                count++;
            } else {
                break;
            }
        }
    }

    function _eligibilityOf(address _poolId, address _player) internal view returns (bool eligibility) {
        PoolConfig memory config = poolConfigMap[_poolId];
        eligibility = true;
        for (uint256 i = 0; i < 4; i++) {
            if (config.players[i] == _player) {
                eligibility = false;
                break;
            }
        }
    }

    function stake(address _poolId, address _token, uint256 _amount, bool _unified) external {
        PoolConfig storage poolConfig = poolConfigMap[_poolId];
        require(_playersCountOf(_poolId) < 4, "FourDucks: players count is 4");
        require(_eligibilityOf(_poolId, msg.sender, "FourDucks: no eligibility"));
        ERC20(_token).transferFrom(msg.sender, address(this), _amount);
        poolConfig.players[_playersCountOf(_poolId)] = msg.sender;
        poolConfig.tokens[_playersCountOf(_poolId)] = _token;
        poolConfig.amount[_playersCountOf(_poolId)] = _amount;
        poolConfig.unified[_playersCountOf(_poolId)] = _unified;
        emit Stake(_poolId, msg.sender, _token, _amount, _unified);

        if (_playersCountOf(_poolId) == 4) {
            bytes32 requestId = airnodeRrp.makeFullRequest(
                airnode,
                endpointIdUint256Array,
                address(this),
                sponsorWallet,
                address(this),
                this.fulfillUint256Array.selector,
                abi.encode(bytes32("1u"), bytes32("size"), 4)
            );
            stakeRequestMap[requestId] = StakeRequest(_poolId, true);
            emit Opening(_poolId, requestId);
        }
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
            stakeRequestMap[requestId].isWaitingFulfill,
            "Request ID not known"
        );
        stakeRequestMap[requestId].isWaitingFulfill = false;
        uint256 qrngUint256 = abi.decode(data, (uint256));
        emit ReceivedUint256(requestId, qrngUint256);

        uint256[8] ducksCoordinates;
        uint256 max;
        uint256 min;
        for (uint256 i = 0; i < 8; i++) {
            qrngUint256 << 32 * i;
            ducksCoordinates[i] = qrngUint256 & 0xffffffff;
            if (i % 2 == 0 && ducksCoordinates[i] > max) {
                max = ducksCoordinates[i];
            }
            if (i % 2 == 0 && (ducksCoordinates[i] < min || min == 0)) {
                min = ducksCoordinates[i];
            }
        }
        uint256 poolId = stakeRequestMap[requestId].poolId;
        if (max - min < 0x80000000) {
            emit RevealLocation(poolId, ducksCoordinates, true);
            _settle(poolId, true);
        } else {
            emit RevealLocation(poolId, ducksCoordinates, false);
            _settle(poolId, false);
        }
    }

    function _settle(address _poolId, bool unified) internal {
        PoolConfig storage config = poolConfigMap[_poolId];
        // settle reward

    }

    function withdraw(address _token, uint256 _amount) onlyOwner external {
        require(_amount <= ERC20(_token).balanceOf(address(this)), "Not enough balance");
        ERC20(_token).transfer(msg.sender, amount);
        emit Withdraw(_token, _amount);
    }

    function withdrawETH(uint256 _amount) onlyOwner external {
        require(_amount <= address(this).balance, "Not enough balance");
        payable(msg.sender).transfer(_amount);
        emit WithdrawETH(_amount);
    }

    function poolConfigOf(address _poolId) external view returns (PoolConfig memory) {
        return poolConfigMap[_poolId];
    }
}