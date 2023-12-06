import { ethers } from "hardhat"
import "@nomiclabs/hardhat-waffle"
import { expect } from "chai"
import { toWei, createContract, sleep } from "./deployUtils"
import { Contract } from "ethers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
const U = ethers.utils
const B = ethers.BigNumber

describe("MlpRewardTracker", async () => {
  let user0: SignerWithAddress
  let user1: SignerWithAddress
  let user2: SignerWithAddress
  let user3: SignerWithAddress
  let trash: SignerWithAddress

  let router: Contract
  let zeroAddress = "0x0000000000000000000000000000000000000000"
  let epsilon = "1000000000"

  before(async () => {
    const accounts = await ethers.getSigners()
    user0 = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    trash = accounts[4]
  })

  it("distribute", async () => {
    const weth = await createContract("MockERC20", ["WETH", "WETH", 18])
    const mlp = await createContract("MockERC20", ["MLP", "MLP", 18])
    const mcb = await createContract("MockERC20", ["MUX", "MUX", 18])
    const arb = await createContract("MockERC20", ["ARB", "ARB", 18])
    const sMlp = await createContract("MlpRewardTracker")
    const arbDist = await createContract("ArbDistributor")
    const mockDist = await createContract("MockDistritbutor", [weth.address])

    await arbDist.initialize("adMlp", "adMlp", user3.address, arb.address, mlp.address, sMlp.address)
    await sMlp.initialize("StakedMlp", "SMLP", [mlp.address], mockDist.address)
    await sMlp.setArbDistributor(arbDist.address)

    // stake mlp
    await mlp.mint(user0.address, toWei("100"))
    await mlp.approve(sMlp.address, toWei("100"))
    await sMlp.stake(mlp.address, toWei("100"))

    await mlp.mint(user1.address, toWei("300"))
    await mlp.connect(user1).approve(sMlp.address, toWei("300"))
    await sMlp.connect(user1).stake(mlp.address, toWei("300"))

    expect(await arbDist.balanceOf(user0.address)).to.equal(toWei("100"))
    expect(await arbDist.balanceOf(user1.address)).to.equal(toWei("300"))

    await arb.mint(arbDist.address, toWei("10000"))
    await arbDist.setRewardRate(toWei("0.1"))

    const t0 = await arbDist.lastUpdateTime()
    await sleep(2000)
    await arbDist.claim(user0.address)
    const t1 = await arbDist.lastUpdateTime()

    expect(await arb.balanceOf(user0.address)).to.equal(
      toWei("0.1")
        .mul(t1 - t0)
        .div(4)
    )
    await arb.transfer(trash.address, await arb.balanceOf(user0.address))

    await sleep(2000)
    await mlp.mint(user2.address, toWei("100"))
    await mlp.connect(user2).approve(sMlp.address, toWei("100"))
    await sMlp.connect(user2).stake(mlp.address, toWei("100"))
    const t2 = await arbDist.lastUpdateTime()
    await arbDist.claim(user0.address)
    const t3 = await arbDist.lastUpdateTime()

    expect(await arb.balanceOf(user0.address)).to.equal(
      toWei("0.1")
        .mul(t2 - t1)
        .div(4)
        .add(
          toWei("0.1")
            .mul(t3 - t2)
            .div(5)
        )
    )
    await mlp.mint(user3.address, toWei("500"))
    await arbDist.updateRewards(user3.address)
    const t4 = await arbDist.lastUpdateTime()
    await sleep(2000)
    expect(await arbDist.balanceOf(user3.address)).to.equal(toWei("500"))
    await arbDist.claim(user0.address)
    const t5 = await arbDist.lastUpdateTime()
    expect(await arb.balanceOf(user3.address)).to.equal(
      toWei("0.1")
        .mul(t5 - t4)
        .div(2)
    )
  })
})
