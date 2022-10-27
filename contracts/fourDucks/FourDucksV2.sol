//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IFourDucks.sol";
import "../lib/RrpRequesterV0Upgradeable.sol";

contract FourDucksV2 is Initializable, RrpRequesterV0Upgradeable, OwnableUpgradeable, UUPSUpgradeable, IFourDucks {
    event RequestedUint256(address indexed poolId, bytes32 indexed requestId);
    event ReceivedUint256(address indexed poolId, bytes32 indexed requestId, uint256 response);
    event SoloStake(address indexed poolId, address indexed player, address token, int256 amount);
    event PooledStake(address indexed poolId, address indexed player, address token, int256 amount);
    event SetPlatformFee(uint256 value);
    event SetSponsorFee(uint256 value);

    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;
    uint256 public platformFee;
    uint256 public sponsorFee;

    address public constant NATIVE_CURRENCY = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping(address => PoolConfig) private poolConfigMap;
    mapping(bytes32 => StakeRequest) private stakeRequestMap;

    /// @custom:oz-upgrades-unsafe-allow constructor
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

    function setPlatformFee(uint256 _value) onlyOwner external {
        require(_value <= 1 ether, "Platform Fee must be less than 1 ether");
        platformFee = _value;
        emit SetPlatformFee(_value);
    }

    function setSponsorFee(uint256 _value) onlyOwner external {
        sponsorFee = _value;
        emit SetPlatformFee(_value);
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

    function soloStake(address _poolId, address _token, int256 _amount) payable external {
        require(_poolId == msg.sender, "PoolId must be equal to Sender");
        PoolConfig storage config = poolConfigMap[_poolId];
        require(_abs(_amount) > 0, "FourDucks: amount must be greater than 0");
        require(msg.value >= sponsorFee, "FourDucks: sponsor fee is not enough");

        if (_token == NATIVE_CURRENCY) {
            require(msg.value >= _abs(_amount) + sponsorFee, "FourDucks: eth amount is not enough");
        } else {
            require(ERC20(_token).transferFrom(msg.sender, address(this), _abs(_amount)), "FourDucks: transferFrom failed");
        }
        (bool success,) = sponsorWallet.call{value : sponsorFee}("");
        require(success, "FourDucks: transfer sponsor fee failed");

        config.players.push(msg.sender);
        config.tokens.push(_token);
        config.amount.push(_amount);
        emit SoloStake(_poolId, msg.sender, _token, _amount);

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

    function pooledStake(address _poolId, address _token, int256 _amount) payable external {
        PoolConfig storage config = poolConfigMap[_poolId];
        require(config.players.length < 2, "FourDucks: max players count is 2");
        require(_eligibilityOf(_poolId, msg.sender), "FourDucks: no eligibility");
        require(_abs(_amount) > 0, "FourDucks: amount must be greater than 0");

        if (_token == NATIVE_CURRENCY) {
            require(msg.value >= _abs(_amount), "FourDucks: eth amount is not enough");
        } else {
            require(ERC20(_token).transferFrom(msg.sender, address(this), _abs(_amount)), "FourDucks: transferFrom failed");
        }
        config.players.push(msg.sender);
        config.tokens.push(_token);
        config.amount.push(_amount);
        emit PooledStake(_poolId, msg.sender, _token, _amount);

        if (config.players.length == 2) {
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
        uint256 qrngUint256 = abi.decode(data, (uint256));
        address poolId = stakeRequestMap[requestId].poolId;
        emit ReceivedUint256(poolId, requestId, qrngUint256);

        uint256[] memory ducksCoordinates = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            ducksCoordinates[i] = qrngUint256 & 0xffffffff;
            qrngUint256 = qrngUint256 >> 64;
        }

        bool result = _distance(ducksCoordinates[0], ducksCoordinates[1], 2 ** 32) <= 2 ** 31 &&
        _distance(ducksCoordinates[0], ducksCoordinates[2], 2 ** 32) <= 2 ** 31 &&
        _distance(ducksCoordinates[0], ducksCoordinates[3], 2 ** 32) <= 2 ** 31 &&
        _distance(ducksCoordinates[1], ducksCoordinates[2], 2 ** 32) <= 2 ** 31 &&
        _distance(ducksCoordinates[1], ducksCoordinates[3], 2 ** 32) <= 2 ** 31 &&
        _distance(ducksCoordinates[2], ducksCoordinates[3], 2 ** 32) <= 2 ** 31;

        if (result) {
            _settle(poolId, true);
        } else {
            _settle(poolId, false);
        }
        delete stakeRequestMap[requestId];
    }

    function _distance(uint256 a, uint256 b, uint256 mod) internal pure returns (uint256) {
        uint256 d = a > b ? a - b : b - a;
        return d > mod / 2 ? mod - d : d;
    }

    function _max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _abs(int256 x) private pure returns (uint256) {
        return x >= 0 ? uint256(x) : uint256(- x);
    }

    function _settle(address _poolId, bool unified) internal {
        PoolConfig storage config = poolConfigMap[_poolId];
        for (uint256 i = 0; i < config.players.length; i++) {
            if (config.players[i] != address(0) && config.tokens[i] != address(0) && (config.amount[i] > 0 && unified || config.amount[i] < 0 && !unified)) {
                uint256 amount = _min(uint256(_abs(config.amount[i])), _safeBalanceOf(config.tokens[i], address(this)));
                _safeTransfer(config.tokens[i], config.players[i], amount * 2 * (1 ether - platformFee) / 1 ether);
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

    function _safeBalanceOf(address _token, address _account) internal view returns (uint256) {
        if (_token == NATIVE_CURRENCY) {
            return _account.balance;
        } else {
            return ERC20(_token).balanceOf(_account);
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        if (token == NATIVE_CURRENCY) {
            payable(to).transfer(value);
        } else {
            ERC20(token).transfer(to, value);
        }
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}
}