//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPrintingPod {
    struct DrawRequest {
        address requester;              // requester address
        bool isWaitingFulfill;          // is waiting fulfill
    }

    struct Blueprint {
        string name;                     // blueprint name
        string description;              // blueprint description
        string image;                    // blueprint image uri
    }

    struct interestDNA {
        uint8 blueprintIndex;            // dna
        uint8 interestsSize;             // interests size
        uint8 interest1Index;            // interest 1 index
        uint8 interest1Value;            // interest 1 value
        uint8 interest2Index;            // interest 2 index
        uint8 interest2Value;            // interest 2 value
        uint8 interest3Index;            // interest 3 index
        uint8 interest3Value;            // interest 3 value
    }

    // @notice Upgrade interest by native currency
    function upgradeInterest(uint256 _tokenId) external payable;

    // @notice Get max interest
    function getMaxInterest() external returns (uint8);

    function getInterestTypes(uint256 offset, uint256 limit) external view returns (string[] memory);

    function addInterestType(string calldata _type) payable external;

    function batchAddInterestTypes(string[] calldata _types) payable external;

    function getBlueprints(uint256 offset, uint256 limit) external view returns (Blueprint[] memory);

    function addBlueprint(Blueprint memory _blueprint) external payable;

    function batchAddBlueprints(Blueprint[] calldata _blueprints) external payable;

    function draw(uint256 size) external payable;

    function withdraw(address _token, uint256 _amount) external;

    function safeMint(address to, uint256[] calldata indexes) external;
}