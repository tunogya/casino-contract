//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ICash.sol";

contract Cash is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ICash {
    // 10% = 1e17, tax will send to cash-address (this), only admin can set and withdraw tax
    uint256 public tax;

    // @notice account => token => amount
    mapping(address => mapping(address => uint256)) private accountCashMap;

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // @notice set tax rate, 10% = 1e17
    function setTax(uint256 _value)
    onlyRole(DEFAULT_ADMIN_ROLE)
    external
    returns (bool)
    {
        require(_value <= 1e18, "Platform Fee must be less than 1e18");
        tax = _value;
        emit SetTax(_value);
        return true;
    }

    // @notice deposit to user's cash account
    // if _token is Address(0), deposit ETH, else deposit ERC20
    // need to approve first
    function deposit(address _token, uint256 _amount) payable external returns (bool) {
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
        return true;
    }

    // @notice withdraw tokens
    // check if user has enough cash, if not, withdraw all
    // if tax > 0, withdraw (1e18 - tax) * _amount
    // if _token is Address(0), withdraw ETH, else withdraw ERC20
    // tax will be sent to contract self, only owner can withdraw
    function withdraw(address _token, uint256 _amount) external returns (bool) {
        uint256 cash = accountCashMap[msg.sender][_token];
        if (cash < _amount) {
            _amount = cash;
        }
        unchecked {
            accountCashMap[msg.sender][_token] -= _amount;
        }
        if (tax > 0) {
            uint256 taxAmount = _amount * tax / 1e18;
            unchecked {
                _amount -= taxAmount;
            }
            accountCashMap[address(this)][_token] += taxAmount;
        }
        if (_token == address(0)) {
            payable(address(msg.sender)).transfer(_amount);
        } else {
            ERC20(_token).transfer(address(msg.sender), _amount);
        }
        return true;
    }

    function withdrawTax(address _token, uint256 _amount)
    onlyRole(DEFAULT_ADMIN_ROLE)
    external
    returns (bool)
    {
        // check if contract has enough cash
        // if not, withdraw all
        // if _token is Address(0), withdraw ETH, else withdraw ERC20
        uint256 cash = accountCashMap[address(this)][_token];
        if (cash < _amount) {
            _amount = cash;
        }
        // update cash first
        unchecked {
            accountCashMap[address(this)][_token] -= _amount;
        }
        if (_token == address(0)) {
            payable(address(msg.sender)).transfer(_amount);
        } else {
            ERC20(_token).transfer(address(msg.sender), _amount);
        }
        return true;
    }

    // @notice balance of a token
    function balanceOf(address _token, address _account) external view returns (uint256 amount) {
        amount = accountCashMap[_account][_token];
    }

    function transfer(address _token, address _to, uint256 _amount) external override returns (bool) {
        uint256 cash = accountCashMap[msg.sender][_token];
        require(cash >= _amount, "Not enough cash");
        unchecked {
            accountCashMap[msg.sender][_token] -= _amount;
        }
        accountCashMap[_to][_token] += _amount;
        return true;
    }

    // @notice only admin can transfer from other account
    function transferFrom(address _token, address _from, address _to, uint256 _amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    returns (bool)
    {
        require(_from != address(0), "transfer from the zero address");
        require(_to != address(0), "transfer to the zero address");

        uint256 cash = accountCashMap[_from][_token];
        require(cash >= _amount, "Not enough cash");
        unchecked {
            accountCashMap[_from][_token] -= _amount;
        }
        accountCashMap[_to][_token] += _amount;
        return true;
    }

    // @notice direct add cash to account, no transfer
    function mint(address _token, address _to, uint256 _amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    returns (bool)
    {
        accountCashMap[_to][_token] += _amount;
        return true;
    }

    // @notice direct remove cash from account, no transfer
    function burn(address _token, address _from, uint256 _amount)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
    returns (bool)
    {
        uint256 cash = accountCashMap[_from][_token];
        // if not enough cash, burn all
        if (cash < _amount) {
            _amount = cash;
        }
        unchecked {
            accountCashMap[_from][_token] -= _amount;
        }
        return true;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(DEFAULT_ADMIN_ROLE)
    override
    {}
}