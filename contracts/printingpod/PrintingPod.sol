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
import "../lib/RrpRequesterV0Upgradeable.sol";

contract PrintingPod is Initializable, ERC721Upgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IPrintingPod, RrpRequesterV0Upgradeable {
    event AddInterestType(bytes32 indexed _type);
    event RequestedUint256Array(address indexed user, bytes32 indexed requestId);
    event ReceivedUint256Array(address indexed user, bytes32 indexed requestId, uint256[] indexed response);

    using CountersUpgradeable for CountersUpgradeable.Counter;

    address public airnode;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    uint8 constant MAX_INTEREST = 20;

    CountersUpgradeable.Counter private _tokenIdCounter;

    Blueprint[] public blueprints;
    bytes32[] public interestTypes;

    // @notice check if a interest has existed
    mapping(bytes32 => bool) public interestTypeMap;

    // @notice interestRNGs only record current valid data when draw
    mapping(address => uint256[]) public interestRNGsMap;

    // @notice requestId => DrawRequest
    mapping(bytes32 => DrawRequest) private drawRequestMap;

    // @notice tokenId => interestDNA
    mapping(uint256 => uint256) public printInterestMap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _airnodeRrp) initializer public {
        __ERC721_init("Printing Pod", "PP");
        __ERC721Burnable_init();
        __RrpRequesterV0_init(_airnodeRrp);
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Sets parameters used in requesting QRNG services
    /// @param _airnode Airnode address
    /// @param _endpointIdUint256Array Endpoint ID used to request a `uint256[]`
    /// @param _sponsorWallet Sponsor wallet address
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256Array,
        address _sponsorWallet
    ) onlyOwner external {
        airnode = _airnode;
        endpointIdUint256Array = _endpointIdUint256Array;
        sponsorWallet = _sponsorWallet;
    }

    function draw(uint256 size) external payable {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256Array,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256Array.selector,
            abi.encode(bytes32("1u"), bytes32("size"), size)
        );
        drawRequestMap[requestId] = DrawRequest(msg.sender, true);
        emit RequestedUint256Array(msg.sender, requestId);
    }

    function safeMint(address to, uint256 index) external {
        require(index < interestRNGsMap[msg.sender].length, "invalid index");

        uint256 tokenId = _tokenIdCounter.current();
        printInterestMap[tokenId] = interestRNGsMap[msg.sender][index];

        delete interestRNGsMap[msg.sender];

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

        emit AddInterestType(_type);
    }

    function batchAddInterestTypes(bytes32[] memory _types) payable external {
        for (uint256 i = 0; i < _types.length; i++) {
            bytes32 _type = _types[i];
            require(interestTypeMap[_type] == false, "Interest type already exists");
            emit AddInterestType(_type);

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

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256Array(bytes32 requestId, bytes calldata data)
    external
    onlyAirnodeRrp
    {
    }
}
