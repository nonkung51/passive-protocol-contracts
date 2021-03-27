pragma experimental ABIEncoderV2;
pragma solidity 0.6.3;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/ChainlinkClient.sol";

contract TokenDataProvider is ChainlinkClient{
    uint256 public mktCap;
    
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    

    AggregatorV3Interface internal priceFeed;
    
    struct TokenData {
        bytes32 ticker;
        uint256 mktCap;
        uint256 price;
    }

    /**
     * Network: Kovan
     * Aggregator: ETH/USD
     * Address: 0x9326BFA02ADD2366b30bacB125260Af641031331
     */
    constructor() public {
        priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

    /**
     * Returns the latest price
     */
    function getThePrice() public view returns (uint256) {
        (, int price, , ,) = priceFeed.latestRoundData();
        uint8 decimals = priceFeed.decimals();
        uint256 convertedPrice = uint256(price) * (uint256(10) ** (18 - uint256(decimals)));
        return convertedPrice;
    }
    
    /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 1000000000000000000 (to remove decimal places from data).
     */
    function requestMktCap() public returns (bytes32 requestId) 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD");
        
        // Get Market Cap of the coin
        request.add("path", "RAW.ETH.USD.MKTCAP");
        
        // Multiply the result by 1000000000000000000 to remove decimals
        int timesAmount = 10**18;
        request.addInt("times", timesAmount);
        
        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _mktCap) public recordChainlinkFulfillment(_requestId)
    {
        mktCap = _mktCap;
    }
    
    /**
     * Withdraw LINK from this contract
     * 
     * NOTE: DO NOT USE THIS IN PRODUCTION AS IT CAN BE CALLED BY ANY ADDRESS.
     * THIS IS PURELY FOR EXAMPLE PURPOSES ONLY.
     */
    function withdrawLink() external {
        LinkTokenInterface linkToken = LinkTokenInterface(chainlinkTokenAddress());
        require(linkToken.transfer(msg.sender, linkToken.balanceOf(address(this))), "Unable to transfer");
    }
    
    function getTokenData() public view returns (TokenData memory) {
        uint256 price = getThePrice();
        
        return TokenData(0x5553540000000000000000000000000000000000000000000000000000000000, price, mktCap);
    }
}

