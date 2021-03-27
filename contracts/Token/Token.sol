pragma solidity 0.6.3;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/ERC20.sol";

// Some part of the code commented to make it easier to debug :-D
contract Token is ERC20{
    // address minter;
    
    constructor() ERC20("Passive Token","PST") public {
        // minter = msg.sender;
    }
    
    function mint(uint256 amount) public {
        // require(msg.sender == minter);
        _mint(msg.sender,amount);
    }
    
    function burn(uint256 amount) public {
        // require(msg.sender == minter);
        _burn(msg.sender,amount);
    }
}