pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../library/ECDSA.sol";
import "../library/EIP712.sol";
import "../interface/IBuzzMiningRigs.sol";

contract BuzzMinerFactory is EIP712, Ownable, ReentrancyGuard {
    bool private initialized;

    IBuzzMiningRigs public minerNFT;

    bytes32 public merkleRoot;
    address public signer;
    address public operator;

    // user id claimNum
    mapping(address => mapping(uint256 => uint256)) public userClaimed;
    mapping(uint256 => uint256) public allIDNum;
    mapping(address => bool) public blacklist;
    uint256 public allNum;

    event EventClaim(address _mintTo, uint256 _id, uint256 _mintNum);
    event EventClaims(address _mintTo, uint256[] _id, uint256[] _mintNum);
    event EventSetBlacklist(address _user, bool _status);
    event EventSetSigner(address _signer);
    event EventSetOperator(address _operator);

    function initialize(
        address _owner,
        address _signer,
        address _operator,
        IBuzzMiningRigs _minerNFT,
        bytes32 _merkleRoot
    ) external {
        require(!initialized, "initialize: Already initialized!");
        eip712Initialize("BuzzMiner", "1.0.0");
        _transferOwnership(_owner);

        signer = _signer;
        operator = _operator;
        minerNFT = _minerNFT;
        merkleRoot = _merkleRoot;
        initialized = true;
    }

    function setBlacklist(address _user, bool _status) external onlyOwner {
        require(
            blacklist[_user] != _status,
            "setBlacklist: status is the same as the current status"
        );
        blacklist[_user] = _status;
        emit EventSetBlacklist(_user, _status);
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
        emit EventSetSigner(_signer);
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit EventSetOperator(_operator);
    }

    function claimHash(
        address _to,
        uint256 _id,
        uint256 _num
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "ClaimMiner(address to,uint256 id,uint256 num)"
                        ),
                        _to,
                        _id,
                        _num
                    )
                )
            );
    }

    function verifySignature(
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        return ECDSA.recover(hash, signature) == signer;
    }

    function updateMerkleRoot(bytes32 _merkleRoot) external {
        require(
            msg.sender == operator,
            "updateMerkleRoot: caller is not the operator"
        );
        merkleRoot = _merkleRoot;
    }

    function claim(
        uint256 _id,
        uint256 _num,
        uint256 addressId,
        bytes32[] memory merkleProof,
        bytes memory _signature
    ) external nonReentrant {
        address sender = msg.sender;
        require(!blacklist[sender], "claim: user in blacklist");
        require(_id > 0 && _id < 4, "claim: _id must be [1,2,3]");
        require(_num > 0, "claim: _num must be greater than 0");
        require(userClaimed[sender][_id] < _num, "all claim");

        bytes32 node = keccak256(abi.encodePacked(addressId, sender));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "claim: Invalid merkleProof"
        );

        require(
            verifySignature(claimHash(sender, _id, _num), _signature),
            "claim:Invalid signature"
        );

        uint256 canClaimNum = _num - userClaimed[sender][_id];
        require(canClaimNum > 0, "claim: canClaimNum must be greater than 0");
        minerNFT.mint(sender, _id, canClaimNum);
        userClaimed[sender][_id] = _num;
        allIDNum[_id] += canClaimNum;
        allNum += canClaimNum;

        emit EventClaim(sender, _id, canClaimNum);
    }

    function claims(
        uint256[] calldata _ids,
        uint256[] calldata _nums,
        uint256 addressId,
        bytes32[] memory merkleProof,
        bytes[] memory _signatures
    ) external nonReentrant {
        address sender = msg.sender;
        require(!blacklist[sender], "claim: user in blacklist");
        require(
            _ids.length == _nums.length,
            "claims: _ids array length must be equal to _nums array length"
        );
        require(
            _ids.length == _nums.length,
            "claims: _ids array length must be equal to _nums array length"
        );
        require(
            _ids.length == _signatures.length,
            "claim: _ids array length must be equal to _signatures array length"
        );

        bytes32 node = keccak256(abi.encodePacked(addressId, sender));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "claim: Invalid merkleProof"
        );
        uint256[] memory claimNums = new uint256[](_ids.length);
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            uint256 _num = _nums[i];
            bytes memory _signature = _signatures[i];
            require(_id > 0 && _id < 4, "claim: _id must be [1,2,3]");
            require(_num > 0, "claim: _num must be greater than 0");
            require(userClaimed[sender][_id] < _num, "all claim");
            require(
                verifySignature(claimHash(sender, _id, _num), _signature),
                "Invalid signature"
            );

            uint256 canClaimNum = _num - userClaimed[sender][_id];
            require(
                canClaimNum > 0,
                "claims: canClaimNum must be greater than 0"
            );
            minerNFT.mint(sender, _id, canClaimNum);
            userClaimed[sender][_id] = _num;
            allIDNum[_id] += canClaimNum;
            allNum += canClaimNum;
            claimNums[i] = canClaimNum;
        }
        emit EventClaims(sender, _ids, claimNums);
    }
}
