pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BuzzTokenClaim is Ownable, ReentrancyGuard {
    bool private initialized;

    // BTC -> merkleRoot; ETH-> merkleRoot; BNB -> merkleRoot
    mapping(address => bytes32) public tokenMerkleRoot;
    mapping(address => mapping(address => bool)) public tokenUserClaimed;
    mapping(address => bool) public blacklist;
    address public merkleManager;

    mapping(address => uint256) public allClaimedAmount;

    event EventSetBlacklist(address indexed _user, bool _status);
    event EventClaim(address indexed token, address indexed to, uint256 amount);
    event EventSetMerkleRoot(address indexed token, bytes32 merkleRoot);
    event EventClaims(
        address indexed to,
        address[] indexed tokens,
        uint256[] amounts
    );
    event EmergencyWithdraw(address account, uint256 banlance);
    event EventSetManager(address manager);

    function initialize(address _owner, address manager) external {
        require(!initialized, "initialize: Already initialized!");

        _transferOwnership(_owner);
        merkleManager = manager;
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

    function setMerkleRootManager(address manager) external onlyOwner {
        require(
            merkleManager != manager,
            "setMerkleRootManager: manager has been set"
        );
        merkleManager = manager;
        emit EventSetManager(manager);
    }

    function setMerkleRoot(address _token, bytes32 _merkleRoot) external {
        require(
            merkleManager == msg.sender,
            "setMerkleRoot: only merkleManager can set merkleRoot"
        );
        tokenMerkleRoot[_token] = _merkleRoot;
        emit EventSetMerkleRoot(_token, _merkleRoot);
    }

    function claim(
        address _token,
        uint256 _addressId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external nonReentrant {
        address _to = msg.sender;
        require(!blacklist[_to], "claim: user is in the blacklist");
        require(
            !tokenUserClaimed[_token][_to],
            "claim: user has already claimed"
        );
        bytes32 _merkleRoot = tokenMerkleRoot[_token];
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(_addressId, _to, _amount));
        require(
            MerkleProof.verify(_merkleProof, _merkleRoot, node),
            "claim: Invalid proof."
        );
        tokenUserClaimed[_token][_to] = true;

        if (_token == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_token).transfer(_to, _amount);
        }

        allClaimedAmount[_token] += _amount;
        emit EventClaim(_token, _to, _amount);
    }

    function claims(
        address[] calldata _tokens,
        uint256[] calldata _addressIds,
        uint256[] calldata _amounts,
        bytes32[][] calldata _merkleProofs
    ) external nonReentrant {
        address _to = msg.sender;
        require(!blacklist[_to], "claim: user is in the blacklist");
        for (uint256 i = 0; i < _tokens.length; i++) {
            address _token = _tokens[i];
            uint256 _amount = _amounts[i];
            uint256 _addressId = _addressIds[i];
            bytes32[] calldata _merkleProof = _merkleProofs[i];
            require(
                !tokenUserClaimed[_token][_to],
                "claim: user has already claimed"
            );
            bytes32 _merkleRoot = tokenMerkleRoot[_token];
            // Verify the merkle proof.
            bytes32 node = keccak256(
                abi.encodePacked(_addressId, _to, _amount)
            );
            require(
                MerkleProof.verify(_merkleProof, _merkleRoot, node),
                "claim: Invalid proof."
            );
            tokenUserClaimed[_token][_to] = true;
            if (_token == address(0)) {
                payable(_to).transfer(_amount);
            } else {
                IERC20(_token).transfer(_to, _amount);
            }
            allClaimedAmount[_token] += _amount;
        }
        emit EventClaims(_to, _tokens, _amounts);
    }

    function emergencyWithdraw(
        address token,
        uint256 amount,
        address withdrawAddr
    ) external onlyOwner {
        if (token == address(0)) {
            payable(withdrawAddr).transfer(amount);
        } else {
            IERC20(token).transfer(withdrawAddr, amount);
        }
        emit EmergencyWithdraw(withdrawAddr, amount);
    }

    receive() external payable {}
}
