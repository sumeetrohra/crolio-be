// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract fBTC is ERC20, ERC20Permit {
    constructor() ERC20("fakeBTC", "fBTC") ERC20Permit("fakeBTC") {}

    function mint() external {
        _mint(msg.sender, 1000000000000000000);
    }
}
