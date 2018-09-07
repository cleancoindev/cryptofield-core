const Core = artifacts.require("./Core");
const Breeding = artifacts.require("./Breeding");
const GOPCreator = artifacts.require("./GOPCreator");

contract("Token", acc => {
  let instance, breed, query, gop;
  let owner = acc[1];
  let secondBuyer = acc[2];
  let amount = web3.toWei(0.25, "ether");

  before("setup instance", async () => {
    instance = await Core.deployed();
    breed = await Breeding.deployed();
    gop = await GOPCreator.deployed();

    await instance.setGOPCreator(gop.address, { from: owner });

    await instance.setBreedingAddr(breed.address, { from: owner });

    await gop.openBatch(1, { from: owner });

    query = await instance.getQueryPrice.call();
  })

  it("should mint a new token with specified params", async () => {
    await gop.createGOP(owner, "male hash", { from: owner, value: amount }); // 0
    let tokenOwner = await instance.ownerOf(0);

    assert.equal(tokenOwner, owner);
  })

  it("should return the owned tokens of an address", async () => {
    let tokens = await instance.getOwnedTokens(owner);

    // This returns the token IDS in an array, not the amount of tokens.
    assert.equal(tokens.toString(), "0");
  })

  it("should be able to transfer a token", async () => {
    // 'owner' has token 0.
    await instance.safeTransferFrom(owner, secondBuyer, 0, { from: owner });
    let newTokenOwner = await instance.ownerOf(0);

    assert.equal(secondBuyer, newTokenOwner);
  })

  it("should transfer ownershp of the contract", async () => {
    let newOwner = acc[5];

    let op = await instance.transferOwnership(newOwner, { from: owner });
    let loggedOwner = op.logs[0].args.newOwner;

    assert.equal(loggedOwner, newOwner);
  })

  it("should use the given name if one is passed", async () => {
    await gop.createGOP(owner, "female hash", { value: amount }); // 1
    await gop.createGOP(owner, "male hash", { value: amount }); // 2

    await instance.putInStud(2, amount, 1, { from: owner, value: query });

    await breed.mix(2, 1, "female offspring hash", { from: owner, value: amount }); // 3

    await instance.setName("Spike", 3, { from: owner }); // This is only possible for offsprings.
    let name = await instance.getHorseName.call(3);

    assert.equal(name, "Spike");
  })

  it("should generate a random name if no name is given", async () => {
    await breed.mix(2, 1, "male offspring hash", { from: owner, value: amount }); // 4
    // We're just going to pass an empty string from the front-end.
    await instance.setName("", 4, { from: owner })
    let name = await instance.getHorseName.call(2);

    assert.notEqual(name, "");
  })

  it("should revert if a name is already given for an offspring/GOP", async () => {
    await breed.mix(2, 1, "female offspring hash", { from: owner, value: amount }); // 5
    await instance.setName("Odds", 5, { from: owner });

    try {
      await instance.setName("Icy", 5, { from: owner });
      assert.fail("Expected revert not received");
    } catch (err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }
  })
})
