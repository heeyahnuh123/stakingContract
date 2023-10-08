// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Heeyahnuh123 is ERC20, Ownable, ERC20Permit {
    constructor(
        address initialOwner
    )
        ERC20("heeyahnuh123", "H123")
        Ownable(initialOwner)
        ERC20Permit("heeyahnuh123")
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
