pragma solidity >=0.5.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import "./interfaces/IPOWToken.sol";
import "./interfaces/IERC20Detail.sol";
import "./ReentrancyGuard.sol";

contract TokenDistribute is ReentrancyGuard{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool internal initialized;
    address public owner;
    address public paramSetter;
    address public hashRateToken;
    address[] public exchangeTokens;
    uint256[] public exchangeRates;

    mapping (address => bool) public isWhiteListed;

    function initialize(address newOwner, address _paramSetter, address _hashRateToken) public {
        require(!initialized, "Token already initialized");
        require(newOwner != address(0), "new owner is the zero address");
        super.initialize();
        initialized = true;

        owner = newOwner;
        paramSetter = _paramSetter;
        hashRateToken = _hashRateToken;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setParamSetter(address _paramSetter) external onlyOwner {
        require(_paramSetter != address(0), "param setter is the zero address");
        emit ParamSetterChanged(paramSetter, _paramSetter);
        paramSetter = _paramSetter;
    }

    function addWhiteLists (address[] calldata _users) external onlyParamSetter {
        for (uint i=0; i<_users.length; i++){
            address _user = _users[i];
            _addWhiteList(_user);
        }
    }

    function addWhiteList (address _user) external onlyParamSetter {
        _addWhiteList(_user);
    }

    function _addWhiteList (address _user) internal {
        isWhiteListed[_user] = true;
        emit AddedWhiteList(_user);
    }

    function removeWhiteList (address _user) external onlyParamSetter {
        delete isWhiteListed[_user];
        emit  RemovedWhiteList(_user);
    }

    function getWhiteListStatus(address _user) public view returns (bool) {
        return isWhiteListed[_user];
    }

    function addExchangeToken(address _exchangeToken, uint256 _exchangeRate) external onlyParamSetter {
        exchangeTokens.push(_exchangeToken);
        exchangeRates.push(_exchangeRate);
    }

    function updateExchangeRate(uint256 _tokenId, uint256 _exchangeRate) external onlyParamSetter checkTokenId(_tokenId) {
        exchangeRates[_tokenId] = _exchangeRate;
    }

    function remainingAmount() public view returns(uint256) {
        return IPOWToken(hashRateToken).remainingAmount();
    }

    function exchange(uint256 _tokenId, uint256 amount, address to) checkTokenId(_tokenId) external nonReentrant {
        require(amount > 0, "Cannot exchange 0");
        require(amount <= remainingAmount(), "not sufficient supply");
        require(getWhiteListStatus(to), "to is not in whitelist");

        uint256 exchangeRateAmplifier = 1000;
        uint256 hashRateTokenAmplifier;
        uint256 exchangeTokenAmplifier;
        {
            address exchangeToken = exchangeTokens[_tokenId];
            uint256 hashRateTokenDecimal = IERC20Detail(hashRateToken).decimals();
            uint256 exchangeTokenDecimal = IERC20Detail(exchangeToken).decimals();
            hashRateTokenAmplifier = 10**hashRateTokenDecimal;
            exchangeTokenAmplifier = 10**exchangeTokenDecimal;
        }

        uint256 token_amount = amount.mul(exchangeRates[_tokenId]).mul(exchangeTokenAmplifier).div(hashRateTokenAmplifier).div(exchangeRateAmplifier);

        {
            address exchangeToken = exchangeTokens[_tokenId];
            IERC20(exchangeToken).safeTransferFrom(msg.sender, address(this), token_amount);
            IPOWToken(hashRateToken).mint(to, amount);
        }

        emit Exchanged(msg.sender, amount, _tokenId, token_amount);
    }

    function ownerMint(uint256 amount)external onlyOwner {
        IPOWToken(hashRateToken).mint(owner, amount);
    }

    function ownerWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner, _amount);
    }

    modifier checkTokenId(uint256 _tokenId) {
        require(exchangeTokens[_tokenId] != address(0) && exchangeRates[_tokenId] != 0, "wrong _tokenId");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyParamSetter() {
        require(msg.sender == paramSetter, "!param setter");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ParamSetterChanged(address indexed previousSetter, address indexed newSetter);
    event Exchanged(address indexed user, uint256 amount, uint256 tokenId, uint256 token_amount);
    event AddedWhiteList(address _user);
    event RemovedWhiteList(address _user);
}