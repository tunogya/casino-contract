//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ICash.sol";

contract Cash is Initializable, OwnableUpgradeable, UUPSUpgradeable, ICash {
    uint256 public tax;

    // account => token => amount
    mapping(address => mapping(address => uint256)) private accountCashMap;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    // @notice set tax rate, 10% = 1e17
    function setTax(uint256 _value) onlyOwner external {
        require(_value <= 1e18, "Platform Fee must be less than 1e18");
        tax = _value;

        emit SetTax(_value);
    }

    // @notice deposit to user's cash account
    // if _token is Address(0), deposit ETH, else deposit ERC20
    // need to approve first
    function deposit(address _token, uint256 _amount) payable external {
        if (_token == address(0)) {
            require(msg.value == _amount, "msg.value must be equal to _amount");
            accountCashMap[msg.sender][_token] += _amount;
        } else {
            ERC20(_token).transferFrom(msg.sender, address(this), _amount);
            accountCashMap[msg.sender][_token] += _amount;
            if (msg.value > 0) {
                accountCashMap[msg.sender][address(0)] += msg.value;
            }
        }
    }

    // @notice withdraw tokens
    // check if user has enough cash, if not, withdraw all
    // if tax > 0, withdraw (1e18 - tax) * _amount
    // if _token is Address(0), withdraw ETH, else withdraw ERC20
    // tax will be sent to contract self, only owner can withdraw
    function withdraw(address _token, uint256 _amount) external {
        uint256 cash = accountCashMap[msg.sender][_token];
        if (cash < _amount) {
            _amount = cash;
        }
        accountCashMap[msg.sender][_token] -= _amount;
        if (tax > 0) {
            uint256 taxAmount = _amount * tax / 1e18;
            _amount -= taxAmount;
            accountCashMap[address(this)][_token] += taxAmount;
        }
        if (_token == address(0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            ERC20(_token).transfer(msg.sender, _amount);
        }
    }

    function withdrawTax(address _token, uint256 _amount) onlyOwner external {
        // check if contract has enough cash
        // if not, withdraw all
        // if _token is Address(0), withdraw ETH, else withdraw ERC20
        uint256 cash = accountCashMap[address(this)][_token];
        if (cash < _amount) {
            _amount = cash;
        }
        // update cash first
        accountCashMap[address(this)][_token] -= _amount;
        if (_token == address(0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            ERC20(_token).transfer(msg.sender, _amount);
        }
    }

    // @notice cash balance of a token
    function cashOf(address _token, address _account) external view returns (uint256 amount) {
        amount = accountCashMap[_account][_token];
    }
}