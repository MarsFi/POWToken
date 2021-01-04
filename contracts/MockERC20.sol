pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";


contract MockERC20 is ERC20, ERC20Detailed {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 supply
    ) public ERC20Detailed(name, symbol, decimals) {
        _mint(msg.sender, supply);
    }
}