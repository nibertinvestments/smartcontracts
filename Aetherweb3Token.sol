// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Aetherweb3Token is ERC20 {
    constructor(uint256 initialSupply) ERC20("Aetherweb3", "AETH") {
        _mint(msg.sender, initialSupply);
    }
}
