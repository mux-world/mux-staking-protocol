import { ethers } from "hardhat"
import "@nomiclabs/hardhat-waffle"
import { expect } from "chai"
import { toWei, createContract, sleep } from "./deployUtils"
import { Contract, ContractReceipt } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

const U = ethers.utils
const B = ethers.BigNumber

describe("FeeDistributor", async () => {
  let user0: SignerWithAddress
  let user1: SignerWithAddress
  let user2: SignerWithAddress
  let user3: SignerWithAddress

  let dist: Contract
  let weth: Contract
  let router: Contract

  before(async () => {
    const accounts = await ethers.getSigners()
    user0 = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
  })

  beforeEach(async () => {
    weth = await createContract("MockERC20", ["S", "S", 18])
    dist = await createContract("TestFeeDistributor", [])
    router = await createContract("MockRouter", [])

    await dist.initialize(weth.address, router.address, user1.address, user2.address, 0)
  })

  it("portion", async function () {
    await dist.setHolderRewardProportion(toWei("0.7"))
    await dist.setExtraRewardProportion(toWei("0.3"))

    var res = await dist.getFeeDistribution(toWei("1"), 0)
    expect(res[0]).to.equal(toWei("0.7"))
    expect(res[1]).to.equal(toWei("0.3"))
    expect(res[2]).to.equal(toWei("0"))

    var res = await dist.getFeeDistribution(B.from("1"), 0)
    expect(res[0]).to.equal(toWei("0"))
    expect(res[1]).to.equal(toWei("0"))
    expect(res[2]).to.equal(1)

    var res = await dist.getFeeDistribution(B.from("1").add(toWei("1")), 0)
    expect(res[0]).to.equal(toWei("0.7"))
    expect(res[1]).to.equal(toWei("0.3"))
    expect(res[2]).to.equal(1)
  })

  it("portion - 2", async function () {
    await dist.setHolderRewardProportion(toWei("0.85"))
    await dist.setExtraRewardProportion(toWei("0.15"))

    var res = await dist.getFeeDistribution(toWei("1"), 0)
    expect(res[0]).to.equal(toWei("0.85"))
    expect(res[1]).to.equal(toWei("0.15"))
    expect(res[2]).to.equal(toWei("0"))

    var res = await dist.getFeeDistribution(B.from("1"), 0)
    expect(res[0]).to.equal(toWei("0"))
    expect(res[1]).to.equal(toWei("0"))
    expect(res[2]).to.equal(1)

    var res = await dist.getFeeDistribution(B.from("1").add(toWei("1")), 0)
    expect(res[0]).to.equal(toWei("0.85"))
    expect(res[1]).to.equal(toWei("0.15"))
    expect(res[2]).to.equal(1)

    var res = await dist.getFeeDistribution(toWei("1").sub(B.from("1")), 0)
    expect(res[0]).to.equal(toWei("0.849999999999999999"))
    expect(res[1]).to.equal(toWei("0.149999999999999999"))
    expect(res[2]).to.equal(1)
  })
})
