// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "../interfaces/IPrintingPod.sol";

contract PrintingPod is Initializable, ERC721Upgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IPrintingPod {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    uint8 constant MAX_INTEREST = 20;

    CountersUpgradeable.Counter private _tokenIdCounter;

    Blueprint[] public blueprints;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("Printing Pod", "PP");
        __ERC721Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function safeMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyOwner
    override
    {}

    // @notice Upgrade interest by native currency
    function upgradeInterest(uint256 _tokenId) external payable {

    }

    // @notice Get max interest
    function getMaxInterest() external pure returns (uint8) {
        return MAX_INTEREST;
    }

    function addInterestType(bytes32 _type) payable external {

    }

    function batchAddInterestType(bytes32[] memory _types) payable external {

    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return "";
    }

    function getBlueprints() external view returns (Blueprint[] memory) {
        return blueprints;
    }

    function getBlueprint(uint256 _id) external view returns (Blueprint memory) {
        return blueprints[_id];
    }

    function addBlueprint(Blueprint memory _blueprint) external payable {

    }

    function batchAddBlueprint(Blueprint[] memory _blueprints) external payable {

    }

    function withdraw(address _token, uint256 _amount) external {

    }

}
