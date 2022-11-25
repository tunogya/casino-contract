//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ICash {
    event SetTax(uint256 value);

    // @notice set tax rate, 10% = 1e17
    function setTax(uint256 _value) external;

    // @notice deposit to user's credit account
    function deposit(address _token, uint256 _amount) payable external;

    // @notice withdraw tokens
    function withdraw(address _token, uint256 _amount) external;

    // @notice cash balance of a token
    function cashOf(address _token, address _account) external view returns (uint256 amount);
}