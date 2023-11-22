/*
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Utilities } from "./Utilities.sol";
import { DamnValuableToken } from "../src/DamnValuableToken.sol";
import { FlashLoanerPool } from "../src/the-rewarder/FlashLoanerPool.sol";
import {TheRewarderPool, RewardToken, AccountingToken, FixedPointMathLib} from "../src/the-rewarder/TheRewarderPool.sol";
import { Attacker } from "../src/the-rewarder/Attacker.sol";

contract TheRewarderTest is Test{
    using FixedPointMathLib for uint256;
    uint256 constant TOKENS_IN_LENDER_POOL = 1_000_000e18;
    Utilities util = new Utilities();
    address payable[] internal users;
    address payable internal deployer;
    address payable internal alice;
    address payable internal bob;
    address payable internal charlie;
    address payable internal david;
    address payable internal player;

    TheRewarderPool rewarderPool;
    RewardToken rewardToken;
    AccountingToken accountingToken;
    DamnValuableToken liquidityToken;
    FlashLoanerPool flashLoanPool;

    function setUp() public{
        users = util.createUsers(4);
        
        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];
        
        address payable[] memory someUsers = util.createUsers(2);
        deployer = someUsers[0];
        player = someUsers[1];

        liquidityToken = new DamnValuableToken();
        flashLoanPool = new FlashLoanerPool(address(liquidityToken));

        liquidityToken.transfer(address(flashLoanPool), TOKENS_IN_LENDER_POOL);

        rewarderPool = new TheRewarderPool(address(liquidityToken));
        rewardToken = RewardToken(rewarderPool.rewardToken());
        accountingToken = AccountingToken(rewarderPool.accountingToken());

        assertEq(accountingToken.owner(), address(rewarderPool));

        uint256 mintRole = accountingToken.MINTER_ROLE();
        uint256 snapShotRole = accountingToken.SNAPSHOT_ROLE();
        uint256 burnerRole = accountingToken.BURNER_ROLE();

        assertTrue(accountingToken.hasAllRoles(address(rewarderPool), mintRole | snapShotRole | burnerRole));

        uint256 depositAmount = 100e18;
        for (uint256 i=0;i < users.length; i++){
            liquidityToken.transfer(users[i], depositAmount);
            vm.startPrank(users[i]);
            liquidityToken.approve(address(rewarderPool), depositAmount);
            rewarderPool.deposit(depositAmount);
            assertEq(accountingToken.balanceOf(users[i]), depositAmount);
            vm.stopPrank();
        }

        // advance block timestap
        vm.warp(block.timestamp + 5 days);

        uint256 rewardInRound = rewarderPool.REWARDS();
        for (uint256 i=0; i<users.length; i++){
            vm.startPrank(users[i]);
            rewarderPool.distributeRewards();
            assertEq(rewardToken.balanceOf(users[i]), rewardInRound.rawDiv(users.length));
            vm.stopPrank();
        }
        assertEq(rewardToken.totalSupply(), rewardInRound);
        assertEq(liquidityToken.balanceOf(address(player)),0);
        assertEq(rewarderPool.roundNumber(),2);
    }

    function testExploit() public{
        // CODE YOUR SOLUTION HERE
        vm.startPrank(player);
        vm.warp(block.timestamp + 5 days);
        Attacker attacker = new Attacker(address(flashLoanPool), address(rewarderPool), address(liquidityToken), address(rewardToken));
        attacker.attack(TOKENS_IN_LENDER_POOL);
        vm.stopPrank();
        validation();
    }

    function validation() public{
        assertEq(rewarderPool.roundNumber(),3);
        for (uint256 i=0; i< users.length; i++){
            vm.startPrank(users[i]);
            rewarderPool.distributeRewards();
            uint256 userReward = rewardToken.balanceOf(users[i]);
            uint256 userDelta = userReward.rawSub(rewarderPool.REWARDS().rawDiv(users.length));
            assertTrue(userDelta < 1e16);
            vm.stopPrank();
        }

        // rewards must have been issued to the player account
        assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
        uint256 playerRewards = rewardToken.balanceOf(address(player));
        assertGt(playerRewards, 0);

        // the amount of rewards earned should be close to total available amount
        uint256 delta = rewarderPool.REWARDS().rawSub(playerRewards);
        assertLt(delta, 1e17);

        // balance of dvt tokens is player and lending pool hasn't changed
        assertEq(liquidityToken.balanceOf(address(player)), 0);
        assertEq(liquidityToken.balanceOf(address(flashLoanPool)), TOKENS_IN_LENDER_POOL);
    }
}
*/