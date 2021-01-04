pragma solidity >=0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import './interfaces/IPOWToken.sol';
import "./uniswapv2/UniswapV2OracleLibrary.sol";

contract BTCParamV2 {
    using SafeMath for uint256;

    bool internal initialized;
    address public owner;
    address public paramSetter;

    uint256 public btcBlockRewardInWei;
    uint256 public btcNetDiff;
    uint256 public btcTxFeeRewardPerTPerSecInWei;

    address public uniPairAddress;
    bool public usePrice0;
    uint32 public lastPriceUpdateTime;
    uint256 public lastCumulativePrice;
    uint256 public lastAveragePrice;

    address[] public paramListeners;

    function initialize(address newOwner, address _paramSetter, uint256 _btcNetDiff, uint256 _btcBlockRewardInWei, address _uniPairAddress, bool _usePrice0) public {
        require(!initialized, "already initialized");
        require(newOwner != address(0), "new owner is the zero address");
        initialized = true;
        owner = newOwner;
        paramSetter= _paramSetter;
        btcBlockRewardInWei = _btcBlockRewardInWei;
        btcNetDiff = _btcNetDiff;

        uniPairAddress = _uniPairAddress;
        usePrice0 = _usePrice0;
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(_uniPairAddress);

        lastPriceUpdateTime = currentBlockTimestamp;
        lastCumulativePrice = _usePrice0?price0Cumulative:price1Cumulative;
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

    function setBtcNetDiff(uint256 _btcNetDiff) external onlyParamSetter {
        btcNetDiff = _btcNetDiff;
        notifyListeners();
    }

    function setBtcBlockReward(uint256 _btcBlockRewardInWei) external onlyParamSetter {
        btcBlockRewardInWei = _btcBlockRewardInWei;
        notifyListeners();
    }

    function updateBtcPrice() external onlyParamSetter {
        _updateBtcPrice();
        notifyListeners();
    }

    function _updateBtcPrice() internal {
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 currentBlockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(uniPairAddress);
        uint256 currentPrice = usePrice0?price0Cumulative:price1Cumulative;

        uint256 timeElapsed = currentBlockTimestamp - lastPriceUpdateTime; // overflow is desired
        if (timeElapsed > 0) {
            lastAveragePrice = currentPrice.sub(lastCumulativePrice).div(timeElapsed);
            lastPriceUpdateTime = currentBlockTimestamp;
            lastCumulativePrice = currentPrice;
        }
    }

    function setBtcTxFeeRewardRate(uint256 _btcTxFeeRewardPerTPerSecInWei) external onlyParamSetter {
        btcTxFeeRewardPerTPerSecInWei = _btcTxFeeRewardPerTPerSecInWei;
        notifyListeners();
    }

    function setBtcTxFeeRewardRateAndUpdateBtcPrice(uint256 _btcTxFeeRewardPerTPerSecInWei) external onlyParamSetter{
        btcTxFeeRewardPerTPerSecInWei = _btcTxFeeRewardPerTPerSecInWei;
        _updateBtcPrice();
        notifyListeners();
    }

    function addListener(address _listener) external onlyParamSetter {
        for (uint i=0; i<paramListeners.length; i++){
            address listener = paramListeners[i];
            require(listener != _listener, 'listener already added.');
        }
        paramListeners.push(_listener);
    }

    function removeListener(address _listener) external onlyParamSetter returns(bool ){
        for (uint i=0; i<paramListeners.length; i++){
            address listener = paramListeners[i];
            if (listener == _listener) {
                delete paramListeners[i];
                return true;
            }
        }
        return false;
    }

    function notifyListeners() internal {
        for (uint i=0; i<paramListeners.length; i++){
            address listener = paramListeners[i];
            if (listener != address(0)) {
                IPOWToken(listener).updateIncomeRate();
            }
        }
    }

    function btcIncomePerTPerSecInWei() external view returns(uint256){
        uint256 oneTHash = 10 ** 12;
        uint256 baseDiff = 2 ** 32;
        uint256 blockRewardRate = oneTHash.mul(btcBlockRewardInWei).div(baseDiff).div(btcNetDiff);
        return blockRewardRate.add(btcTxFeeRewardPerTPerSecInWei);
    }

    function btcPrice() external view returns (uint256) {
        return lastAveragePrice.mul(100).div(2**112);
    }

    /* ========== MODIFIERS ========== */
    modifier onlyOwner() {
        require(msg.sender == owner, "!owner");
        _;
    }

    modifier onlyParamSetter() {
        require(msg.sender == paramSetter, "!paramSetter");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ParamSetterChanged(address indexed previousSetter, address indexed newSetter);
}