// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("ERC", "ERC") {}

    function mint(address _receiver, uint _amount) external {
        _mint(_receiver, _amount);
    }
}
