//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ICash {
    event SetTax(uint256 value);

    // @notice set tax rate, 10% = 1e17
    function setTax(uint256 _value) external returns (bool);

    // @notice deposit to user's credit account
    function deposit(address _token, uint256 _amount) payable external returns (bool);

    // @notice withdraw tokens
    function withdraw(address _token, uint256 _amount) external returns (bool);

    // @notice withdraw tax tokens
    function withdrawTax(address _token, uint256 _amount) external returns (bool);

    // @notice balance of a token
    function balanceOf(address _token, address _account) external view returns (uint256 amount);

    function transfer(address _token, address _to, uint256 _amount) external returns (bool);

    function transferFrom(address _token, address _from, address _to, uint256 _amount) external returns (bool);

    function mint(address _token, address _to, uint256 _amount) external returns (bool);

    function burn(address _token, address _from, uint256 _amount) external returns (bool);
}