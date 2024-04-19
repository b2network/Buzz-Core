// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Test is ERC721 {
    uint256 private _currentTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC721("TestToken", "TT721") {}

    function mint(address to) external {
        _currentTokenId++;
        _mint(to, _currentTokenId);
    }
}
