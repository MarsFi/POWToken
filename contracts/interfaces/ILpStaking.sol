pragma solidity >=0.5.0;

interface ILpStaking {
    function lpIncomeRateChanged() external;
    function lpRewardRateChanged() external;
}