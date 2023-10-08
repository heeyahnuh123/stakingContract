// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReceiptToken {
    function mint(address to, uint256 amount) external;
    // Add any other functions from your token contract that you need here.
}
