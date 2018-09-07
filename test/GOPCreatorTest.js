const GOPCreator = artifacts.require("./GOPCreator");
const Core = artifacts.require("./Core");

contract("GOPCreator", acc => {
  let instance, core;
  let owner = acc[1];
  let amount = web3.toWei(0.25, "ether");

  before("setup instance", async () => {
    instance = await GOPCreator.deployed();
    core = await Core.deployed();

    await core.setGOPCreator(instance.address, { from: owner });

    await instance.openBatch(1, { from: owner });

    await instance.createGOP(owner, "first hash", { value: amount }); // 0
  })

  it("should open a batch", async () => {
    await instance.createGOP(owner, "some hash", { value: amount }); // 1

    let remaining = await instance.horsesRemaining.call(1);

    assert.equal(remaining.toNumber(), 99);
  })

  it("should create correct horse based on open batch", async () => {
    await instance.closeBatch(1, { from: owner });
    await instance.openBatch(3, { from: owner });
    await instance.createGOP(owner, "some hash", { value: amount }); // 2

    let genotype = await core.getGenotype.call(2);
    let bloodline = await core.getBloodline.call(2);

    assert.equal(genotype.toNumber(), 3);
    assert.equal(web3.toUtf8(bloodline), "S");
  })

  it("should revert and not modify state", async () => {
    try {
      await instance.createGOP(owner, "some hash"); // 3
      assert.fail("Expected revert not received");
    } catch (err) {
      let revertFound = err.message.search("revert") >= 0;
      assert(revertFound, `Expected "revert", got ${err} instead`);
    }

    let genotype = await core.getGenotype.call(3);
    assert.equal(genotype.toNumber(), 0);
  })
})