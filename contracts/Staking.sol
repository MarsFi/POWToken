pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ReentrancyGuard.sol";
import './interfaces/IPOWToken.sol';
import './interfaces/IPOWERC20.sol';
import './interfaces/ILpStaking.sol';

contract Staking is ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool internal initialized;
    address public owner;
    address public lpStaking;
    bool public emergencyStop;
    address public hashRateToken;

    uint256 public incomeLastUpdateTime;
    uint256 public incomePerTokenStored;
    mapping(address => uint256) public userIncomePerTokenPaid;
    mapping(address => uint256) public incomes;
    mapping(address => uint256) public accumulatedIncomes;

    uint256 public rewardLastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    function initialize(address newOwner, address _hashRateToken, address _lpStaking) public {
        require(!initialized, "already initialized");
        require(newOwner != address(0), "new owner is the zero address");
        super.initialize();
        initialized = true;
        owner = newOwner;
        hashRateToken = _hashRateToken;
        lpStaking = _lpStaking;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setEmergencyStop(bool _emergencyStop) external onlyOwner {
        emergencyStop = _emergencyStop;
    }

    function weiToSatoshi(uint256 amount) public pure returns (uint256) {
        return amount.div(10**10);
    }

    function stakeWithPermit(uint256 amount, uint deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant updateIncome(msg.sender) updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        notifyLpStakingUpdateIncome();

        balances[msg.sender] = balances[msg.sender].add(amount);
        totalSupply = totalSupply.add(amount);

        // permit
        IPOWERC20(hashRateToken).permit(msg.sender, address(this), amount, deadline, v, r, s);
        IERC20(hashRateToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function stake(uint256 amount) external nonReentrant updateIncome(msg.sender) updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        notifyLpStakingUpdateIncome();

        balances[msg.sender] = balances[msg.sender].add(amount);
        totalSupply = totalSupply.add(amount);
        IERC20(hashRateToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateIncome(msg.sender) updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        notifyLpStakingUpdateIncome();

        totalSupply = totalSupply.sub(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        IERC20(hashRateToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getIncome();
        getReward();
    }

    function incomeRateChanged() external updateIncome(address(0)) {

    }

    function getCurIncomeRate() public view returns (uint256) {
        uint startMiningTime = IPOWToken(hashRateToken).startMiningTime();
        //not start mining yet.
        if (block.timestamp <= startMiningTime) {
            return 0;
        }

        uint256 incomeRate = IPOWToken(hashRateToken).incomeRate();
        return incomeRate;
    }

    function incomePerToken() public view returns (uint256) {
        uint startMiningTime = IPOWToken(hashRateToken).startMiningTime();
        //not start mining yet.
        if (block.timestamp <= startMiningTime) {
            return 0;
        }

        uint256 _incomeLastUpdateTime = incomeLastUpdateTime;
        if (_incomeLastUpdateTime == 0) {
            _incomeLastUpdateTime = startMiningTime;
        }

        uint256 incomeRate = getCurIncomeRate();
        uint256 normalIncome = block.timestamp.sub(_incomeLastUpdateTime).mul(incomeRate);
        return incomePerTokenStored.add(normalIncome);
    }

    function incomeEarned(address account) external view returns (uint256) {
        uint256 income = _incomeEarned(account);
        return weiToSatoshi(income);
    }

    function _incomeEarned(address account) internal view returns (uint256) {
        return balances[account].mul(incomePerToken().sub(userIncomePerTokenPaid[account])).div(1e18).add(incomes[account]);
    }

    function getUserAccumulatedWithdrawIncome(address account) public view returns (uint256) {
        uint256 amount = accumulatedIncomes[account];
        return weiToSatoshi(amount);
    }

    function getIncome() public nonReentrant updateIncome(msg.sender) nonEmergencyStop {
        uint256 income = incomes[msg.sender];
        if (income > 0) {
            accumulatedIncomes[msg.sender] = accumulatedIncomes[msg.sender].add(income);
            incomes[msg.sender] = 0;
            uint256 amount = weiToSatoshi(income);
            IPOWToken(hashRateToken).claimIncome(msg.sender, amount);
            emit IncomePaid(msg.sender, income);
        }
    }

    function notifyLpStakingUpdateIncome() internal {
        if (lpStaking != address(0)) {
            ILpStaking(lpStaking).lpIncomeRateChanged();
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 periodFinish = IPOWToken(hashRateToken).rewardPeriodFinish();
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardRateChanged() external updateReward(address(0)) {
        rewardLastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        uint256 rewardRate = IPOWToken(hashRateToken).stakingRewardRate();
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(rewardLastUpdateTime).mul(rewardRate).mul(1e18).div(totalSupply)
        );
    }

    function rewardEarned(address account) public view returns (uint256) {
        return balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getReward() public nonReentrant updateReward(msg.sender) nonEmergencyStop {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IPOWToken(hashRateToken).claimReward(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) external onlyOwner {
        require(_token != hashRateToken, 'hashRateToken cannot transfer.');
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    /* ========== MODIFIERS ========== */

    modifier updateIncome(address account)  {
        uint startMiningTime = IPOWToken(hashRateToken).startMiningTime();
        if (block.timestamp > startMiningTime) {
            incomePerTokenStored = incomePerToken();
            incomeLastUpdateTime = block.timestamp;
            if (account != address(0)) {
                incomes[account] = _incomeEarned(account);
                userIncomePerTokenPaid[account] = incomePerTokenStored;
            }
        }
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        rewardLastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = rewardEarned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier nonEmergencyStop() {
        require(emergencyStop == false, "emergency stop");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    /* ========== EVENTS ========== */

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ParamSetterChanged(address indexed previousSetter, address indexed newSetter);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event IncomePaid(address indexed user, uint256 income);
    event RewardPaid(address indexed user, uint256 reward);
}