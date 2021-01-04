pragma solidity >=0.5.0;

interface IERC20Detail {
    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
}