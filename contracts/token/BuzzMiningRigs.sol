pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interface/IBuzzMiningRigs.sol";
import "../library/ERC1155Supply.sol";

contract BuzzMiner is
    IBuzzMiningRigs,
    AccessControl,
    ERC1155Supply,
    Ownable,
    ReentrancyGuard
{
    using Strings for uint256;

    bool private initialized;

    mapping(uint256 => uint256) public minerQualities;

    string constant ROLE_MINTER_STR = "ROLE_MINTER";

    // 0xaeaef46186eb59f884e36929b6d682a6ae35e1e43d8f05f058dcefb92b601461
    bytes32 constant ROLE_MINTER = keccak256(bytes(ROLE_MINTER_STR));

    string constant ROLE_MINTER_ADMIN_STR = "ROLE_MINTER_ADMIN";

    // 0xc30b6f1bcbf41750053d221187e3d61595d548191e1ee1cab3dd3ae1dc469c0a
    bytes32 constant ROLE_MINTER_ADMIN =
        keccak256(bytes(ROLE_MINTER_ADMIN_STR));

    event SetMinerQuality(uint256 _id, uint256 _quality);
    event SetBaseURI(string baseURI);
    event MintMiner(address to, uint256 id, uint256 amount);
    event MintMiners(address to, uint256[] ids, uint256[] amounts);

    constructor() ERC1155("https//buzzminer.com/api/token/") {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function initialize(address _owner) external {
        require(!initialized, "initialize: Already initialized!");
        _transferOwnership(_owner);

        _setURI("https//buzzmianer.com/api/token/");
        _setRoleAdmin(ROLE_MINTER, ROLE_MINTER_ADMIN);
        _setupRole(ROLE_MINTER_ADMIN, _owner);
        minerQualities[1] = 10; // CPU
        minerQualities[2] = 100; // GPU
        minerQualities[3] = 1000; // ASIC
        initialized = true;
    }

    function setMinerQuality(uint256 _id, uint256 _quality) external onlyOwner {
        minerQualities[_id] = _quality;
        emit SetMinerQuality(_id, _quality);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _setURI(baseURI_);
        emit SetBaseURI(baseURI_);
    }

    function setMinterAdmin(address minterAdmin) external onlyOwner {
        _setupRole(ROLE_MINTER_ADMIN, minterAdmin);
    }

    function revokeMinterAdmin(address minterAdmin) external onlyOwner {
        _revokeRole(ROLE_MINTER_ADMIN, minterAdmin);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount
    ) external override nonReentrant {
        require(
            hasRole(ROLE_MINTER, msg.sender),
            "BuzzMiner: Caller is not a minter"
        );
        require(id > 0, "BuzzMiner: INVALID_ID.");
        _mint(to, id, amount, "0x0");
        emit MintMiner(to, id, amount);
    }

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external override nonReentrant {
        require(
            hasRole(ROLE_MINTER, msg.sender),
            "BuzzMiner: Caller is not a minter"
        );
        require(
            ids.length == amounts.length,
            "BuzzMiner: INVALID_ARRAY_LENGTH."
        );
        _mintBatch(to, ids, amounts, "0x0");

        emit MintMiners(to, ids, amounts);
    }

    function burn(uint256 _id, uint256 _amount) external {
        require(
            balanceOf(msg.sender, _id) >= _amount,
            "BuzzMiner#burn: Trying to burn more tokens than you own"
        );
        _burn(msg.sender, _id, _amount);
    }

    function burnBatch(
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external nonReentrant {
        for (uint i = 0; i < ids.length; i++) {
            require(
                balanceOf(msg.sender, ids[i]) >= amounts[i],
                "BuzzMiner#burn: Trying to burn more tokens than you own"
            );
        }
        _burnBatch(msg.sender, ids, amounts);
    }

    function minerQuality(
        uint256 _id
    ) external view override returns (uint256) {
        return minerQualities[_id];
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(minerQualities[_id] != 0, "BuzzMiner: INVALID_ID.");
        return string(abi.encodePacked(super.uri(_id), _id.toString()));
    }

    function name() public view virtual returns (string memory) {
        return "Buzz Mining Rigs";
    }

    function symbol() public view virtual returns (string memory) {
        return "BMR";
    }
}
