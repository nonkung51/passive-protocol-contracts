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
    
    mapping(bytes32 => uint256) public holdingBalanceValue;
    
    constructor(address _dexAddress) public {
        admin = msg.sender;
        dexAddress = _dexAddress;
    }
    
    function changeDexAddress(address _dexAddress) onlyAdmin() public  {
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
        IERC20(tokens[_ticker].tokenAddress).approve(dexAddress,uint256(-1));
    }
    
    function increaseFund(uint256 _amount) public {
        CoinInterface(tokens[keccak256("DAI")].tokenAddress).mint(_amount);
    }
    
    function decreaseFund(uint256 _amount,TokenData[6] calldata _tokenDatas) external {
        TokenData[6] memory temp_tokenDatas = _tokenDatas;
        for(uint256 i=0;i<_tokenDatas.length;i++){
            tokenDatas[temp_tokenDatas[i].ticker] = temp_tokenDatas[i];
        }
        
        //Sell all ?Token to DAI and Get totalMktCap in one time loop
        uint256 totalMktCap = 0;
        for(uint256 i=0;i<tokenList.length;i++){
            if(tokenList[i] != keccak256("DAI")){
                _trade(IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this)),tokenList[i],keccak256("DAI"));
                totalMktCap += tokenDatas[tokenList[i]].mktCap;
            }
        }
        
        CoinInterface(tokens[keccak256("DAI")].tokenAddress).burn(_amount);
        
        uint256 totalDAI = IERC20(tokens[keccak256("DAI")].tokenAddress).balanceOf(address(this));
        
        // //Hold 10% for Liqudate
        // totalDAI = totalDAI - (totalDAI/10);
        
        //Buy each ?Token in fund using DAI
        for(uint256 i=0;i<tokenList.length;i++){
            if(tokenList[i] != keccak256("DAI")){
                _trade((totalDAI*tokenDatas[tokenList[i]].mktCap/totalMktCap),keccak256("DAI"),tokenList[i]);
            }
        }
    }
    
    //Stupid Adjusting
    function adjustFund(TokenData[6] calldata _tokenDatas) external {
        TokenData[6] memory temp_tokenDatas = _tokenDatas;
        for(uint256 i=0;i<_tokenDatas.length;i++){
            tokenDatas[temp_tokenDatas[i].ticker] = temp_tokenDatas[i];
        }
        
        //Sell all ?Token to DAI and Get totalMktCap in one time loop
        uint256 totalMktCap = 0;
        for(uint256 i=0;i<tokenList.length;i++){
            if(tokenList[i] != keccak256("DAI")){
                _trade(IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this)),tokenList[i],keccak256("DAI"));
                totalMktCap += tokenDatas[tokenList[i]].mktCap;
            }
        }
        
        uint256 totalDAI = IERC20(tokens[keccak256("DAI")].tokenAddress).balanceOf(address(this));
        
        //Buy each ?Token in fund using DAI
        for(uint256 i=0;i<tokenList.length;i++){
            if(tokenList[i] != keccak256("DAI")){
                _trade((totalDAI*tokenDatas[tokenList[i]].mktCap/totalMktCap),keccak256("DAI"),tokenList[i]);
            }
        }
    }
    
    //Smart Adjusting
    // function adjustFund(TokenData[6] calldata _tokenDatas) external{
    //     TokenData[6] memory temp_tokenDatas = _tokenDatas;
    //     for(uint256 i=0;i<_tokenDatas.length;i++){
    //         tokenDatas[temp_tokenDatas[i].ticker] = temp_tokenDatas[i];
    //     }
    //     _adjustFund();
    // }
    
    // function _adjustFund() private {
    //     //totalFundValue not include DAI (DAI is our Liqudity)
    //     uint256 totalFundValue = getTotalFundValue();
        
    //     //totalFundMktCap not include DAI (DAI is our Liqudity)
    //     uint256 totalFundMktCap = 0;
    //     for(uint256 i=0;i<tokenList.length;i++){
    //         totalFundMktCap += tokenDatas[tokenList[i]].mktCap;
    //     }
    //     totalFundMktCap -= tokenDatas[keccak256("DAI")].mktCap;
        
    //     //Sell ?Token to get DAI            
    //     for(uint256 i=0;i<tokenList.length;i++){
    //         uint256 valueNew =((tokenDatas[tokenList[i]].mktCap/totalFundMktCap)*totalFundValue)/tokenDatas[tokenList[i]].price;
    //         uint256 valueNew_RealHolding = valueNew-(totalFundValue);
            
    //         /* Data may be lost uint256->int256 ..Becareful! */
    //         int256 adjustAmount = int256((valueNew_RealHolding/tokenDatas[tokenList[i]].price) - (IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this))));
    //         if(adjustAmount<0){
    //             _trade(uint256(-1*adjustAmount),tokenList[i],keccak256("DAI"));
    //         }
    //     }
        
    //     Buy ?Token using DAI 
    //     for(uint256 i=0;i<tokenList.length;i++){
    //         uint256 valueNew =((tokenDatas[tokenList[i]].mktCap/totalFundMktCap)*totalFundValue)/tokenDatas[tokenList[i]].price;
    //         uint256 valueNew_RealHolding = valueNew-(totalFundValue);
            
    //         /* Data may be lost uint256->int256 ..Becareful! */
    //         int256 adjustAmount = int256((valueNew_RealHolding/tokenDatas[tokenList[i]].price) - (IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this))));
    //         if(adjustAmount>0){
    //             _trade(uint256(adjustAmount),keccak256("DAI"),tokenList[i]);
    //         }
    //     }
    // }

    //Get TotalFundValue (Not Include DAI)
    /* you should call updateTokenDatas(TokenData[6] calldata _tokenDatas) before do this!*/
    function getTotalFundValue() public view returns(uint256){
        return getTotalHoldingValue() - (IERC20(tokens[keccak256("DAI")].tokenAddress).balanceOf(address(this))*(tokenDatas[keccak256("DAI")].price))/(1e36);
    }
    
    //Get TotalHoldingValue (Include DAI)
    /* you should call updateTokenDatas(TokenData[6] calldata _tokenDatas) before do this!*/
    function getTotalHoldingValue() public view returns(uint256){
        uint256 totalFundValue = 0;
        for(uint256 i=0;i<tokenList.length;i++){
            totalFundValue += (IERC20(tokens[tokenList[i]].tokenAddress).balanceOf(address(this))/1e18)*(tokenDatas[tokenList[i]].price/1e18);
        }
        
        return totalFundValue;
    }
    
    function updateTokenDatas(TokenData[6] calldata _tokenDatas) external{
        TokenData[6] memory temp_tokenDatas = _tokenDatas;
        for(uint256 i=0;i<_tokenDatas.length;i++){
            tokenDatas[temp_tokenDatas[i].ticker] = temp_tokenDatas[i];
        }
    }
    
    function _trade(uint256 _amount, bytes32 _currencyA, bytes32 _currencyB) tokenExist(_currencyA) tokenExist(_currencyB) private {
        if(IERC20(tokens[_currencyA].tokenAddress).balanceOf(address(this))<=_amount){
            _incAllowanceDex(_currencyA);
        }
        SwapInterface(dexAddress).swap(_amount,_currencyA,_currencyB);
    }
    
    function _incAllowanceDex(bytes32 ticker) private{
        IERC20(tokens[ticker].tokenAddress).approve(dexAddress,uint256(-1));
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