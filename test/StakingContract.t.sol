// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Staking} from "../src/StakingContract.sol";

contract StakingContractTest is Test {
    Staking public staking;

    function setUp() public {
        staking = new Staking();
    }

    function testsetRewardsDuration() public {
        staking.rewards();
        staking.duration = 10;
        vm.expectRevert(staking.setRewardsDuration.selector);
    }

    function testRewardAmount() public {
        staking.rewardRate();
        staking.updatedAt = 4;
        vm.expectRevert(staking.notifyRewardAmount.selector);
    }
}
