pragma solidity >=0.5.0;

interface IStaking {
    function incomeRateChanged() external;
    function rewardRateChanged() external;
    function totalSupply() external view returns(uint256);
}