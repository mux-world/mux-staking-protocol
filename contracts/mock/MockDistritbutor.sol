// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

contract MockDistritbutor {
    address public rewardToken;

    constructor(address rewardToken_) {
        rewardToken = rewardToken_;
    }

    function distribute() external {}
}
