pragma solidity >=0.5.0;

interface IBTCParam {
    function btcPrice() external view returns (uint256);
    function btcIncomePerTPerSecInWei() external view returns(uint256);
}