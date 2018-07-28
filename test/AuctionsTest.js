const Auctions = artifacts.require("./Auctions");
const CToken = artifacts.require("./CToken");

contract("Auctions", acc => {
  let instance;
  let tokenInstance;
  let owner = acc[0];
  let buyer = acc[1];
  let amount = new web3.BigNumber(web3.toWei(1, "ether"));

  beforeEach("setup instance", async () => {
    instance = await Auctions.deployed();

    // We need this instance to mint a token.
    tokenInstance = await CToken.deployed();
    await tokenInstance.setAuctions(instance.address);
  })

  /*
  Since we can't test the oraclize, we're going to try to recreate
  the function.
  */
  it("should create an auction", async () => {
    await tokenInstance.createHorse(buyer, "some hash");
    await tokenInstance.approveAuctions(0, {from: buyer});
    await instance.createAuction(0, 0, {from: buyer, value: amount});

    let auctions = await instance.getAuctionsLength.call();
    assert.equal(auctions.toString(), "1");

    let status = await instance.getAuctionStatus.call(0);
    assert.equal(status, true);
  })

  it("should record a new bid for an address", async () => {
    await tokenInstance.createHorse(buyer, "other hash");
    await tokenInstance.approveAuctions(1, {from: buyer});
    
    let res = await instance.createAuction(1, 1, {from: buyer, value: amount});
    let auctionId = res.logs[0].args._auctionId.toNumber();

    // Auction should be open for a while, we're not calling the __callback function anyway.
    await instance.bid(auctionId, {from: acc[3], value: new web3.BigNumber(web3.toWei(0.025, "ether"))});

    // No one has bidded yet so the user should be the max bidder.
    let maxBidder = await instance.getMaxBidder.call(auctionId);
    assert.equal(maxBidder[0], acc[3]);

    // Record another bid for a higher amount
    await instance.bid(auctionId, {from: acc[4], value: new web3.BigNumber(web3.toWei(0.030, "ether"))});

    let newMaxBidder = await instance.getMaxBidder.call(auctionId);
    assert.equal(newMaxBidder[0], acc[4]);

    // amount of bidders should be two (2)
    let bidders = await instance.amountOfBidders.call(auctionId);
    assert.equal(bidders.toString(), "2");
  })

  it("should revert if the new bid amount is lower than the maxBid", async () => {
    await tokenInstance.createHorse(buyer, "third hash");
    await tokenInstance.approveAuctions(2, {from: buyer});

    let res = await instance.createAuction(1, 2, {from: buyer, value: amount});
    let auctionId = res.logs[0].args._auctionId.toNumber();

    // Record a new bid.
    await instance.bid(auctionId, {from: acc[2], value: web3.toWei(1, "finney")});

    // OpenZeppelin implementation.
    try {
      await instance.bid(auctionId, {from: acc[3], value: web3.toWei(0.5, "finney")});
      assert.fail("Expected revert not received");
    } catch(err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }
  })

  it("should let the owner close an auction", async () => {
    // We're going to close an already open auction
    let status = await instance.getAuctionStatus.call(0);
    assert.equal(status, true);

    await instance.closeAuction(0, {from: owner});
    
    status = await instance.getAuctionStatus.call(0);
    assert.equal(status, false);
  })

  it("should revert if not the owner tries to close an auction", async () => {
    // Again, we're using an existing auction.
    let status = await instance.getAuctionStatus.call(1);
    assert.equal(status, true);

    try {
      await instance.closeAuction(1, {from: acc[1]});
      assert.fail("Expected revert not received");
    } catch(err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }
  })

  it("should send the token to the max bidder of an auction", async () => {
    await tokenInstance.createHorse(buyer, "fourth hash");
    await tokenInstance.approveAuctions(3, {from: buyer});

    let res = await instance.createAuction(1, 3, {from: buyer, value: amount});
    let auctionId = res.logs[0].args._auctionId.toNumber();

    await instance.bid(auctionId, {from: acc[3], value: amount});

    // Auction closed
    await instance.closeAuction(auctionId, {from: owner});

    // maxBidder claims the reward
    await instance.withdraw(auctionId, {from: acc[3]});

    let tokenOwner = await tokenInstance.ownerOfToken.call(3);

    assert.equal(tokenOwner, acc[3]);
  })

  it("should send max bid to the auction owner", async () => {
    await tokenInstance.createHorse(buyer, "fifth hash");
    await tokenInstance.approveAuctions(4, {from: buyer});

    let res = await instance.createAuction(1, 4, {from: buyer, value: amount});
    let auction = res.logs[0].args._auctionId.toNumber();

    await instance.bid(auction, {from: acc[4], value: web3.toWei(1, "finney")});

    await instance.closeAuction(auction, {from: owner});

    let op = await instance.withdraw(auction, {from: buyer});
    let user = op.logs[0].args._user;
    let payout = op.logs[0].args._payout;

    assert.equal(user, buyer);
    assert.equal(payout, web3.toWei(1, "finney"));
  })

  it("should get the amount they bid if they're not the owner or winner", async () => {
    await tokenInstance.createHorse(buyer, "fifth hash");
    await tokenInstance.approveAuctions(5, {from: buyer});

    let res = await instance.createAuction(1, 5, {from: buyer, value: amount});
    let auction = res.logs[0].args._auctionId.toNumber();

    await instance.bid(auction, {from: acc[5], value: web3.toWei(1, "finney")});
    await instance.bid(auction, {from: acc[4], value: web3.toWei(2, "finney")});

    await instance.closeAuction(auction, {from: owner});

    // Not the winner nor the owner
    let op = await instance.withdraw(auction, {from: acc[5]});
    let address = op.logs[0].args._user;
    let payout = op.logs[0].args._payout;

    assert.equal(address, acc[5]);
    assert.equal(payout, web3.toWei(1, "finney"));
  })
})