// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

contract NFTAuction {
    address public owner;
    address public nftAddress;
    uint256 public tokenId;

    address public highestBidder;
    uint256 public highestBid;
    uint256 public auctionEndTime;
    bool public started;
    bool public ended;

    mapping(address => uint256) public pendingReturns;

    event AuctionStarted(uint256 endTime);
    event BidPlaced(address bidder, uint256 amount);
    event Withdrawn(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this.");
        _;
    }

    constructor(address _nftAddress, uint256 _tokenId) {
        owner = msg.sender;
        nftAddress = _nftAddress;
        tokenId = _tokenId;
    }

    function startAuction(uint256 durationInSeconds) external onlyOwner {
        require(!started, "Auction already started.");
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
        started = true;
        auctionEndTime = block.timestamp + durationInSeconds;
        emit AuctionStarted(auctionEndTime);
    }

    function bid() external payable {
        require(started, "Auction not started.");
        require(block.timestamp < auctionEndTime, "Auction already ended.");
        require(msg.value > highestBid, "Bid too low.");

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit BidPlaced(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No amount to withdraw.");

        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function endAuction() external onlyOwner {
        require(started, "Auction not started.");
        require(block.timestamp >= auctionEndTime, "Auction not yet ended.");
        require(!ended, "Auction already ended.");

        ended = true;

        if (highestBidder != address(0)) {
            IERC721(nftAddress).transferFrom(address(this), highestBidder, tokenId);
            payable(owner).transfer(highestBid);
        } else {
            // No bids, return NFT
            IERC721(nftAddress).transferFrom(address(this), owner, tokenId);
        }

        emit AuctionEnded(highestBidder, highestBid);
    }
}
