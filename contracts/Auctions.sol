pragma solidity ^0.4.2;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "installed_contracts/oraclize-api/contracts/usingOraclize.sol";
import "./CToken.sol";

contract Auctions is usingOraclize, Ownable {
    uint256[] auctionIds;
    address ctoken;

    struct AuctionData {
        address owner;

        bool isOpen;

        uint256 duration;
        uint256 maxBid;
        uint256 horse;

        address maxBidder;
        address[] bidders;
        // Maps each address on this auction to a bid.
        mapping(address => uint256) bids;
        mapping(address => bool) exists;
    }

    mapping(uint256 => AuctionData) auctions;

    event AuctionCreated(uint256 _auctionId);
    event Bid(address _bidder, uint256 _amount);
    event Withdraw(address _user, uint256 _payout);

    constructor(address _ctoken) public {
        OAR = OraclizeAddrResolverI(0xFC0dF90FC691d442D3c1304BE5ba165cFd554Cb8);
        ctoken = _ctoken;
        owner = msg.sender;
    }

    function createAuction(uint256 _duration, uint256 _horseId) public payable {
        // We ensure that the value sent can cover the Query price for later usage.
        require(msg.value >= oraclize_getPrice("URL"));
        require(msg.sender == CToken(ctoken).ownerOfToken(_horseId));
        require(CToken(ctoken).isTokenApproved(this, _horseId));

        uint256 auctionId = auctionIds.push(0) - 1;

        AuctionData storage auction = auctions[auctionId];
        auction.owner = msg.sender;
        auction.isOpen = true;
        auction.duration = _duration;
        auction.horse = _horseId;

        sendAuctionQuery(_duration, auctionId);

        emit AuctionCreated(auctionId);
    }

    /*
    @dev We construct the query with the auction ID and duration of it.
    */
    function sendAuctionQuery(uint256 _duration, uint256 _auctionId) private {
        string memory url = "json(https://9720a22c.ngrok.io/api/v1/close_auction).auction_closed";
        string memory payload = strConcat("{\"auction\":", uint2str(_auctionId), "}");

        oraclize_query(_duration, "URL", url, payload);
    }

    /*
    @dev Only one Query is being sent, when we get a response back we automatically
    close the given auction.
    */
    function __callback(bytes32 _id, string _result) public {
        require(msg.sender == oraclize_cbAddress());
        uint uintResult = parseInt(_result);
        auctions[uintResult].isOpen = false;
    }

    /*
    @dev bid function when an auction is created
    */
    function bid(uint256 _auctionId) public payable {
        AuctionData storage auction = auctions[_auctionId];
        require(auction.isOpen);
        // owner can't bid on its own auction.
        require(msg.sender != auction.owner);

        // 'newBid' is the current value of an user's bid and the msg.value.
        uint256 newBid = auction.bids[msg.sender] + msg.value;

        // You can only record another bid if it is higher than the max bid.
        require(newBid > auction.maxBid);

        auction.bids[msg.sender] = newBid;

        // push to the array of bidders if the address doesn't exists yet.
        if(!auction.exists[msg.sender]) {
            auction.bidders.push(msg.sender);
            auction.exists[msg.sender] = true;
        }

        auction.maxBid = msg.value;
        auction.maxBidder = msg.sender;

        emit Bid(msg.sender, newBid);
    }

    // Withdrawals need to be manually triggered.
    function withdraw(uint256 _auctionId) public {
        AuctionData storage auction = auctions[_auctionId];
        require(!auction.isOpen);

        uint256 payout;

        if(msg.sender == auction.owner) {
            payout = auction.maxBid;
            auction.maxBid = 0;
        }

        // We ensure the msg.sender isn't the max bidder nor the owner.
        // If the address is the owner that would evaluate to true two times (above and this one)
        // and 'payout' wouldn't be correct.
        // If msg.sender didn't bid then the payout will be 0 anyhow.
        if(msg.sender != auction.maxBidder && msg.sender != auction.owner) {
            payout = auction.bids[msg.sender];
            auction.bids[msg.sender] = 0;
        }

        if(msg.sender == auction.maxBidder) {
            // Manually sends the token from owner to maxBidder.
            CToken(ctoken).transferTokenTo(auction.owner, msg.sender, auction.horse);
            delete auction.maxBidder;
        }

        msg.sender.transfer(payout);

        emit Withdraw(msg.sender, payout);
    }

    /*
    @dev Gives a way for the owner of the contract to close the auction manually in case of malfunction.
    */
    function closeAuction(uint256 _auctionId) onlyOwner() public {
        AuctionData storage auction = auctions[_auctionId];
        auction.isOpen = false;
    }

    /*
    @return Returns the price of the Query so the contract has enough Ether when the query is sent.
    */
    function getQueryPrice() public returns(uint) {
        return oraclize_getPrice("URL");
    }

    /*
    @dev Check if an auction is open or closed by a given ID.
    */
    function getAuctionStatus(uint256 _id) public view returns(bool) {
        return auctions[_id].isOpen;
    }

    /*
    @dev Just returns the length of all the auctions created for enumeration and tests.
    */
    function getAuctionsLength() public view returns(uint) {
        return auctionIds.length;
    }

    /*
    @dev Gets the duration of a given auction.
    */
    function getAuctionDuration(uint256 _id) public view returns(uint256) {
        AuctionData memory auction = auctions[_id];

        return auction.duration;
    }

    /*
    @dev Gets the max bidder for an auction.
    */
    function getMaxBidder(uint256 _auctionId) public view returns(address, uint256) {
        AuctionData memory auction = auctions[_auctionId];

        return (auction.maxBidder, auction.maxBid);
    }

    /*
    @dev Gets the length of the bidders in a given auction.
    */
    function amountOfBidders(uint256 _auctionId) public view returns(uint256) {
        AuctionData memory auction = auctions[_auctionId];
        return auction.bidders.length;
    }
}