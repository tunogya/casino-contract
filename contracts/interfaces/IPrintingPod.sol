//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPrintingPod {
    struct DrawRequest {
        address requester;              // requester address
        bool isWaitingFulfill;          // is waiting fulfill
    }

    struct Blueprint {
        string name;                     // blueprint name

    }

    // @notice Upgrade interest by native currency
    function upgradeInterest(uint256 _tokenId) external payable;

    // @notice Get max interest
    function getMaxInterest() external returns (uint8);

    function getInterestTypes(uint256 offset, uint256 limit) external view returns (bytes32[] memory);

    function addInterestType(bytes32 _type) payable external;

    function batchAddInterestTypes(bytes32[] memory _types) payable external;

    function getBlueprints(uint256 offset, uint256 limit) external view returns (Blueprint[] memory);

    function addBlueprint(Blueprint memory _blueprint) external payable;

    function batchAddBlueprints(Blueprint[] memory _blueprints) external payable;

    function draw(uint256 size) external payable;

    function withdraw(address _token, uint256 _amount) external;
}