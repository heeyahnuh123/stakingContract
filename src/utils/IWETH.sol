// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWETH {
    function deposit() external payable; // Function to wrap Ether into WETH

    function withdraw(uint256 amount) external; // Function to unwrap WETH into Ether
}
