pragma solidity >=0.5.0;

interface IPOWToken {
    function updateIncomeRate() external;
    function incomeToken() external view returns(uint256);
    function incomeRate() external view returns(uint256);
    function startMiningTime() external view returns (uint256);
    function mint(address to, uint value) external;
    function remainingAmount() external view returns(uint256);
    function rewardToken() external view returns(uint256);
    function stakingRewardRate() external view returns(uint256);
    function lpStakingRewardRate() external view returns(uint256);
    function rewardPeriodFinish() external view returns(uint256);
    function claimIncome(address to, uint256 amount) external;
    function claimReward(address to, uint256 amount) external;
}