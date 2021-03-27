pragma solidity 0.6.3;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol';

interface MinterInterface {
    function mint(uint256 amount) external;
}

contract Dex {
    address public admin;
    
    struct Token {
        bytes32 ticker;
        address tokenAddress;
        uint256 price;
    }
    mapping(bytes32 => Token) public tokens;
    bytes32[] public tokenList;
    
    constructor() public {
        admin = msg.sender;
    }
    
    function addToken(bytes32 _ticker, address _tokenAddress, uint256 _pric) onlyAdmin() public {
        if(tokens[_ticker].tokenAddress == address(0)){
            tokenList.push(_ticker);
        }
        tokens[_ticker] = Token(_ticker, _tokenAddress, _pric);
    }
    
    function editPrice(bytes32 _ticker, uint256 _price) onlyAdmin() public {
        tokens[_ticker].price = _price;
    }
    
    function swap(uint256 _amount, bytes32 _currencyA, bytes32 _currencyB) tokenExist(_currencyA) tokenExist(_currencyB) public {
        
        //Transfer _currencyA to this wallet
        IERC20(tokens[_currencyA].tokenAddress).transferFrom(msg.sender,address(this),_amount);
        
        //Calculate amount of _currencyB for mint
        uint256 bAmount = _amount * tokens[_currencyB].price / tokens[_currencyA].price;
        
        //Mint _currencyB  
        MinterInterface(tokens[_currencyB].tokenAddress).mint(bAmount);
        
        //Trasfer _currencyB to sender
        IERC20(tokens[_currencyB].tokenAddress).transfer(msg.sender, bAmount);
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