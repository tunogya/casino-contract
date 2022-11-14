// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";
import "../interfaces/IPrintingPod.sol";
import "../lib/RrpRequesterV0Upgradeable.sol";

contract PrintingPod is Initializable, ERC721Upgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IPrintingPod, RrpRequesterV0Upgradeable {
    event AddInterestType(string indexed _type);
    event RequestedUint256Array(address indexed requester, bytes32 indexed requestId);
    event ReceivedUint256Array(address indexed requester, bytes32 indexed requestId, uint256[] indexed response);
    event SetSponsorFee(uint256 indexed value);

    using CountersUpgradeable for CountersUpgradeable.Counter;

    using Strings for uint256;

    address public airnode;
    bytes32 public endpointIdUint256Array;
    address public sponsorWallet;

    uint8 constant MAX_INTEREST_POINTS = 20;

    CountersUpgradeable.Counter private _tokenIdCounter;
    CountersUpgradeable.Counter private _blueprintsCounter;
    CountersUpgradeable.Counter private _interestTypesCounter;

    Blueprint[256] private blueprints;
    string[256] private interestTypes;

    // @notice check if a interest has existed
    mapping(string => bool) public interestTypeMap;

    mapping(address => interestDNA[]) private draftInterestDNAsMap;

    // @notice requestId => DrawRequest
    mapping(bytes32 => DrawRequest) private drawRequestMap;

    // @notice tokenId => interestDNA
    mapping(uint256 => interestDNA) private printInterestDNAMap;

    uint256 public sponsorFee;

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

    function safeMint(address to, uint256[] calldata indexes) external {
        for (uint256 i = 0; i < indexes.length; i++) {
            require(indexes[i] < draftInterestDNAsMap[msg.sender].length, "invalid index");

            uint256 tokenId = _tokenIdCounter.current();
            printInterestDNAMap[tokenId] = draftInterestDNAsMap[msg.sender][indexes[i]];
            _safeMint(to, tokenId);
        }
        delete draftInterestDNAsMap[msg.sender];
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
    function getMaxInterestPoints() external pure returns (uint8) {
        return MAX_INTEREST_POINTS;
    }

    function addInterestType(string calldata _type) payable external {
        require(interestTypeMap[_type] == false, "PrintingPod: Interest type already exists");
        require(msg.value >= sponsorFee, "PrintingPod: Sponsor fee is not enough");

        interestTypeMap[_type] = true;

        interestTypes[_interestTypesCounter.current() % 256] = _type;
        _interestTypesCounter.increment();

        emit AddInterestType(_type);
    }

    function batchAddInterestTypes(string[] calldata _types) payable external {
        for (uint256 i = 0; i < _types.length; i++) {
            string memory _type = _types[i];
            require(interestTypeMap[_type] == false, "PrintingPod: Interest type already exists");
            emit AddInterestType(_type);

            interestTypeMap[_type] = true;
            interestTypes[_interestTypesCounter.current() % 256] = _type;
            _interestTypesCounter.increment();
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        interestDNA storage dna = printInterestDNAMap[tokenId];

        uint256 interest1Value = uint256(dna.interest1Value);
        uint256 interest2Value = uint256(dna.interest2Value);
        uint256 interest3Value = uint256(dna.interest3Value);

        return string(
            abi.encodePacked(
                abi.encodePacked(
                    'data:application/json;base64,',
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                dna.name,
                                '","description":"',
                                dna.description,
                                '","image":"',
                                dna.image,
                                '","attributes":[{"trait_type":"',
                                dna.interest1Type,
                                '","value":',
                                Strings.toString(interest1Value),
                                dna.interestsSize >= 2 ? string(
                                abi.encodePacked(
                                    '},{"trait_type":"',
                                    dna.interest2Type,
                                    '","value":',
                                    Strings.toString(interest2Value)
                                )
                            ) : "",
                                dna.interestsSize >= 3 ? string(
                                abi.encodePacked(
                                    '},{"trait_type":"',
                                    dna.interest3Type,
                                    '","value":',
                                    Strings.toString(interest3Value)
                                )
                            ) : "",
                                '}]}'
                            )
                        )
                    )
                )
            )
        );
    }

    function getBlueprints(uint256 offset, uint256 limit) external view returns (Blueprint[] memory) {
        Blueprint[] memory _blueprints = new Blueprint[](limit);
        for (uint256 i = 0; i < limit; i++) {
            _blueprints[i] = blueprints[offset + i];
        }
        return _blueprints;
    }

    function addBlueprint(Blueprint calldata _blueprint) onlyOwner external {
        blueprints[_blueprintsCounter.current() % 256] = _blueprint;
        _blueprintsCounter.increment();
    }

    function batchAddBlueprints(Blueprint[] calldata _blueprints) onlyOwner external {
        for (uint256 i = 0; i < _blueprints.length; i++) {
            blueprints[_blueprintsCounter.current() % 256] = _blueprints[i];
            _blueprintsCounter.increment();
        }
    }

    function getInterestTypes(uint256 offset, uint256 limit) external view returns (string[] memory) {
        string[] memory _interestTypes = new string[](limit);
        for (uint256 i = 0; i < limit; i++) {
            _interestTypes[i] = interestTypes[offset + i];
        }
        return _interestTypes;
    }

    function withdraw(address _token, uint256 _amount) onlyOwner external {
        if (_token == address(0)) {
            require(_amount <= address(this).balance, "PrintingPod: Not enough balance");
            payable(msg.sender).transfer(_amount);
        } else {
            require(_amount <= ERC20(_token).balanceOf(address(this)), "PrintingPod: Not enough balance");
            ERC20(_token).transfer(msg.sender, _amount);
        }
    }

    function draftInterestDNAsOf(address _owner) external view returns (interestDNA[] memory) {
        return draftInterestDNAsMap[_owner];
    }

    function printInterestDNAOf(uint256 _tokenId) external view returns (interestDNA memory) {
        return printInterestDNAMap[_tokenId];
    }

    function blueprintsCounter() external view returns (uint256) {
        return _blueprintsCounter.current();
    }

    function interestTypesCounter() external view returns (uint256) {
        return _interestTypesCounter.current();
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /// @notice Called by the Airnode through the AirnodeRrp contract to
    /// fulfill the request
    /// @param requestId Request ID
    /// @param data ABI-encoded response
    function fulfillUint256Array(bytes32 requestId, bytes calldata data)
    external
    onlyAirnodeRrp
    {
        require(
            drawRequestMap[requestId].isWaitingFulfill,
            "PrintingPod: Request ID not known"
        );
        uint256[] memory qrngUint256Array = abi.decode(data, (uint256[]));
        address requester = drawRequestMap[requestId].requester;
        emit ReceivedUint256Array(requester, requestId, qrngUint256Array);

        delete draftInterestDNAsMap[requester];
        uint256 interestTypesCount = interestTypes.length;
        for (uint256 i = 0; i < qrngUint256Array.length; i++) {
            uint256 interestRNG = qrngUint256Array[i];
            uint8 blueprintIndex = uint8(uint256(interestRNG % blueprints.length));
            uint8 interestsSize = uint8(uint256(interestRNG % _min(3, interestTypesCount)) + 1);
            uint8 value = 10;
            uint8 interest1Index = uint8(uint256(keccak256(abi.encodePacked(interestRNG + 0))) % interestTypesCount);
            uint8 interest2Index;
            uint8 interest3Index;
            if (interestsSize >= 2) {
                interest2Index = uint8(uint256(keccak256(abi.encodePacked(interestRNG + 1))) % interestTypesCount);
                value = 3;
            }
            if (interestsSize >= 3) {
                interest3Index = uint8(uint256(keccak256(abi.encodePacked(interestRNG + 2))) % interestTypesCount);
                value = 1;
            }

            draftInterestDNAsMap[requester].push(interestDNA(
                    blueprints[blueprintIndex].name,
                    blueprints[blueprintIndex].description,
                    blueprints[blueprintIndex].image,
                    interestTypes[interest1Index],
                    interestTypes[interest2Index],
                    interestTypes[interest3Index],
                    interestsSize,
                    value,
                    value,
                    value
                ));
        }

        delete drawRequestMap[requestId];
    }

    function setSponsorFee(uint256 _value) onlyOwner external {
        sponsorFee = _value;
        emit SetSponsorFee(_value);
    }
}
