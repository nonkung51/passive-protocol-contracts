pragma solidity 0.6.3;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol';

interface MinterInterface {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external; 
}

contract FarmingPool {
    string public name = "Simple Farm";
    address public owner;
    
    struct Token {
        address tokenAddress;
    }
    
    Token public daiToken;
    Token public passiveToken;
    
    uint256 public totalStaking;
    uint256 public mintPerBlock;
    
    bool mintingStart;
    
    address[] public stakers;
    mapping(address => uint) public stakingBalance;
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public isStaking;
    mapping(address => uint256) public lastHarvestedBlock;
    mapping(address => uint256) public _pendingBalance;
    uint256 public lastRewardBlock;
    uint256 public lastMinting;

    constructor(address _daiToken, address _passiveToken, uint256 _mintPerBlock) public {
        daiToken = Token(_daiToken);
        passiveToken = Token(_passiveToken);
        owner = msg.sender;
        lastRewardBlock = block.number;
        lastMinting = block.number;
        totalStaking = 0;
        mintPerBlock = _mintPerBlock;
        mintingStart = false;
    }
    
    function blockNumber() public view returns (uint256) {
        return block.number;
    }
    
    function harvest() public {
        // Mint Passive Token for mintPerBlock * (block.number - lastMinting)
        uint256 mintAmount = pendingBalance(msg.sender);
        MinterInterface(passiveToken.tokenAddress).mint(mintAmount);
        
        // transfer pending amount to msg.sender
        IERC20(passiveToken.tokenAddress).transfer(msg.sender, pendingBalance(msg.sender));
        
        // set lastHarvestedBlock to Current block
        lastMinting = block.number;
        lastHarvestedBlock[msg.sender] = block.number;
        
        updatePool();
        _pendingBalance[msg.sender] = 0;
    }
    
    function pendingBalance(address _address) public view returns (uint256) {
        if (isStaking[_address] && mintingStart) {
            return _pendingBalance[_address] + mintPerBlock * (block.number - lastRewardBlock) * (stakingBalance[_address] / totalStaking);
        } else {
            return 0;
        }
    }
    
    function updatePool() public {
        for (uint i=0; i<stakers.length; i++) {
            address curStaker = stakers[i];
            _pendingBalance[curStaker] = _pendingBalance[curStaker] + mintPerBlock * (block.number - lastRewardBlock) * (stakingBalance[curStaker] / totalStaking);
        }
        lastRewardBlock = block.number;
    }
    
    function calculateLP(uint256 daiAmount) private returns (uint256) {
        // let's Mocking it so TVL = totalStaking ** 2 * 1.05
        // Growing by 5%
        if (mintingStart) {
            // Equation: DAIin * LPtotal / TVL
            // We should using real EQUATION
            // but again we are Mocking this ;-;
            return sqrt(daiAmount);
        }
        
        return sqrt(daiAmount);
    }

    function stakeTokens(uint amount) public {
        // Require amount greater than 0
        require(amount > 0, "amount cannot be 0");

        // Trasnfer Mock Dai tokens to this contract for staking
        IERC20(daiToken.tokenAddress).transferFrom(
            msg.sender,
            address(this), // Maybe use Fund Manager Wallet instead?
            amount
        );
        
        uint256 LP = calculateLP(amount);

        // Update staking balance
        stakingBalance[msg.sender] = stakingBalance[msg.sender] + LP;
        totalStaking += LP;

        // Add user to stakers array *only* if they haven't staked already
        if(!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
        }
        
        if(!mintingStart) {
            mintingStart = true;
            lastRewardBlock = block.number;
        }

        // Update staking status
        isStaking[msg.sender] = true;
        hasStaked[msg.sender] = true;
        
        // Update Pool
        updatePool();
        
        // Force harvest
        harvest();
    }

    // Unstaking Tokens (Withdraw)
    function unstakeTokens() public {
        // Fetch staking balance
        uint balance = stakingBalance[msg.sender];

        // Require amount greater than 0
        require(balance > 0, "staking balance cannot be 0");

        // Transfer Mock Dai tokens to this contract for staking
        // Maybe transfer from Fund Manager Wallet instead?
        IERC20(daiToken.tokenAddress).transfer(msg.sender, balance);

        // Reset staking balance
        stakingBalance[msg.sender] = 0;

        // Update staking status
        isStaking[msg.sender] = false;
        totalStaking -= balance;
        
        // Update Pool
        updatePool();
        
        // Force harvest
        harvest();
    }
    
    // Babylonian Method from https://ethereum.stackexchange.com/questions/2910/can-i-square-root-in-solidity
    function sqrt(uint x) private returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}