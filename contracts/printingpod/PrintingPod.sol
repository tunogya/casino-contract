// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IPrintingPod.sol";

contract PrintingPod is Initializable, ERC721Upgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IPrintingPod {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    uint8 constant MAX_INTEREST = 20;

    CountersUpgradeable.Counter private _tokenIdCounter;

    Blueprint[] public blueprints;
    bytes32[] public interestTypes;

    mapping(bytes32 => bool) public interestTypeMap;

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
        require(interestTypeMap[_type] == false, "Interest type already exists");

        interestTypeMap[_type] = true;
        interestTypes.push(_type);

        // add event
    }

    function batchAddInterestTypes(bytes32[] memory _types) payable external {
        for (uint256 i = 0; i < _types.length; i++) {
            bytes32 _type = _types[i];
            require(interestTypeMap[_type] == false, "Interest type already exists");

            interestTypeMap[_type] = true;
            interestTypes.push(_type);
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return "";
    }

    function getBlueprints(uint256 offset, uint256 limit) external view returns (Blueprint[] memory) {
        Blueprint[] memory _blueprints = new Blueprint[](limit);

        for (uint256 i = 0; i < limit; i++) {
            _blueprints[i] = blueprints[offset + i];
        }

        return _blueprints;
    }

    function addBlueprint(Blueprint memory _blueprint) external payable {
        blueprints.push(_blueprint);
    }

    function batchAddBlueprints(Blueprint[] memory _blueprints) external payable {
        for (uint256 i = 0; i < _blueprints.length; i++) {
            blueprints.push(_blueprints[i]);
        }
    }

    function getInterestTypes(uint256 offset, uint256 limit) external view returns (bytes32[] memory) {
        bytes32[] memory _interestTypes = new bytes32[](limit);

        for (uint256 i = 0; i < limit; i++) {
            _interestTypes[i] = interestTypes[offset + i];
        }

        return _interestTypes;
    }

    function withdraw(address _token, uint256 _amount) onlyOwner external {
        if (_token == address(0)) {
            require(_amount <= address(this).balance, "Not enough balance");
            payable(msg.sender).transfer(_amount);
        } else {
            require(_amount <= ERC20(_token).balanceOf(address(this)), "Not enough balance");
            ERC20(_token).transfer(msg.sender, _amount);
        }
    }
}
