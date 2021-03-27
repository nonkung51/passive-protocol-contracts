pragma solidity 0.6.3;
pragma experimental ABIEncoderV2;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol';

interface CoinInterface {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
}
interface SwapInterface {
    function swap(uint256 _amount, bytes32 _currencyA, bytes32 _currencyB) external;
}

contract FundManaging {
    address public admin;
    address public dexAddress;
    
    bytes32[] public tokenList;
    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }
    mapping(bytes32 => Token) public tokens;
    
    struct TokenData{
        bytes32 ticker;
        uint256 mktCap;
        uint256 price;
    }
    mapping(bytes32 => TokenData) public tokenDatas;
    
    constructor(address _dexAddress) public {
        admin = msg.sender;
        dexAddress = _dexAddress;
    }
    
    function changeDexAddress(address _dexAddress) onlyAdmin() public {
        for(uint256 i=0;i<tokenList.length;i++ ){
            IERC20(tokens[tokenList[i]].tokenAddress).approve(dexAddress,0);
            IERC20(tokens[tokenList[i]].tokenAddress).approve(_dexAddress,1e18);
        }
        dexAddress = _dexAddress;
    }
    
    function addToken(bytes32 _ticker, address _tokenAddress) onlyAdmin() public {
        if(tokens[_ticker].tokenAddress == address(0)){
            tokenList.push(_ticker);
        }
        tokens[_ticker] = Token(_ticker, _tokenAddress);
        IERC20(tokens[_ticker].tokenAddress).approve(dexAddress,0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }
    
    function increaseFund(bytes32 _ticker, uint256 _amount) public {
        CoinInterface(tokens[_ticker].tokenAddress).mint(_amount);
    }
    
    function decreaseFund(bytes32 _ticker, uint256 _amount) public {
        CoinInterface(tokens[_ticker].tokenAddress).burn(_amount);
    }
    
    //Stupid Adjusting
    function adjustFund(TokenData[] memory _tokenDatas) public {
        _updateTokenDatas(_tokenDatas);
        
        //Sell all ?Token to DAI and Get totalMktCap in one time loop
        uint256 totalMktCap = 0;
        for(uint256 i=0;i<tokenList.length;i++){
            if(tokenList[i] != keccak256("DAI")){
                _trade(IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this)),tokenList[i],keccak256("DAI"));
                totalMktCap += tokenDatas[tokenList[i]].mktCap;
            }
        }
        
        //Buy each ?Token in fund using DAI
        uint256 totalDAI = IERC20(tokens[keccak256("DAI")].tokenAddress).balanceOf(address(this));
        for(uint256 i=0;i<tokenList.length;i++){
            if(tokenList[i] != keccak256("DAI")){
                _trade((totalDAI*tokenDatas[tokenList[i]].mktCap/totalMktCap),keccak256("DAI"),tokenList[i]);
            }
        }
    }

    function getTotalFundValue(TokenData[] memory _tokenDatas) public returns(uint256){
        _updateTokenDatas(_tokenDatas);
        
        uint256 totalFundValue = 0;
        for(uint256 i=0;i<tokenList.length;i++){
            totalFundValue += IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this))*(tokenDatas[tokenList[i]].price);
        }
        
        return totalFundValue;
    }
    
    function _updateTokenDatas(TokenData[] memory _tokenDatas) private{
        for(uint256 i=0;i<_tokenDatas.length;i++){
            tokenDatas[_tokenDatas[i].ticker] = _tokenDatas[i];
        }
    }
    
    function _trade(uint256 _amount, bytes32 _currencyA, bytes32 _currencyB) tokenExist(_currencyA) tokenExist(_currencyB) private {
        if(IERC20(tokens[_currencyA].tokenAddress).balanceOf(address(this))<=_amount){
            _incAllowanceDex(_currencyA);
        }
        SwapInterface(dexAddress).swap(_amount,_currencyA,_currencyB);
    }
    
    function _incAllowanceDex(bytes32 ticker) private {
        IERC20(tokens[ticker].tokenAddress).approve(dexAddress,0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, 'only admin');
        _;
    }
    
    modifier tokenExist(bytes32 ticker) {
        require(tokens[ticker].tokenAddress != address(0),'this token does not exist');
        _;
    }
}