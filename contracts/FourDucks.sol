//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IFourDucks.sol";

contract FourDucks is RrpRequesterV0, IFourDucks, Ownable {
    event RequestedUint256(address indexed poolId, bytes32 indexed requestId);
    event ReceivedUint256(address indexed poolId, bytes32 indexed requestId, uint256 response);
    event Stake(address indexed poolId, address indexed player, address token, int256 amount);
    event SetFee(uint256 value);

    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;
    uint256 public fee;

    address public constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => PoolConfig) private poolConfigMap;
    mapping(bytes32 => StakeRequest) private stakeRequestMap;

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
        require(_value <= 1 ether, "Fee must be less than 1 ether");

        fee = _value;
        emit SetFee(_value);
    }

    function _eligibilityOf(address _poolId, address _player) internal view returns (bool eligibility) {
        PoolConfig memory config = poolConfigMap[_poolId];
        eligibility = true;
        for (uint256 i = 0; i < config.players.length; i++) {
            if (config.players[i] == _player) {
                eligibility = false;
                break;
            }
        }
    }

    function _abs(int256 x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(- x);
    }

    function stake(address _poolId, address _token, int256 _amount) payable external {
        PoolConfig storage config = poolConfigMap[_poolId];
        require(config.players.length < 4, "FourDucks: max players count is 4");
        require(_eligibilityOf(_poolId, msg.sender), "FourDucks: no eligibility");
        require(_abs(_amount) > 0, "FourDucks: amount must be greater than 0");

        if (_token == NATIVE_CURRENCY) {
            require(msg.value >= _abs(_amount), "FourDucks: msg.value must be equal to amount");
        } else {
            require(ERC20(_token).transferFrom(msg.sender, address(this), _abs(_amount)), "FourDucks: transferFrom failed");
        }

        config.players[config.players.length] = msg.sender;
        config.tokens[config.players.length] = _token;
        config.amount[config.players.length] = _amount;
        emit Stake(_poolId, msg.sender, _token, _amount);

        if (config.players.length == 4) {
            bytes32 requestId = airnodeRrp.makeFullRequest(
                airnode,
                endpointIdUint256,
                address(this),
                sponsorWallet,
                address(this),
                this.fulfillUint256.selector,
                ""
            );
            stakeRequestMap[requestId] = StakeRequest(_poolId, true);
            emit RequestedUint256(_poolId, requestId);
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
        address poolId = stakeRequestMap[requestId].poolId;
        emit ReceivedUint256(poolId, requestId, qrngUint256);

        uint256[] memory ducksCoordinates = new uint256[](8);
        uint256 max;
        uint256 min;
        for (uint256 i = 0; i < 8; i++) {
            ducksCoordinates[i] = qrngUint256 & 0xffffffff;
            if (i % 2 == 0) {
                if (i == 0) {
                    max = ducksCoordinates[i];
                    min = ducksCoordinates[i];
                } else {
                    if (ducksCoordinates[i] > max) {
                        max = ducksCoordinates[i];
                    }
                    if (ducksCoordinates[i] < min) {
                        min = ducksCoordinates[i];
                    }
                }
            }
            qrngUint256 = qrngUint256 >> 32;
        }

        if (max - min <= 0x80000000) {
            _settle(poolId, true);
        } else {
            _settle(poolId, false);
        }
    }

    function _settle(address _poolId, bool unified) internal {
        PoolConfig storage config = poolConfigMap[_poolId];
        for (uint256 i = 0; i < 4; i++) {
            if (config.amount[i] > 0 && unified || config.amount[i] < 0 && !unified) {
                uint256 balance = ERC20(config.tokens[i]).balanceOf(address(this));
                uint256 amount = _abs(config.amount[i]);
                if (balance < amount) {
                    amount = balance;
                }
                ERC20(config.tokens[i]).transfer(config.players[i], amount * 2 * (1 ether - fee) / 1 ether);
            }
        }
        delete poolConfigMap[_poolId];
    }

    function withdraw(address token, uint256 amount) onlyOwner external {
        if (token == NATIVE_CURRENCY) {
            require(amount <= address(this).balance, "Not enough balance");
            payable(msg.sender).transfer(amount);
        } else {
            require(amount <= ERC20(token).balanceOf(address(this)), "Not enough balance");
            ERC20(token).transfer(msg.sender, amount);
        }
    }

    function poolConfigOf(address _poolId) external view returns (PoolConfig memory) {
        return poolConfigMap[_poolId];
    }

    function stakeRequestOf(bytes32 requestId) external view returns (StakeRequest memory) {
        return stakeRequestMap[requestId];
    }
}