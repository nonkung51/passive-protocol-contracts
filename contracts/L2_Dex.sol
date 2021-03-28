pragma solidity 0.6.3;
pragma experimental ABIEncoderV2;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol';

interface MinterInterface {
    function mint(uint256 amount) external;
}

contract Dex {
    address public admin;
    address public dataFeederAddress;
    
    bytes32[] public tokenList;
    struct Token {
        bytes32 ticker;
        address tokenAddress;
        uint256 price;
    }
    mapping(bytes32 => Token) public tokens;
    
    struct TokenData{
        bytes32 ticker;
        uint256 mktCap;
        uint256 price;
    }

    constructor(address _dataFeederAddress) public {
        admin = msg.sender;
        dataFeederAddress = _dataFeederAddress;
    }
    
    function changeDataFeederAddress(address _dataFeederAddress) onlyAdmin() public {
        dataFeederAddress = _dataFeederAddress;
    }
    
    function addToken(bytes32 _ticker, address _tokenAddress, uint256 _price) onlyAdmin() public {
        if(tokens[_ticker].tokenAddress == address(0)){
            tokenList.push(_ticker);
        }
        tokens[_ticker] = Token(_ticker, _tokenAddress, _price);
    }
    
    function updateTokenPrice(TokenData[6] calldata _tokenDatas) onlyDataFeeder() external{
        for(uint256 i=0;i<_tokenDatas.length;i++){
            tokens[_tokenDatas[i].ticker].price = _tokenDatas[i].price;
        }
    }
    
    function swap(uint256 _amount, bytes32 _currencyA, bytes32 _currencyB) tokenExist(_currencyA) tokenExist(_currencyB) public {
        
        //Transfer _currencyA to this wallet
        IERC20(tokens[_currencyA].tokenAddress).transferFrom(msg.sender,address(this),_amount);
        
        //Calculate amount of _currencyB for mint
        uint256 bAmount = _amount * tokens[_currencyA].price / tokens[_currencyB].price;
        
        //Mint _currencyB  
        MinterInterface(tokens[_currencyB].tokenAddress).mint(bAmount);
        
        //Trasfer _currencyB to sender
        IERC20(tokens[_currencyB].tokenAddress).transfer(msg.sender, bAmount);
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, 'only admin');
        _;
    }
    
    modifier onlyDataFeeder() {
        require(msg.sender == dataFeederAddress, 'only dataFedder');
        _;
    }
    
    modifier tokenExist(bytes32 ticker) {
        require(tokens[ticker].tokenAddress != address(0),'this token does not exist');
        _;
    }
}