pragma solidity ^0.8.0;
// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;

interface IBuzzMiningRigs {
    function mint(address to, uint256 id, uint256 amount) external;

    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external;

    function minerQuality(uint256 id) external view returns (uint256);
}
