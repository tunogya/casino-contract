//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPrintingPod {
    struct Blueprint {
        string name;                     // blueprint name

    }

    // @notice Upgrade interest by native currency
    function upgradeInterest(uint256 _tokenId) external payable;

    // @notice Get max interest
    function getMaxInterest() external returns (uint8);

    function addInterestType(bytes32 _type) payable external;

    function batchAddInterestType(bytes32[] memory _types) payable external;

    function getBlueprints() external returns (Blueprint[] memory);

    function getBlueprint(uint256 _id) external returns (Blueprint memory);

    function addBlueprint(Blueprint memory _blueprint) external payable;

    function batchAddBlueprint(Blueprint[] memory _blueprints) external payable;

    function withdraw(address _token, uint256 _amount) external;
}