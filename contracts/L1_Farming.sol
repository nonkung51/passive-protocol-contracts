pragma solidity 0.6.3;
pragma experimental ABIEncoderV2;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol';

struct TokenData {
    bytes32 ticker;
    uint256 mktCap;
    uint256 price;
}

interface TokenDataProviderInterface {
    function requestMktCap() external;
    function getTokenData() external view returns (bytes32 ticker, uint256 mktCap, uint256 price);
}

interface FundManageProvider {
    function increaseFund(bytes32, uint256) external;
    function decreaseFund(bytes32, uint256) external;
    function adjustFund(TokenData[6] calldata) external;
    function updateTokenDatas(TokenData[6] calldata) external;
}

interface DexProvider {
    function updateTokenPrice(TokenData[6] calldata) external;
}

interface MinterInterface {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external; 
}

contract L1_Farm {
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
    
    
    struct TokenDataProvider {
        address providerAddress;
    }
    // Mocking this to be 5
    TokenDataProvider[5] trackToken;
    TokenDataProvider daiTokenTrack;
    
    FundManageProvider fundManager;
    DexProvider dex;
    

    // constructor(address _daiToken, address _passiveToken, uint256 _mintPerBlock) public {
    constructor() public {
        // daiToken = Token(_daiToken);
        // passiveToken = Token(_passiveToken);
        daiToken = Token(0xcac5A73d6A02673A3A29517641789ACBAfa6496d);
        passiveToken = Token(0x1b7Cd6Ee68b5BcEE83C4152A31b0747DC73b4F26);
        owner = msg.sender;
        lastRewardBlock = block.number;
        lastMinting = block.number;
        totalStaking = 0;
        // mintPerBlock = _mintPerBlock;
        mintPerBlock = 10000000000;
        mintingStart = false;
        
        // For contacting to Data Node & fundManger & Mocking DEX
        trackToken[0] = TokenDataProvider(0x47Ce804776Fa3D81f5A16D81826C41E86bf12D92);
        trackToken[1] = TokenDataProvider(0x5E1c3446899fe414f6feC1aB4DdA850Bed24D0b7);
        trackToken[2] = TokenDataProvider(0x44bedf12AffaE0b6A671188CEB8F7B334eec9d59);
        trackToken[3] = TokenDataProvider(0x4eA55208D359F069e90a31290104309C2d0FeD9F);
        trackToken[4] = TokenDataProvider(0xB516b7d0548b029DF6e05b70FFbfF7c75167c8e4);
        
        daiTokenTrack = TokenDataProvider(0x692F4C7C81b6D3E85b98785f127966FE94A7D946);
        
        fundManager = FundManageProvider(0x757736EB252e0393a83fd305F21957C0b1Bc8141);
        dex = DexProvider(0x63b43B56968c8687dbf13f02f59e31FbEe76FCca);
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
        // daiToken.transferFrom(msg.sender, address(this), _amount);
        IERC20(daiToken.tokenAddress).transferFrom(
            msg.sender,
            address(this),
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
    
    /////// below here is serve for Data Oracle
    function updateMktCap() public {
        for(uint8 i = 0; i < 5;i++) {
            TokenDataProviderInterface(trackToken[i].providerAddress).requestMktCap();
        }
    }
    
    function editPoolData(address token0, address token1, address token2, address token3, address token4, address daiToken, address fundManageAddress, address dexAddress) public {
        trackToken[0] = TokenDataProvider(token0);
        trackToken[1] = TokenDataProvider(token1);
        trackToken[2] = TokenDataProvider(token2);
        trackToken[3] = TokenDataProvider(token3);
        trackToken[4] = TokenDataProvider(token4);
        
        daiTokenTrack = TokenDataProvider(daiToken);
        
        fundManager = FundManageProvider(fundManageAddress);
        dex = DexProvider(dexAddress);
    }
    
    // Call this to Mock dex data
    function dexDataUpdate() public {
        // Call to Chainlink to update 
        updateMktCap();
        
        // Pull Token Data
        TokenData[6] memory _tokensData;
         for(uint8 i=0; i < 5;i++) {
            (bytes32 ticker, uint256 mktCap, uint256 price) = TokenDataProviderInterface(trackToken[i].providerAddress).getTokenData();
            _tokensData[i] = (TokenData(ticker, mktCap, price));
        }
        
        // Hard code for DAI
        (bytes32 ticker, uint256 mktCap, uint256 price) = TokenDataProviderInterface(daiTokenTrack.providerAddress).getTokenData();
        _tokensData[5] = TokenData(0xa5e92f3efb6826155f1f728e162af9d7cda33a574a1153b58f03ea01cc37e568, mktCap, price);
        
        // Update DEX Data
        dex.updateTokenPrice(_tokensData);
    }
    
    function tryAdjust() public {
        // Call to Chainlink to update 
        updateMktCap();
        
        // Pull Token Data
        TokenData[6] memory _tokensData;
         for(uint8 i=0; i < 5;i++) {
            (bytes32 ticker, uint256 mktCap, uint256 price) = TokenDataProviderInterface(trackToken[i].providerAddress).getTokenData();
            _tokensData[i] = (TokenData(ticker, mktCap, price));
        }
        
        // Hard code for DAI
        (bytes32 ticker, uint256 mktCap, uint256 price) = TokenDataProviderInterface(daiTokenTrack.providerAddress).getTokenData();
        _tokensData[5] = TokenData(0xa5e92f3efb6826155f1f728e162af9d7cda33a574a1153b58f03ea01cc37e568, mktCap, price);
        
        // Calling Adjust fund
        fundManager.updateTokenDatas(_tokensData);
        // fundManager.adjustFund(_tokensData);
    }
}